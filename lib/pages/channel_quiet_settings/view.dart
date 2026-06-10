import 'package:PiliPlus/common/widgets/flutter/list_tile.dart' as custom;
import 'package:PiliPlus/pages/video/channel_quiet/channel_quiet_rule.dart';
import 'package:PiliPlus/pages/video/channel_quiet/channel_quiet_store.dart';
import 'package:flutter/material.dart' hide ListTile;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class ChannelQuietSettingsPage extends StatefulWidget {
  const ChannelQuietSettingsPage({
    super.key,
    this.showAppBar = true,
    this.store,
  });

  final bool showAppBar;
  final ChannelQuietStore? store;

  @override
  State<ChannelQuietSettingsPage> createState() =>
      _ChannelQuietSettingsPageState();
}

class _ChannelQuietSettingsPageState extends State<ChannelQuietSettingsPage> {
  late final ChannelQuietStore _store = widget.store ?? ChannelQuietStore();
  List<ChannelQuietRule> _rules = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rules = await _store.load();
    if (!mounted) return;
    setState(() {
      _rules = _sortRules(rules);
      _loaded = true;
    });
  }

  Future<void> _saveRule(ChannelQuietRule rule) async {
    try {
      await _store.update(
        key: rule.key,
        channelName: rule.channelName,
        hideComments: rule.hideComments,
        hideDanmaku: rule.hideDanmaku,
      );
      await _load();
      SmartDialog.showToast('已保存');
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  Future<void> _deleteRule(ChannelQuietRule rule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除频道屏蔽'),
        content: Text(_ruleTitle(rule)),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _store.delete(rule.key);
      await _load();
      SmartDialog.showToast('已删除');
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    final showAppBar = widget.showAppBar;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: showAppBar ? AppBar(title: const Text('频道屏蔽')) : null,
      body: ListView(
        padding: EdgeInsets.only(
          left: showAppBar ? padding.left : 0,
          right: showAppBar ? padding.right : 0,
          bottom: padding.bottom + 100,
        ),
        children: [
          custom.ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: const Text('持久频道屏蔽'),
            subtitle: Text(_summary),
          ),
          const Divider(height: 1),
          if (!_loaded)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_rules.isEmpty)
            const custom.ListTile(
              leading: Icon(Icons.rule_folder_outlined),
              title: Text('暂无频道规则'),
              subtitle: Text('可在视频详情页的更多菜单添加当前频道'),
            )
          else
            ..._rules.map(_buildRuleItem),
        ],
      ),
    );
  }

  String get _summary {
    if (!_loaded) return '正在加载';
    if (_rules.isEmpty) return '还未添加频道规则';
    final comments = _rules.where((rule) => rule.hideComments).length;
    final danmaku = _rules.where((rule) => rule.hideDanmaku).length;
    return '${_rules.length} 条规则 / 评论 $comments / 弹幕 $danmaku';
  }

  Widget _buildRuleItem(ChannelQuietRule rule) {
    final isActive = rule.hideComments || rule.hideDanmaku;
    return custom.ListTile(
      leading: Icon(_ruleIcon(rule)),
      title: Text(_ruleTitle(rule)),
      subtitle: Text(_ruleSubtitle(rule)),
      trailing: Switch(
        value: isActive,
        onChanged: (_) => _toggleRuleActive(rule),
      ),
      onTap: () => _openEditor(rule),
      onLongPress: () => _deleteRule(rule),
    );
  }

  Future<void> _toggleRuleActive(ChannelQuietRule rule) async {
    final isActive = rule.hideComments || rule.hideDanmaku;
    try {
      await _store.update(
        key: rule.key,
        hideComments: !isActive,
        hideDanmaku: !isActive,
      );
      await _load();
      SmartDialog.showToast(isActive ? '已停用' : '已启用');
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  Future<void> _openEditor(ChannelQuietRule rule) async {
    String channelName = rule.channelName;
    bool hideComments = rule.hideComments;
    bool hideDanmaku = rule.hideDanmaku;

    final saved = await showDialog<ChannelQuietRule>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑频道屏蔽'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  autofocus: true,
                  initialValue: channelName,
                  decoration: const InputDecoration(labelText: '频道名称'),
                  onChanged: (value) => channelName = value,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('隐藏评论'),
                  value: hideComments,
                  onChanged: (value) =>
                      setDialogState(() => hideComments = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('隐藏弹幕'),
                  value: hideDanmaku,
                  onChanged: (value) =>
                      setDialogState(() => hideDanmaku = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('取消')),
            TextButton(
              onPressed: () {
                final trimmedName = channelName.trim();
                if (trimmedName.isEmpty) {
                  SmartDialog.showToast('频道名称不能为空');
                  return;
                }
                Get.back(
                  result: rule.copyWith(
                    channelName: trimmedName,
                    hideComments: hideComments,
                    hideDanmaku: hideDanmaku,
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (saved != null) {
      await _saveRule(saved);
    }
  }
}

List<ChannelQuietRule> _sortRules(List<ChannelQuietRule> rules) =>
    [...rules]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

String _ruleTitle(ChannelQuietRule rule) {
  if (rule.channelName.isNotEmpty) return rule.channelName;
  return rule.channelUid;
}

String _ruleSubtitle(ChannelQuietRule rule) =>
    '${_targetTypeLabel(rule.key)} ${rule.channelUid} / ${_actionsLabel(rule)} / '
    '更新 ${_formatDateTime(rule.updatedAt)}';

String _targetTypeLabel(String key) {
  if (key.startsWith('pgc:')) return 'PGC';
  return 'UP';
}

String _actionsLabel(ChannelQuietRule rule) {
  final actions = [
    if (rule.hideComments) '评论',
    if (rule.hideDanmaku) '弹幕',
  ];
  return actions.isEmpty ? '未隐藏' : '隐藏${actions.join('、')}';
}

IconData _ruleIcon(ChannelQuietRule rule) {
  if (rule.hideComments && rule.hideDanmaku) {
    return Icons.visibility_off_outlined;
  }
  if (rule.hideComments) return Icons.forum_outlined;
  if (rule.hideDanmaku) return Icons.subtitles_off_outlined;
  return Icons.visibility_outlined;
}

String _formatDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final month = twoDigits(value.month);
  final day = twoDigits(value.day);
  final hour = twoDigits(value.hour);
  final minute = twoDigits(value.minute);
  return '${value.year}-$month-$day $hour:$minute';
}
