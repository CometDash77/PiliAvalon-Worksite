import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/features/llm/llm_settings.dart';
import 'package:PiliPlus/features/screening/screening_mode.dart';

/// 一次性幂等迁移（issue #142）：把旧的 Jev+LLM 双线并存配置映射到
/// 全局三态模式，绝不静默丢弃、绝不静默选模型。
///
/// 映射规则（维护者拍板）：
/// - 旧双线都活着（Jev 总开关开 + LLM 配置完整已确认）→ `decision`，
///   并落一条可关闭的迁移提示（LLM 配置原样保留）；
/// - 只有 LLM 线活着 → `llm`；
/// - 只有 Jev 线活着 / 两者皆无 → `decision`（新装默认 Decision）。
///
/// 红线：本迁移只写 `piliavalon.screening.v1.*` 键，绝不写、改、删任何
/// `piliavalon.jev.v1.*` / `piliavalon.llm.v1.*` 键；mode 键已存在即
/// no-op；重复执行结果确定（可重入，删掉 mode 键可重跑）。
abstract final class ScreeningModeMigration {
  static bool _done = false;

  /// For tests: re-arm the one-shot latch.
  static void resetForTest() => _done = false;

  static Future<void> ensureRun({
    ScreeningModeStore? store,
    JevSettingsStore? jevSettings,
    LlmSettingsStore? llmSettings,
  }) async {
    // 先落闩：本进程只做一次；失败也不在启动路径上反复重试
    // （键保留，下次启动重试，同 JevCommentCriteriaMigration 先例）。
    _done = true;
    final modeStore = store ?? ScreeningModeStore();
    // 幂等判据：mode 键已在 → 无论值是什么都不再动。
    if ((await modeStore.read()) != null) return;
    final jevLive = await _jevAlive(jevSettings);
    final llmLive = await _llmAlive(llmSettings);
    if (jevLive && llmLive) {
      await modeStore.save(ScreeningEngineMode.decision);
      // 不静默：存量双线被裁成单线，落一条用户可关闭的提示。
      await modeStore.saveNotice(ScreeningModeStore.dualLineNotice);
    } else if (llmLive) {
      await modeStore.save(ScreeningEngineMode.llm);
    } else {
      // 仅 Jev 活 / 双双没配：Decision 默认（维护者拍板）。
      await modeStore.save(ScreeningEngineMode.decision);
    }
  }

  static Future<bool> _jevAlive(JevSettingsStore? jevSettings) async {
    try {
      return (jevSettings ?? JevSettingsStore()).load().enabled;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _llmAlive(LlmSettingsStore? llmSettings) async {
    try {
      final config = await (llmSettings ?? LlmSettingsStore()).load();
      return config.protocol != null &&
          config.confirmed &&
          config.issues.isEmpty;
    } catch (_) {
      return false;
    }
  }
}
