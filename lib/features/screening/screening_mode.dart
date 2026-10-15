import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/utils/storage.dart';

/// 全局筛选引擎三态（issue #142）：每次筛选只调度一个后端。
///
/// - [off]：语义筛选整体关闭，Decision/LLM 两线都不跑，上游请求为 0。
/// - [decision]：只跑确定性 Decision 线（Jev 评测器/评论规则），LLM 上游 0 次。
/// - [llm]：只跑通用 LLM 线，Jev 评测器 0 次调用。
enum ScreeningEngineMode {
  off('off'),
  decision('decision'),
  llm('llm');

  const ScreeningEngineMode(this.id);

  final String id;

  static ScreeningEngineMode? tryFromId(String? raw) {
    if (raw == null) return null;
    for (final mode in values) {
      if (mode.id == raw) return mode;
    }
    return null;
  }
}

/// Reads and writes the global screening mode (issue #142).
///
/// 独立 namespace，绝不读写 `piliavalon.jev.v1.*` / `piliavalon.llm.v1.*`：
/// 切换模式不清除、不覆盖任何一方的引擎配置（维护者拍板）。
class ScreeningModeStore {
  ScreeningModeStore({JevSettingsBox? box}) : _boxOrNull = box {
    // 与 LlmSettingsStore 同款懒加载：注入 box 时清静态缓存，
    // 构造期不触 GStorage（测试先建 box 再建 store）。
    if (box != null) {
      _cache = null;
    }
  }

  static const String namespace = 'piliavalon.screening.v1';
  static const String modeKey = '$namespace.mode';
  static const String migrationNoticeKey = '$namespace.migration_notice';

  /// 一次性迁移提示文案（双线存量 → Decision），设置页读取展示。
  static const String dualLineNotice =
      '检测到旧的 Jev+LLM 双线筛选配置，已按新规则切换为 Decision 模式；'
      'LLM 配置已保留，可随时切回。';

  /// 进程内代际计数：任何一次 save() 都会自增。调度层在派发上游请求前
  /// 捕获该值，等待返回后复核——计数变了说明模式被切换，在途的旧模式
  /// 结果整页作废（issue #142 并发切换守卫）。
  static int _generation = 0;
  static int get generation => _generation;

  final JevSettingsBox? _boxOrNull;
  JevSettingsBox? _lazyBox;
  JevSettingsBox get _box =>
      _lazyBox ??= _boxOrNull ?? HiveJevSettingsBox(GStorage.setting);

  static ScreeningEngineMode? _cache;

  /// Last loaded mode, or null before any load.
  static ScreeningEngineMode? get snapshot => _cache;

  static void resetCache() => _cache = null;

  /// 原始读取：键不存在返回 null（迁移幂等判据依据）。
  /// 键存在但值是垃圾串 → 归一为 [ScreeningEngineMode.decision]。
  Future<ScreeningEngineMode?> read() async {
    final raw = _box.get(modeKey);
    if (raw is! String) return null;
    final mode = ScreeningEngineMode.tryFromId(raw);
    return mode ?? ScreeningEngineMode.decision;
  }

  /// 当前生效模式；从未写入过时默认 [ScreeningEngineMode.decision]
  /// （维护者拍板：新装默认 Decision）。
  Future<ScreeningEngineMode> load() async =>
      (await read()) ?? _cache ?? ScreeningEngineMode.decision;

  Future<void> save(ScreeningEngineMode mode) async {
    await _box.put(modeKey, mode.id);
    _cache = mode;
    _generation++;
  }

  Future<String?> readNotice() async {
    final raw = _box.get(migrationNoticeKey);
    if (raw is String && raw.trim().isNotEmpty) return raw;
    return null;
  }

  Future<void> saveNotice(String? notice) async {
    if (notice == null || notice.trim().isEmpty) {
      await _box.delete(migrationNoticeKey);
    } else {
      await _box.put(migrationNoticeKey, notice);
    }
  }
}
