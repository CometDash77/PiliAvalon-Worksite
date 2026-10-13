import 'dart:convert';

import 'package:PiliPlus/features/llm/llm_contract.dart';

/// One verified hit: the model must reference a rule id that was actually
/// sent, with a short human-readable reason.
class LlmHit {
  const LlmHit({required this.ruleId, required this.reason});

  final String ruleId;
  final String reason; // already truncated to LlmLimits.maxReasonRunes
}

/// Parsed verdict of one chat answer (spec 4).
class LlmVerdict {
  const LlmVerdict({
    required this.valid,
    required this.hits,
    required this.droppedHits,
  });

  /// Whole-response shape contract held (exactly {"hits":[...]} with no
  /// extra fields anywhere). False = the response is invalid and the whole
  /// batch it belongs to fails open.
  final bool valid;

  /// Known-rule hits only.
  final List<LlmHit> hits;

  /// True when unknown rule ids or missing reasons forced a hit drop: the
  /// affected content stays visible (fail-open per hit), other hits stand,
  /// but no verdict from this response may enter the cache.
  final bool droppedHits;

  static const LlmVerdict invalid = LlmVerdict(
    valid: false,
    hits: [],
    droppedHits: false,
  );
}

abstract final class LlmVerdictParser {
  /// Lenient extraction (first '{' .. last '}'), then strict shape: the
  /// top level must be exactly {'hits': [...]} and every entry exactly
  /// {'rule_id', 'reason'} with string values. Extra fields anywhere make
  /// the whole response invalid (spec 6). Unknown rule ids and hits without
  /// a reason fail open for their own content only: the hit is dropped, the
  /// rest stands. Reasons over [LlmLimits.maxReasonRunes] runes are
  /// truncated but keep the verdict valid (spec 4).
  static LlmVerdict parse(String? text, Set<String> knownRuleIds) {
    if (text == null) return LlmVerdict.invalid;
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return LlmVerdict.invalid;
    Object? decoded;
    try {
      decoded = jsonDecode(text.substring(start, end + 1));
    } catch (_) {
      return LlmVerdict.invalid;
    }
    if (decoded is! Map) return LlmVerdict.invalid;
    if (decoded.length != 1 || decoded.keys.first != 'hits') {
      return LlmVerdict.invalid;
    }
    final hits = decoded['hits'];
    if (hits is! List) return LlmVerdict.invalid;
    final result = <LlmHit>[];
    var dropped = false;
    for (final entry in hits) {
      if (entry is! Map) return LlmVerdict.invalid;
      if (entry.length != 2 ||
          !entry.containsKey('rule_id') ||
          !entry.containsKey('reason')) {
        return LlmVerdict.invalid;
      }
      final id = entry['rule_id'];
      final reason = entry['reason'];
      if (id is! String || reason is! String) return LlmVerdict.invalid;
      if (!knownRuleIds.contains(id)) {
        dropped = true;
        continue;
      }
      if (reason.trim().isEmpty) {
        dropped = true;
        continue;
      }
      result.add(
        LlmHit(
          ruleId: id,
          reason: String.fromCharCodes(
            reason.runes.take(LlmLimits.maxReasonRunes),
          ),
        ),
      );
    }
    return LlmVerdict(
      valid: true,
      hits: List.unmodifiable(result),
      droppedHits: dropped,
    );
  }
}
