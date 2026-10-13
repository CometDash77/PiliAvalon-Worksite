import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_http_probe.dart';
import 'package:PiliPlus/features/jev/jev_provider_selection.dart';

/// Outcome of one validation attempt, always tied to the provider that was
/// actually called.
class JevValidationResult {
  const JevValidationResult({
    required this.provider,
    required this.outcome,
    this.blockedBy = const <JevSelectionIssue>[],
    this.detail,
    this.model,
  });

  /// The provider of the attempt, or the selected provider when nothing was
  /// sent because the selection was still blocked.
  final JevProvider? provider;

  /// `null` when no request left the device.
  final JevProbeOutcome? outcome;

  /// Non-empty when the request was never sent.
  final List<JevSelectionIssue> blockedBy;

  /// Short upstream summary (status + message) from the probe, when the
  /// provider actually answered; null keeps the generic copy (issue #101).
  final String? detail;
  final String? model;

  bool get attempted => outcome != null;

  bool get validated => outcome == JevProbeOutcome.ok;
}

/// Validates a key against the selected provider and nothing else.
///
/// Issue #31/#38: there is no fallback path. A failure is reported for the
/// provider the user chose; the key is never retried against the other provider
/// and a single validation never retries itself.
class JevKeyValidator {
  JevKeyValidator({JevProbe? probe}) : _probe = probe ?? JevHttpProbe().call;

  final JevProbe _probe;

  Future<JevValidationResult> validate({
    required JevSelectionState selection,
    required String apiKey,
    String? model,
  }) async {
    final provider = selection.routableProvider;
    if (provider == null) {
      return JevValidationResult(
        provider: selection.provider,
        outcome: null,
        blockedBy: selection.issues,
      );
    }
    final effectiveModel = model ?? provider.model;
    final result = await _probe(
      provider: provider,
      apiKey: apiKey,
      model: effectiveModel,
    );
    return JevValidationResult(
      provider: provider,
      outcome: result.outcome,
      model: effectiveModel,
      detail: result.detail,
    );
  }
}
