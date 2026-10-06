import 'dart:convert';

import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:flutter/foundation.dart' show immutable, listEquals;

/// One explicit 「不感兴趣」 tap on a recommendation card (issue #33).
///
/// This is the only admissible collection event, and [JevDislikeSignal.card] is
/// its only constructor: there is deliberately no way to build a signal from a
/// video-detail dislike, a comment interaction, a skip, or viewing behaviour, so
/// no caller can feed those into the local profile.
@immutable
class JevDislikeSignal {
  const JevDislikeSignal.card({
    required this.title,
    this.displayedReason,
    this.selectedReason,
  });

  /// Title of the marked card.
  final String title;

  /// The recommendation reason the card displayed, when it had one
  /// (rcmd_reason).
  final String? displayedReason;

  /// The feedback reason the user tapped, when the platform offered a list of
  /// them.
  final String? selectedReason;

  /// The short preference theme this tap contributes to, or null when none of
  /// the three fields carries a usable topical phrase — then nothing is stored.
  ///
  /// Gap G-05 resolution: summarisation is deterministic and on-device. The card
  /// title is the only topical field, so it wins; the displayed reason and the
  /// tapped reason are non-topical fallbacks (they are UI categories such as
  /// 「已看过」). See [JevPreferenceTheme.summarizeText] for the cleaning rules
  /// that keep a theme a theme instead of a stored per-video row.
  String? summarize() =>
      JevPreferenceTheme.summarizeText(title) ??
      JevPreferenceTheme.summarizeText(displayedReason) ??
      JevPreferenceTheme.summarizeText(selectedReason);
}

/// One locally summarised negative-preference theme — the only thing this
/// feature retains (issue #33).
///
/// A theme is a short topical phrase plus an approximate count: never a video
/// id, a link, an uploader, or a per-video row.
@immutable
class JevPreferenceTheme {
  const JevPreferenceTheme({
    required this.theme,
    required this.count,
    required this.lastFeedbackAt,
  });

  /// Short topical phrase of at most [JevLimits.maxThemeChars] runes.
  final String theme;

  /// Approximate number of card dislikes folded into this theme, saturating at
  /// [JevLimits.maxThemeCount]: a magnitude, not an exact tally.
  final int count;

  /// Time of the newest feedback behind this theme. Drives both eviction (oldest
  /// new feedback first) and the six-month expiry.
  final DateTime lastFeedbackAt;

  /// Dedupe/merge key: case- and space-insensitive.
  String get key => keyOf(theme);

  static String keyOf(String theme) => theme.replaceAll(' ', '').toLowerCase();

  JevPreferenceTheme bumped(DateTime now) => JevPreferenceTheme(
    theme: theme,
    count: count >= JevLimits.maxThemeCount
        ? JevLimits.maxThemeCount
        : count + 1,
    lastFeedbackAt: now,
  );

  /// Card text → short theme phrase, or null when nothing usable is left.
  ///
  /// Deterministic, offline, and small. Bracketed decoration is dropped, links
  /// and video ids are removed (they must never reach the profile, let alone the
  /// request), everything that is not a CJK/kana/hangul/latin/digit word
  /// collapses to one space, and the result is capped at [JevLimits.maxThemeChars]
  /// runes. A phrase shorter than two runes is noise and yields null.
  static String? summarizeText(String? raw) {
    if (raw == null) return null;
    final stripped = raw
        .replaceAll(_url, ' ')
        .replaceAll(_videoId, ' ')
        .replaceAll('_', ' ');
    final runes = stripped.runes.toList();
    final buffer = StringBuffer();
    var bracketed = 0;
    for (final rune in runes) {
      if (_openBrackets.contains(rune)) {
        bracketed++;
        continue;
      }
      if (_closeBrackets.contains(rune)) {
        if (bracketed > 0) bracketed--;
        continue;
      }
      if (bracketed > 0) continue;
      buffer.writeCharCode(_isWordRune(rune) ? rune : _space);
    }
    var text = buffer.toString().replaceAll(_spaces, ' ').trim();
    final kept = text.runes.toList();
    if (kept.length > JevLimits.maxThemeChars) {
      text = String.fromCharCodes(kept.take(JevLimits.maxThemeChars)).trim();
    }
    if (text.runes.length < 2) return null;
    return text;
  }

  static const int _space = 0x20;

  /// 【 ( （ [
  static const Set<int> _openBrackets = <int>{0x3010, 0xFF08, 0x0028, 0x005B};

  /// 】 ) ） ]
  static const Set<int> _closeBrackets = <int>{0x3011, 0xFF09, 0x0029, 0x005D};

  static bool _isWordRune(int rune) =>
      (rune >= 0x4e00 && rune <= 0x9fff) || // CJK unified ideographs
      (rune >= 0x3040 && rune <= 0x30ff) || // kana
      (rune >= 0xac00 && rune <= 0xd7af) || // hangul
      (rune >= 0x30 && rune <= 0x39) || // 0-9
      (rune >= 0x41 && rune <= 0x5a) || // A-Z
      (rune >= 0x61 && rune <= 0x7a); // a-z

  static final RegExp _url = RegExp(r'[a-zA-Z][a-zA-Z0-9+.-]*://[^ ]+');

  /// BV1xx411c7mD / av170001: a video id is identity, not a theme.
  static final RegExp _videoId = RegExp(
    r'(?:^|[^0-9A-Za-z])(?:[Bb][Vv][0-9A-Za-z]{8,}|av[0-9]{4,})(?:[^0-9A-Za-z]|$)',
  );

  static final RegExp _spaces = RegExp(r' +');

  @override
  bool operator ==(Object other) =>
      other is JevPreferenceTheme &&
      other.theme == theme &&
      other.count == count &&
      other.lastFeedbackAt == lastFeedbackAt;

  @override
  int get hashCode => Object.hash(theme, count, lastFeedbackAt);

  @override
  String toString() => 'JevPreferenceTheme($theme x $count)';
}

/// The local explicit negative-feedback profile (issue #33).
///
/// Themes and approximate counts only, newest feedback first, at most
/// [JevLimits.maxProfileThemes] entries. Platform-side 「撤销」 never reaches this
/// class: it cancels the platform feedback and leaves the local count alone.
@immutable
class JevPreferenceProfile {
  const JevPreferenceProfile({this.themes = const <JevPreferenceTheme>[]});

  static const JevPreferenceProfile empty = JevPreferenceProfile();

  static const String themesField = 'themes';
  static const String themeField = 'theme';
  static const String countField = 'count';
  static const String lastField = 'last';

  /// Ordered by last feedback, newest first.
  final List<JevPreferenceTheme> themes;

  bool get isEmpty => themes.isEmpty;

  int get length => themes.length;

  /// Folds one card dislike in: merge on [JevPreferenceTheme.key], bump the
  /// approximate count, refresh the feedback time, then keep the newest
  /// [JevLimits.maxProfileThemes] themes — the one with the oldest new feedback
  /// is evicted first (issue #33).
  JevPreferenceProfile recordTheme(String theme, {required DateTime now}) {
    final incoming = JevPreferenceTheme(
      theme: theme,
      count: 1,
      lastFeedbackAt: now,
    );
    var merged = false;
    final next = <JevPreferenceTheme>[];
    for (final existing in themes) {
      if (existing.key == incoming.key) {
        next.add(existing.bumped(now));
        merged = true;
      } else {
        next.add(existing);
      }
    }
    if (!merged) next.add(incoming);
    return _from(next);
  }

  /// Deletes one theme (issue #33: deleting a single theme is a user action).
  JevPreferenceProfile withoutTheme(String theme) {
    final key = JevPreferenceTheme.keyOf(theme);
    return JevPreferenceProfile(
      themes: List.unmodifiable(themes.where((item) => item.key != key)),
    );
  }

  /// Drops every theme with no new feedback for [JevLimits.themeTtl].
  ///
  /// Settlement is lazy and independent of the switches: a profile keeps its
  /// expiry timers while Jev is off (issue #33).
  JevPreferenceProfile settled(DateTime now) {
    final kept = themes
        .where(
          (item) => now.difference(item.lastFeedbackAt) < JevLimits.themeTtl,
        )
        .toList();
    if (kept.length == themes.length) return this;
    return JevPreferenceProfile(themes: List.unmodifiable(kept));
  }

  /// Stored form: the theme, the approximate count, and the feedback time that
  /// the eviction and expiry rules need. Nothing else is ever written.
  String encode() => jsonEncode(<String, Object?>{
    themesField: <Object?>[
      for (final item in themes)
        <String, Object?>{
          themeField: item.theme,
          countField: item.count,
          lastField: item.lastFeedbackAt.millisecondsSinceEpoch,
        },
    ],
  });

  /// The projection allowed to leave the device (issue #29 privacy limits):
  /// theme plus approximate count. Card identity and timestamps stay local.
  Map<String, Object?> statePayload() => <String, Object?>{
    themesField: <Object?>[
      for (final item in themes)
        <String, Object?>{themeField: item.theme, countField: item.count},
    ],
  };

  /// Never throws: anything that is not a well-formed profile reads as empty,
  /// and one unusable entry is skipped instead of poisoning the rest.
  static JevPreferenceProfile decode(Object? raw) {
    if (raw is! String || raw.isEmpty) return empty;
    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (_) {
      return empty;
    }
    if (parsed is! Map) return empty;
    final entries = parsed[themesField];
    if (entries is! List) return empty;

    final themes = <JevPreferenceTheme>[];
    for (final entry in entries) {
      if (entry is! Map) continue;
      final rawTheme = entry[themeField];
      final rawLast = entry[lastField];
      if (rawTheme is! String || rawLast is! int) continue;
      final text = JevPreferenceTheme.summarizeText(rawTheme);
      if (text == null) continue;
      final rawCount = entry[countField];
      themes.add(
        JevPreferenceTheme(
          theme: text,
          count: (rawCount is int ? rawCount : 1).clamp(
            1,
            JevLimits.maxThemeCount,
          ),
          lastFeedbackAt: DateTime.fromMillisecondsSinceEpoch(rawLast),
        ),
      );
    }
    return _from(themes);
  }

  static JevPreferenceProfile _from(List<JevPreferenceTheme> themes) {
    final sorted = List<JevPreferenceTheme>.of(themes)
      ..sort((a, b) {
        final byTime = b.lastFeedbackAt.compareTo(a.lastFeedbackAt);
        // Ties break on the theme key so the stored order is deterministic.
        return byTime != 0 ? byTime : a.key.compareTo(b.key);
      });
    if (sorted.length > JevLimits.maxProfileThemes) {
      sorted.removeRange(JevLimits.maxProfileThemes, sorted.length);
    }
    return JevPreferenceProfile(themes: List.unmodifiable(sorted));
  }

  @override
  bool operator ==(Object other) =>
      other is JevPreferenceProfile && listEquals(other.themes, themes);

  @override
  int get hashCode => Object.hashAll(themes);

  @override
  String toString() => 'JevPreferenceProfile($length themes)';
}
