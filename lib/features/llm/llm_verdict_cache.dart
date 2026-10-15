import 'dart:collection';

import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/features/jev/jev_verdict_cache.dart'
    show JevVerdictCache;
import 'package:PiliPlus/utils/storage.dart';

/// In-process verdict cache for the generic line (spec 5).
///
/// Same shape as the Jev verdict cache (#123): entries are organized by a
/// policy generation (protocol + base URL + model + active rule_version),
/// any policy change invalidates the whole old generation, entries carry a
/// TTL and a write-order capacity cap. The TTL/capacity/switch settings are
/// READ FROM THE SAME CONFIG SOURCE as #123 (JevVerdictCache's static
/// readers) - one settings entry, no separate generic-line knobs, so the
/// future #124 comment-cache unification has a single place to land.
///
/// Only definite verdicts (hide or keep) are stored; failures, timeouts,
/// truncated/refused responses, invalid responses and responses with
/// dropped hits never reach this cache.
class LlmVerdictCache {
  LlmVerdictCache({JevSettingsBox? box, DateTime Function()? clock})
    : _boxOrNull = box,
      _clock = clock ?? DateTime.now;

  // 构造期不触碰 GStorage（#130）：解析推迟到首次读写。
  final JevSettingsBox? _boxOrNull;
  JevSettingsBox? _lazyBox;
  JevSettingsBox get _box =>
      _lazyBox ??= _boxOrNull ?? HiveJevSettingsBox(GStorage.setting);
  final DateTime Function() _clock;

  // ponytail: no in-flight dedupe (JevVerdictCache has one). The comment
  // chain screens one page per controller and the video chain one page per
  // surface, so concurrent duplicate identities are rare; add an in-flight
  // map only if profiling shows duplicate upstream calls.
  static final Map<String, LinkedHashMap<String, _LlmVerdictEntry>>
  _generations = <String, LinkedHashMap<String, _LlmVerdictEntry>>{};

  bool get enabled => JevVerdictCache.enabledIn(_box);

  Duration get ttl => Duration(minutes: JevVerdictCache.ttlMinutesIn(_box));

  int get maxEntries => JevVerdictCache.maxEntriesIn(_box);

  /// Non-null hide verdict for a fresh entry; expired entries are dropped
  /// on read.
  bool? lookup(String generation, String identity) {
    final entries = _generations[generation];
    if (entries == null) return null;
    final entry = entries[identity];
    if (entry == null) return null;
    if (_clock().isAfter(entry.storedAt.add(ttl))) {
      entries.remove(identity);
      return null;
    }
    return entry.hide;
  }

  /// Writes one definite verdict. A new generation invalidates every older
  /// one; over capacity the oldest entries go first.
  void put(String generation, String identity, {required bool hide}) {
    var entries = _generations[generation];
    if (entries == null) {
      _generations.removeWhere((key, _) => key != generation);
      entries = LinkedHashMap<String, _LlmVerdictEntry>();
      _generations[generation] = entries;
    }
    final now = _clock();
    entries
      ..removeWhere((_, entry) => now.isAfter(entry.storedAt.add(ttl)))
      ..remove(identity)
      ..[identity] = _LlmVerdictEntry(hide: hide, storedAt: now);
    final max = maxEntries;
    while (entries.length > max) {
      entries.remove(entries.keys.first);
    }
  }

  static void resetCache() => _generations.clear();

  static int get cachedEntryCount {
    var total = 0;
    for (final entries in _generations.values) {
      total += entries.length;
    }
    return total;
  }
}

class _LlmVerdictEntry {
  const _LlmVerdictEntry({required this.hide, required this.storedAt});

  final bool hide;
  final DateTime storedAt;
}
