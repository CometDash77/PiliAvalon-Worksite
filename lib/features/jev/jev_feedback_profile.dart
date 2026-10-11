import 'dart:convert';

import 'package:PiliPlus/features/jev/jev_models.dart';

abstract interface class JevProfileBox {
  Object? get(String key);
  Future<void> put(String key, Object? value);
  Future<void> delete(String key);
}

class JevFeedbackProfile {
  JevFeedbackProfile(this.box, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const storageKey = 'piliavalon.jev.negative_themes.v1';
  static const maxThemes = 20;
  final JevProfileBox box;
  final DateTime Function() _clock;

  List<JevTheme> load() {
    try {
      final raw = box.get(storageKey);
      if (raw is! String) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final themes = _newestFirst(
        decoded
            .whereType<Map>()
            .map((item) => JevTheme.fromJson(item.cast<String, Object?>()))
            .where(
              (theme) => !theme.updatedAt.isBefore(_sixMonthsBefore(_clock())),
            ),
      );
      return themes.take(maxThemes).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Call only for an explicit dislike on a recommendation card, and only
  /// when the Jev master switch is on. Stores themes and approximate counts,
  /// never the source card or its identifiers.
  ///
  /// A card title is deliberately absent: it identifies one video rather than
  /// expressing a reusable negative preference. The selected reason wins over
  /// the displayed reason; a dislike with neither reason leaves the profile
  /// unchanged.
  Future<void> recordExplicitDislike({
    required bool jevEnabled,
    String? displayedReason,
    String? selectedReason,
    DateTime? at,
  }) async {
    if (!jevEnabled) return;
    final now = at ?? _clock();
    await pruneExpired();
    final reason = selectedReason ?? displayedReason;
    final terms = _extractThemes(reason).toSet();
    if (terms.isEmpty) return;
    final current = load();
    final byLabel = {for (final theme in current) theme.label: theme};
    final updated = <JevTheme>[
      for (final term in terms)
        JevTheme(
          label: term,
          count: _approxNext(byLabel[term]?.count ?? 0),
          updatedAt: now,
        ),
      for (final theme in current)
        if (!terms.contains(theme.label)) theme,
    ];
    await box.put(
      storageKey,
      jsonEncode(
        updated.take(maxThemes).map((theme) => theme.toJson()).toList(),
      ),
    );
  }

  Future<void> deleteTheme(String label) async {
    final next = load().where((theme) => theme.label != label).toList();
    await box.put(
      storageKey,
      jsonEncode(next.map((theme) => theme.toJson()).toList()),
    );
  }

  Future<void> deleteAll() => box.delete(storageKey);

  Future<void> pruneExpired({DateTime? at}) async {
    final now = at ?? _clock();
    final cutoff = _sixMonthsBefore(now);
    final active = load()
        .where((theme) => !theme.updatedAt.isBefore(cutoff))
        .toList();
    await box.put(
      storageKey,
      jsonEncode(active.map((theme) => theme.toJson()).toList()),
    );
  }

  List<Map<String, Object?>> providerSummary() => [
    for (final theme in load())
      {
        'label': theme.label,
        'approximate_count': theme.count,
      },
  ];

  /// Sorts newest first while preserving stored order for equal timestamps.
  static List<JevTheme> _newestFirst(Iterable<JevTheme> themes) {
    final sorted = <JevTheme>[];
    for (final theme in themes) {
      var index = 0;
      while (index < sorted.length &&
          !theme.updatedAt.isAfter(sorted[index].updatedAt)) {
        index++;
      }
      sorted.insert(index, theme);
    }
    return sorted;
  }

  static int _approxNext(int count) {
    const buckets = [1, 2, 3, 5, 10, 20, 50];
    final next = count + 1;
    return buckets.firstWhere((bucket) => bucket >= next, orElse: () => 50);
  }

  static DateTime _sixMonthsBefore(DateTime date) {
    final targetMonth = date.month - 6;
    final lastTargetDay = date.isUtc
        ? DateTime.utc(date.year, targetMonth + 1, 0).day
        : DateTime(date.year, targetMonth + 1, 0).day;
    final day = date.day.clamp(1, lastTargetDay);
    return date.isUtc
        ? DateTime.utc(
            date.year,
            targetMonth,
            day,
            date.hour,
            date.minute,
            date.second,
          )
        : DateTime(
            date.year,
            targetMonth,
            day,
            date.hour,
            date.minute,
            date.second,
          );
  }

  static Iterable<String> _extractThemes(String? raw) sync* {
    if (raw == null) return;
    final normalized = raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    for (final part in normalized.split(RegExp(r'[，,。.!！?？;；:：、/|]+'))) {
      final value = part.trim();
      if (value.length < 2 || value.length > 32) continue;
      if (RegExp(r'^(不感兴趣|不喜欢|其他原因|减少推荐)$').hasMatch(value)) continue;
      yield value;
    }
  }
}
