import 'package:PiliPlus/common/widgets/flutter/list_tile.dart' as custom;
import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/pages/setting/models/shielding_settings.dart';
import 'package:flutter/material.dart' hide ListTile;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

/// A dedicated sub-page for managing recommendation-scope numeric range
/// shielding rules (duration, playbackCount, danmakuCount).
///
/// This page is reachable from 推荐流设置 and pre-configures new rules with
/// scope=recommendation, matchMode=range, for the numeric rule types.
class RecommendRangeShieldingPage extends StatefulWidget {
  const RecommendRangeShieldingPage({
    super.key,
    this.showAppBar = true,
    this.store,
  });

  final bool showAppBar;
  final ShieldSettingsStore? store;

  @override
  State<RecommendRangeShieldingPage> createState() =>
      _RecommendRangeShieldingPageState();
}

class _RecommendRangeShieldingPageState
    extends State<RecommendRangeShieldingPage> {
  static const _allowedTypes = [
    ShieldRuleType.duration,
    ShieldRuleType.playbackCount,
    ShieldRuleType.danmakuCount,
  ];

  late final _store = widget.store ?? ShieldSettingsStore();
  late ShieldRuleSet _ruleSet = _store.snapshot();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await _store.load();
    if (!mounted) return;
    setState(() => _ruleSet = loaded);
  }

  Future<void> _save(ShieldRuleSet ruleSet) async {
    try {
      await _store.save(ruleSet);
      if (!mounted) return;
      setState(() => _ruleSet = ruleSet);
      SmartDialog.showToast('已保存');
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  List<ShieldRule> get _visibleRules =>
      _ruleSet.rules
          .where(
            (rule) =>
                _allowedTypes.contains(rule.type) &&
                rule.scope == ShieldScope.recommendation &&
                rule.matchMode == ShieldMatchMode.range,
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Widget build(BuildContext context) {
    final showAppBar = widget.showAppBar;
    final padding = MediaQuery.viewPaddingOf(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: showAppBar
          ? AppBar(
              title: const Text('推荐流范围屏蔽'),
              actions: [
                IconButton(
                  tooltip: '新增',
                  onPressed: _openEditor,
                  icon: const Icon(Icons.add),
                ),
              ],
            )
          : null,
      body: ListView(
        padding: EdgeInsets.only(
          left: showAppBar ? padding.left : 0,
          right: showAppBar ? padding.right : 0,
          bottom: padding.bottom + 100,
        ),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '为首页推荐流设置时长、播放数、弹幕数的范围屏蔽规则。\n'
              '支持多条规则同时生效（如屏蔽过短和过长的视频）。\n'
              '格式: min..max，如 0..30 或 1200..',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const Divider(height: 1),
          custom.ListTile(
            leading: const Icon(Icons.rule_outlined),
            title: const Text('推荐流范围规则'),
            subtitle: Text(shieldRuleSummary(_visibleRules)),
            trailing: const Icon(Icons.add),
            onTap: _openEditor,
          ),
          if (_ruleSet.loadErrors.isNotEmpty)
            custom.ListTile(
              dense: true,
              leading: Icon(
                Icons.warning_amber_outlined,
                color: ColorScheme.of(context).error,
              ),
              title: Text(
                '规则加载失败，当前已临时关闭屏蔽',
                style: TextStyle(color: ColorScheme.of(context).error),
              ),
              subtitle: Text(_ruleSet.loadErrors.join('\n')),
            ),
          if (_visibleRules.isEmpty)
            custom.ListTile(
              leading: const Icon(Icons.rule_folder_outlined),
              title: const Text('暂无规则'),
              subtitle: const Text('点击右上角或规则入口添加'),
              onTap: _openEditor,
            )
          else
            ..._visibleRules.map(_buildRuleItem),
        ],
      ),
      floatingActionButton: showAppBar
          ? FloatingActionButton(
              tooltip: '新增规则',
              onPressed: _openEditor,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildRuleItem(ShieldRule rule) {
    return custom.ListTile(
      leading: Icon(
        rule.action == ShieldAction.allow
            ? Icons.verified_user_outlined
            : Icons.block_outlined,
      ),
      title: Text(shieldRuleTitle(rule)),
      subtitle: Text(
        '${shieldScopeLabel(rule.scope)} / '
        '${shieldMatchModeLabel(rule.matchMode, type: rule.type)} / '
        '${rule.enabled ? '已启用' : '已停用'}',
      ),
      trailing: Switch(
        value: rule.enabled,
        onChanged: (value) {
          final rules = _ruleSet.rules
              .map(
                (item) => item.id == rule.id
                    ? item.copyWith(enabled: value, updatedAt: DateTime.now())
                    : item,
              )
              .toList();
          _save(_ruleSet.copyWith(rules: rules));
        },
      ),
      onTap: () => _openEditor(rule: rule),
      onLongPress: () => _deleteRule(rule),
    );
  }

  Future<void> _deleteRule(ShieldRule rule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除规则'),
        content: Text(rule.pattern),
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
    await _save(
      _ruleSet.copyWith(
        rules: _ruleSet.rules.where((item) => item.id != rule.id).toList(),
      ),
    );
  }

  Future<void> _openEditor({ShieldRule? rule}) async {
    ShieldRuleType type = rule?.type ?? ShieldRuleType.duration;
    // Always range for this surface.
    const mode = ShieldMatchMode.range;
    // Always recommendation scope.
    const scope = ShieldScope.recommendation;
    ShieldAction action = rule?.action ?? ShieldAction.block;
    bool enabled = rule?.enabled ?? true;
    String pattern = rule?.pattern ?? '';

    final saved = await showDialog<ShieldRule>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(rule == null ? '新增范围规则' : '编辑范围规则'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  autofocus: true,
                  initialValue: pattern,
                  decoration: const InputDecoration(
                    labelText: '数值范围',
                    hintText: '如 0..30 或 1200..',
                  ),
                  onChanged: (value) => pattern = value,
                ),
                const SizedBox(height: 12),
                _dropdown(
                  label: '类型',
                  value: type,
                  values: _allowedTypes,
                  text: shieldRuleTypeLabel,
                  onChanged: (value) => setDialogState(() => type = value),
                ),
                _dropdown(
                  label: '动作',
                  value: action,
                  values: ShieldAction.values,
                  text: shieldActionLabel,
                  onChanged: (value) => setDialogState(() => action = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用'),
                  value: enabled,
                  onChanged: (value) => setDialogState(() => enabled = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('取消')),
            TextButton(
              onPressed: () {
                final trimmed = pattern.trim();
                if (trimmed.isEmpty) {
                  SmartDialog.showToast('数值范围不能为空');
                  return;
                }
                if (!_isValidRangePattern(trimmed)) {
                  SmartDialog.showToast('数值范围无效（格式: min..max）');
                  return;
                }
                Get.back(
                  result: ShieldRule(
                    id:
                        rule?.id ??
                        'manual-${DateTime.now().microsecondsSinceEpoch}',
                    type: type,
                    matchMode: mode,
                    scope: scope,
                    action: action,
                    pattern: trimmed,
                    enabled: enabled,
                    updatedAt: DateTime.now(),
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (saved == null) return;
    final rules = [
      for (final item in _ruleSet.rules)
        if (item.id != saved.id) item,
      saved,
    ];
    await _save(_ruleSet.copyWith(rules: rules));
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T value) text,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (value) => DropdownMenuItem<T>(
              value: value,
              child: Text(text(value)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  bool _isValidRangePattern(String pattern) {
    final match = RegExp(
      r'^\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+)?)\s*\.\.\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+)?)\s*$',
    ).firstMatch(pattern);
    if (match != null) {
      final min = _parseRangeBound(match.group(1));
      final max = _parseRangeBound(match.group(2));
      if (min == null && max == null) return false;
      return min == null || max == null || min <= max;
    }
    return num.tryParse(pattern) != null;
  }

  num? _parseRangeBound(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return num.tryParse(trimmed);
  }
}
