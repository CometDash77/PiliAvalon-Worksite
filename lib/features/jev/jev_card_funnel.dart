import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_preference_profile.dart';
import 'package:PiliPlus/features/jev/jev_preference_store.dart';

/// 卡片「不感兴趣」→ 偏好档漏斗（G-07 收敛后的唯一采集点）。
///
/// 只允许在推荐卡片的显式动作回调里调用；面开关的判定在
/// [JevPreferenceStore.record] 内部（isSurfaceEnabled），UI 层不可能忘。
/// 漏斗永远静默失败——它不影响卡片动作本身，也不向上抛。
class JevCardFunnel {
  JevCardFunnel({this.store});

  final JevPreferenceStore? store;

  /// 默认实例；测试可整体替换。
  static JevCardFunnel instance = JevCardFunnel();

  /// 返回是否真的写入了主题（面开关关闭或摘要为空时为 false）。
  Future<bool> recordCardDislike({
    required String title,
    String? displayedReason,
    String? selectedReason,
    required JevSurface surface,
  }) async {
    try {
      return await (store ?? JevPreferenceStore()).record(
        JevDislikeSignal.card(
          title: title,
          displayedReason: displayedReason,
          selectedReason: selectedReason,
        ),
        surface: surface,
      );
    } catch (_) {
      return false;
    }
  }
}
