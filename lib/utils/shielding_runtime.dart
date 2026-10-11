import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/features/shielding/shielding_store.dart';

/// Composition boundary for persisted shielding rules. Pure filters receive
/// the returned snapshot explicitly; tests can replace this one provider.
abstract final class ShieldingRuntime {
  static ShieldRuleSet Function()? ruleSetProvider;

  static ShieldRuleSet snapshot() =>
      ruleSetProvider?.call() ?? ShieldSettingsStore().snapshot();
}
