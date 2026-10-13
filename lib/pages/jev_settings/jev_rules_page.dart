import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:material_ui/material_ui.dart';

String _targetLabel(JevRuleTarget target) => switch (target) {
  JevRuleTarget.video => '视频',
  JevRuleTarget.comment => '评论',
  JevRuleTarget.live => '直播间',
};

String _scope(JevRuleTarget target) => switch (target) {
  JevRuleTarget.video => '首页、相关、热门、排行、PGC、音乐推荐；沿用各入口开关。',
  JevRuleTarget.comment => '仅视频详情评论正文及必要回复上下文，不筛选实时弹幕。',
  JevRuleTarget.live => '仅直播推荐卡片的标题、分区等现有内容，不读取房间消息。',
};

/// Local rule management; saving does not make a network request.
class JevRulesPage extends StatefulWidget {
  const JevRulesPage({super.key, this.store});
  final JevRuleStore? store;

  @override
  State<JevRulesPage> createState() => _JevRulesPageState();
}

class _JevRulesPageState extends State<JevRulesPage> {
  late final JevRuleStore _store = widget.store ?? JevRuleStore();
  JevRuleConfig? _config;
  JevRuleTarget _target = JevRuleTarget.video;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await _store.load();
      if (mounted) {
        setState(() {
          _config = config;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '读取规则失败，请重试');
    }
  }

  Future<bool> _save(JevRuleConfig next) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      await _store.save(next);
      if (!mounted) return false;
      setState(() {
        _config = next;
        _error = null;
      });
      return true;
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，原有规则已保留，请重试');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit([JevRule? rule]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _RuleEditor(
          target: _target,
          initial: rule,
          onSave: (next) {
            final config = _config!;
            return _save(
              JevRuleConfig(
                rules: [
                  for (final existing in config.rules)
                    if (existing.id != next.id) existing,
                  next,
                ],
                disabledBuiltins: config.disabledBuiltins,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _delete(JevRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除规则？'),
        content: Text(rule.question),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final config = _config!;
    await _save(
      JevRuleConfig(
        rules: config.rules.where((r) => r.id != rule.id).toList(),
        disabledBuiltins: config.disabledBuiltins,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final rules =
        config?.rules.where((r) => r.target == _target).toList() ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Jev 判断规则')),
      body: config == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : TextButton(onPressed: _load, child: Text('$_error · 重试')),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<JevRuleTarget>(
                  segments: [
                    for (final target in JevRuleTarget.values)
                      ButtonSegment(
                        value: target,
                        label: Text(_targetLabel(target)),
                      ),
                  ],
                  selected: {_target},
                  onSelectionChanged: _saving
                      ? null
                      : (value) => setState(() => _target = value.single),
                ),
                const SizedBox(height: 16),
                Text(_scope(_target)),
                const SizedBox(height: 8),
                const Text('任一启用规则达到阈值就隐藏；不命中、不确定、信息不足或请求失败时正常展示。'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_target != JevRuleTarget.comment)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('根据不感兴趣主题筛选（内置）'),
                    subtitle: const Text('与自定义规则并列，可独立启停'),
                    value: !config.disabledBuiltins.contains(_target),
                    onChanged: _saving
                        ? null
                        : (enabled) {
                            final disabled = {...config.disabledBuiltins};
                            enabled
                                ? disabled.remove(_target)
                                : disabled.add(_target);
                            _save(
                              JevRuleConfig(
                                rules: config.rules,
                                disabledBuiltins: disabled,
                              ),
                            );
                          },
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      _saving || rules.length >= JevRule.maxRulesPerTarget
                      ? null
                      : _edit,
                  icon: const Icon(Icons.add),
                  label: const Text('添加规则'),
                ),
                const Text('每个场景最多 ${JevRule.maxRulesPerTarget} 条自定义规则'),
                if (rules.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('还没有自定义规则。填写你想判断的问题。'),
                  ),
                for (final rule in rules)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rule.question,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${rule.type == JevRuleType.noul ? 'Yes / No' : '选择题'} · 阈值 ${(rule.threshold * 100).round()}%',
                          ),
                          Text(
                            '隐藏条件：${rule.type == JevRuleType.noul ? (rule.hideOnYes ? 'Yes' : 'No') : rule.options.where((o) => rule.hiddenOptions.contains(o.id)).map((o) => o.label).join('、')}',
                          ),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Switch(
                                value: rule.enabled,
                                onChanged: _saving
                                    ? null
                                    : (enabled) => _save(
                                        JevRuleConfig(
                                          rules: [
                                            for (final r in config.rules)
                                              r.id == rule.id
                                                  ? r.copyWith(enabled: enabled)
                                                  : r,
                                          ],
                                          disabledBuiltins:
                                              config.disabledBuiltins,
                                        ),
                                      ),
                              ),
                              Text(rule.enabled ? '已启用' : '已停用'),
                              TextButton(
                                onPressed: _saving ? null : () => _edit(rule),
                                child: const Text('编辑'),
                              ),
                              TextButton(
                                onPressed: _saving ? null : () => _delete(rule),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _OptionDraft {
  _OptionDraft(this.id, String label, String description, this.hidden)
    : label = TextEditingController(text: label),
      description = TextEditingController(text: description);
  final String id;
  final TextEditingController label;
  final TextEditingController description;
  bool hidden;
  void dispose() {
    label.dispose();
    description.dispose();
  }
}

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({required this.target, required this.onSave, this.initial});
  final JevRuleTarget target;
  final JevRule? initial;
  final Future<bool> Function(JevRule) onSave;
  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late final _question = TextEditingController(
    text: widget.initial?.question ?? '',
  );
  late final _yes = TextEditingController(
    text: widget.initial?.yesMeaning ?? '',
  );
  late final _no = TextEditingController(text: widget.initial?.noMeaning ?? '');
  late JevRuleType _type = widget.initial?.type ?? JevRuleType.noul;
  late bool _hideOnYes = widget.initial?.hideOnYes ?? true;
  late bool _enabled = widget.initial?.enabled ?? true;
  late double _threshold = widget.initial?.threshold ?? .95;
  late final String _id =
      widget.initial?.id ?? 'rule-${DateTime.now().microsecondsSinceEpoch}';
  late final List<_OptionDraft> _options = [
    for (final o in widget.initial?.options ?? <JevRuleOption>[])
      _OptionDraft(
        o.id,
        o.label,
        o.description,
        widget.initial!.hiddenOptions.contains(o.id),
      ),
  ];
  final List<_OptionDraft> _removedOptions = [];
  int _optionSequence = 0;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _question.dispose();
    _yes.dispose();
    _no.dispose();
    for (final o in [..._options, ..._removedOptions]) {
      o.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final rule = JevRule(
      id: _id,
      target: widget.target,
      question: _question.text.trim(),
      type: _type,
      enabled: _enabled,
      threshold: _threshold,
      hideOnYes: _hideOnYes,
      yesMeaning: _yes.text.trim(),
      noMeaning: _no.text.trim(),
      options: [
        for (final o in _options)
          JevRuleOption(
            id: o.id,
            label: o.label.text.trim(),
            description: o.description.text.trim(),
          ),
      ],
      hiddenOptions: {
        for (final o in _options)
          if (o.hidden) o.id,
      },
    );
    final error = rule.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.onSave(rule);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = '保存失败，草稿已保留，请重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? '添加规则' : '编辑规则')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('适用于${_targetLabel(widget.target)}；取消不会修改已保存规则。'),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('rule-question'),
            controller: _question,
            enabled: !_saving,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: '你想判断的问题',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<JevRuleType>(
            segments: const [
              ButtonSegment(value: JevRuleType.noul, label: Text('Yes / No')),
              ButtonSegment(value: JevRuleType.choice, label: Text('选择题')),
            ],
            selected: {_type},
            onSelectionChanged: _saving
                ? null
                : (value) => setState(() => _type = value.single),
          ),
          const SizedBox(height: 16),
          if (_type == JevRuleType.noul) ...[
            TextField(
              controller: _yes,
              maxLength: 400,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Yes 的含义（选填）'),
            ),
            TextField(
              controller: _no,
              maxLength: 400,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'No 的含义（选填）'),
            ),
            const SizedBox(height: 16),
            const Text('哪个答案达到阈值时隐藏'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Yes')),
                ButtonSegment(value: false, label: Text('No')),
              ],
              selected: {_hideOnYes},
              onSelectionChanged: _saving
                  ? null
                  : (value) => setState(() => _hideOnYes = value.single),
            ),
          ] else ...[
            const Text('模型每次只选一个答案；可勾选多个选到就隐藏的选项。'),
            for (final option in _options)
              Card(
                key: ValueKey(option.id),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: option.label,
                        maxLength: 80,
                        enabled: !_saving,
                        decoration: const InputDecoration(labelText: '选项名称'),
                      ),
                      TextField(
                        controller: option.description,
                        maxLength: 400,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: '含义说明（选填）',
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('选到此答案时隐藏'),
                              value: option.hidden,
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() => option.hidden = v!),
                            ),
                          ),
                          IconButton(
                            tooltip: '删除选项',
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                    _options.remove(option);
                                    _removedOptions.add(option);
                                  }),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: _saving || _options.length >= JevRule.maxOptions
                  ? null
                  : () => setState(
                      () => _options.add(
                        _OptionDraft(
                          '$_id-option-${++_optionSequence}-${DateTime.now().microsecondsSinceEpoch}',
                          '',
                          '',
                          false,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.add),
              label: const Text('添加选项'),
            ),
            const Text('选择题需要 2–20 个名称不同的选项，至少勾选一个隐藏答案。'),
          ],
          const SizedBox(height: 16),
          Text('执行阈值：${(_threshold * 100).round()}%'),
          Slider(
            key: const ValueKey('rule-threshold'),
            min: .5,
            max: 1,
            divisions: 50,
            value: _threshold,
            label: '${(_threshold * 100).round()}%',
            onChanged: _saving
                ? null
                : (value) => setState(() => _threshold = value),
          ),
          Text(
            _type == JevRuleType.noul
                ? '选择 Yes 时使用 Yes 概率；选择 No 时使用 No 概率。'
                : '返回选项在隐藏集合内，且模型置信度达到阈值才隐藏。',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('启用此规则'),
            value: _enabled,
            onChanged: _saving
                ? null
                : (value) => setState(() => _enabled = value),
          ),
          if (_error != null)
            Text(
              _error!,
              key: const ValueKey('rule-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存规则'),
          ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
