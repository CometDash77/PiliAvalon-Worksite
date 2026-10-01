import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

abstract final class LiveCardShieldQuickAction {
  static Future<bool> addHostRule({
    required ShieldSettingsStore store,
    required int? uid,
    required Future<void> Function() onRuleSaved,
  }) => _addRule(
    store: store,
    type: ShieldRuleType.uid,
    identity: uid,
    label: '主播 UID',
    onRuleSaved: onRuleSaved,
  );

  static Future<bool> addRoomRule({
    required ShieldSettingsStore store,
    required int? roomId,
    required Future<void> Function() onRuleSaved,
  }) => _addRule(
    store: store,
    type: ShieldRuleType.roomId,
    identity: roomId,
    label: '直播间 ID',
    onRuleSaved: onRuleSaved,
  );

  static Future<void> showChoice({
    required BuildContext context,
    required int? uid,
    required int? roomId,
    required ShieldSettingsStore store,
    required Future<void> Function() onRuleSaved,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择屏蔽目标'),
        actions: [
          TextButton(
            key: const Key('live-shield-host'),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await addHostRule(
                store: store,
                uid: uid,
                onRuleSaved: onRuleSaved,
              );
            },
            child: const Text('屏蔽主播'),
          ),
          TextButton(
            key: const Key('live-shield-room'),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await addRoomRule(
                store: store,
                roomId: roomId,
                onRuleSaved: onRuleSaved,
              );
            },
            child: const Text('屏蔽房间'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  static Future<bool> _addRule({
    required ShieldSettingsStore store,
    required ShieldRuleType type,
    required int? identity,
    required String label,
    required Future<void> Function() onRuleSaved,
  }) async {
    final pattern = identity?.toString();
    if (pattern == null || pattern.isEmpty) {
      SmartDialog.showToast('屏蔽失败：无法获取$label');
      return false;
    }

    try {
      final rule = await store.addQuickActionRule(
        type: type,
        matchMode: ShieldMatchMode.exact,
        scope: ShieldScope.live,
        pattern: pattern,
      );
      await onRuleSaved();
      SmartDialog.showToast(
        rule == null ? '规则已存在：屏蔽$label $pattern' : '已添加：屏蔽$label $pattern',
      );
      return true;
    } catch (error) {
      SmartDialog.showToast('屏蔽失败：$error');
      return false;
    }
  }
}
