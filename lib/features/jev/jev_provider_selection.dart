import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_key_format.dart';
import 'package:flutter/foundation.dart' show immutable;

/// Reasons a credential cannot be used yet (issues #31/#38).
enum JevSelectionIssue {
  missingKey('请填写 API Key'),
  missingProvider('请选择服务提供方：TypeSafe 或 OpenRouter'),
  openRouterSuggestion('该 Key 形似 OpenRouter 密钥，请确认提供方为 OpenRouter'),
  providerMismatch('该 Key 形似 OpenRouter 密钥，与已选提供方不一致，需确认后才验证');

  const JevSelectionIssue(this.message);

  final String message;
}

/// The explicit provider choice plus the key the user pasted.
///
/// Nothing here infers a provider from the key: the only hint the product acts
/// on is `sk-or-v1-`, and all it can do is ask the user to confirm.
@immutable
class JevSelectionState {
  const JevSelectionState({
    this.provider,
    this.keyText = '',
    this.mismatchAcknowledged = false,
  });

  /// The provider the user chose; `null` until they choose one.
  final JevProvider? provider;

  final String keyText;

  /// Set once the user confirmed a hint that disagrees with [provider].
  final bool mismatchAcknowledged;

  JevKeyHint get keyHint => JevKeyFormat.hintFor(keyText);

  String get trimmedKey => keyText.trim();

  bool get hasKey => trimmedKey.isNotEmpty;

  /// A `sk-or-v1-` key plus a non-OpenRouter provider blocks validation until
  /// the user confirms; the product never switches provider silently.
  bool get isBlockedByMismatch =>
      provider != null &&
      provider != JevProvider.openRouter &&
      keyHint == JevKeyHint.openRouterSuggested &&
      !mismatchAcknowledged;

  /// Issues that still need a user decision before this credential is usable.
  List<JevSelectionIssue> get issues {
    final result = <JevSelectionIssue>[];
    if (!hasKey) {
      result.add(JevSelectionIssue.missingKey);
    }
    if (provider == null) {
      result.add(JevSelectionIssue.missingProvider);
      if (keyHint == JevKeyHint.openRouterSuggested) {
        result.add(JevSelectionIssue.openRouterSuggestion);
      }
      return result;
    }
    if (isBlockedByMismatch) {
      result.add(JevSelectionIssue.providerMismatch);
    }
    return result;
  }

  /// Whether the credential may be saved or validated right now.
  bool get canValidate => hasKey && provider != null && !isBlockedByMismatch;

  /// The provider a validation call may use, or `null` while blocked.
  JevProvider? get routableProvider => canValidate ? provider : null;

  /// Choosing a provider clears any earlier acknowledgement: a previous
  /// confirmation never carries over to a different provider.
  JevSelectionState withProvider(JevProvider value) =>
      JevSelectionState(provider: value, keyText: keyText);

  /// Editing the key clears any earlier acknowledgement as well.
  JevSelectionState withKey(String value) =>
      JevSelectionState(provider: provider, keyText: value);

  JevSelectionState acknowledgeMismatch() => JevSelectionState(
    provider: provider,
    keyText: keyText,
    mismatchAcknowledged: true,
  );
}
