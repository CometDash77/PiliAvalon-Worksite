import 'dart:convert';

import 'package:PiliPlus/features/llm/llm_contract.dart';

/// One verified hit: the model must reference a rule id that was actually
/// sent, with a short human-readable reason.
enum LlmConfidenceBand { high, medium, low }

class LlmHit {
  const LlmHit({
    required this.ruleId,
    required this.reason,
    this.band,
  });

  final String ruleId;
  final String reason; // already truncated to LlmLimits.maxReasonRunes
  final LlmConfidenceBand? band;
}

/// Parsed verdict of one chat answer (spec 4).
class LlmVerdict {
  const LlmVerdict({
    required this.valid,
    required this.hits,
  });

  /// Whole-response shape contract held (exactly {"hits":[...]} with no
  /// extra fields anywhere). False = the response is invalid and the whole
  /// batch it belongs to fails open.
  final bool valid;

  /// Known-rule hits only.
  final List<LlmHit> hits;

  static const LlmVerdict invalid = LlmVerdict(
    valid: false,
    hits: [],
  );
}

abstract final class LlmVerdictParser {
  /// Strict JSON decoding and shape: the
  /// top level must be exactly {'hits': [...]} and every entry exactly
  /// {'rule_id', 'reason'} with string values; canonical mode also requires
  /// a qualitative band. Extra fields, unknown ids,
  /// blank reasons, or duplicate ids make the whole response invalid: a
  /// partially understood response must never hide content. Reasons over
  /// [LlmLimits.maxReasonRunes] runes are truncated but keep the verdict
  /// valid (spec 4).
  static LlmVerdict parse(String? text, Set<String> knownRuleIds) =>
      _parse(text, knownRuleIds, requireBand: false);

  static LlmVerdict parseCanonical(String? text, Set<String> knownRuleIds) =>
      _parse(text, knownRuleIds, requireBand: true);

  static LlmVerdict _parse(
    String? text,
    Set<String> knownRuleIds, {
    required bool requireBand,
  }) {
    if (text == null) return LlmVerdict.invalid;
    Object? decoded;
    try {
      decoded = jsonDecode(text);
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
    final seen = <String>{};
    for (final entry in hits) {
      if (entry is! Map) return LlmVerdict.invalid;
      final expectedFields = requireBand ? 3 : 2;
      if (entry.length != expectedFields ||
          !entry.containsKey('rule_id') ||
          !entry.containsKey('reason') ||
          (requireBand && !entry.containsKey('band'))) {
        return LlmVerdict.invalid;
      }
      final id = entry['rule_id'];
      final reason = entry['reason'];
      final band = _parseBand(entry['band']);
      if (id is! String || reason is! String ||
          (requireBand && band == null)) return LlmVerdict.invalid;
      if (!knownRuleIds.contains(id) ||
          reason.trim().isEmpty ||
          !seen.add(id)) {
        return LlmVerdict.invalid;
      }
      result.add(
        LlmHit(
          ruleId: id,
          reason: String.fromCharCodes(
            reason.runes.take(LlmLimits.maxReasonRunes),
          ),
          band: band,
        ),
      );
    }
    return LlmVerdict(
      valid: true,
      hits: List.unmodifiable(result),
    );
  }

  static LlmConfidenceBand? _parseBand(Object? value) => switch (value) {
    'high' => LlmConfidenceBand.high,
    'medium' => LlmConfidenceBand.medium,
    'low' => LlmConfidenceBand.low,
    _ => null,
  };
}
