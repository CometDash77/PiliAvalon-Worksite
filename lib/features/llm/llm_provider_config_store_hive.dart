import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/features/llm/llm_provider_config_store.dart';
import 'package:PiliPlus/utils/storage.dart';

/// Issue #144: production entry point for the per-provider config store.
/// Split from llm_provider_config_store.dart so that tests exercising the
/// store logic can inject a fake [JevSettingsBox] without compiling the
/// storage/UI dependency chain (GStorage pulls in scaffold widgets whose
/// third-party dependency surface is currently uncompilable locally).
LlmProviderConfigStore createDefaultLlmProviderConfigStore() =>
    LlmProviderConfigStore(box: HiveJevSettingsBox(GStorage.setting));
