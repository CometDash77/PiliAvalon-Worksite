import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:material_ui/material_ui.dart';

/// Video-face natural-language blocking rules for the generic LLM line
/// (issue #136). Saving does not make a network request.
class LlmVideoRulesPage extends StatefulWidget {
  const LlmVideoRulesPage({super.key, this.store});

  /// Store of the unified rule blob (#141); the retired standalone
  /// LlmVideoRuleStore is only a migration source.
  final JevRuleStore? store;

  @override
  State<LlmVideoRulesPage> createState() => _LlmVideoRulesPageState();
}

class _LlmVideoRulesPageState extends State<LlmVideoRulesPage> {
  late final JevRuleStore _store = widget.store ?? JevRuleStore();
  LlmVideoRuleConfig? _config;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      try {
        // One-shot idempotent legacy migration (#141); a failure must not
        // block editing the unified blob.
        await _store.migrateLegacyLlmVideoRules();
      } catch (_) {}
      final config = LlmVideoRuleConfig(
        rules: (await _store.load()).videoTextRules,
      );
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

  Future<bool> _save(LlmVideoRuleConfig next) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      // Persist into the unified blob, leaving typed rules untouched (#141).
      final full = await _store.load();
      await _store.save(full.copyWith(videoTextRules: next.rules));
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

  Future<void> _edit([LlmVideoRule? rule]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _RuleEditor(
          initial: rule,
          onSave: (next) {
            final config = _config!;
            return _save(
              LlmVideoRuleConfig(
                rules: [
                  for (final existing in config.rules)
                    if (existing.id != next.id) existing,
                  next,
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _delete(LlmVideoRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除规则？'),
        content: Text(rule.text),
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
      LlmVideoRuleConfig(
        rules: config.rules.where((r) => r.id != rule.id).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final rules = config?.rules ?? const <LlmVideoRule>[];
    return Scaffold(
      appBar: AppBar(title: const Text('视频屏蔽规则')),
      body: config == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : TextButton(onPressed: _load, child: Text('$_error · 重试')),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('通用模型逐条判定视频标题与分区/标签上下文；任一启用规则命中就屏蔽并给出理由，不走阈值。'),
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
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      _saving || rules.length >= LlmVideoRule.maxRulesPerSurface
                      ? null
                      : _edit,
                  icon: const Icon(Icons.add),
                  label: const Text('添加规则'),
                ),
                const Text(
                  '最多 ${LlmVideoRule.maxRulesPerSurface} 条，单条 ${LlmVideoRule.maxTextRunes} 字以内。',
                ),
                if (rules.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('还没有视频屏蔽规则。用一句话描述想屏蔽的视频。'),
                  ),
                for (final rule in rules)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rule.text,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Switch(
                                value: rule.enabled,
                                onChanged: _saving
                                    ? null
                                    : (enabled) => _save(
                                        LlmVideoRuleConfig(
                                          rules: [
                                            for (final r in config.rules)
                                              r.id == rule.id
                                                  ? r.copyWith(enabled: enabled)
                                                  : r,
                                          ],
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

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({required this.onSave, this.initial});
  final LlmVideoRule? initial;
  final Future<bool> Function(LlmVideoRule) onSave;
  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late final _text = TextEditingController(text: widget.initial?.text ?? '');
  late bool _enabled = widget.initial?.enabled ?? true;
  late final String _id =
      widget.initial?.id ?? 'rule-${DateTime.now().microsecondsSinceEpoch}';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rule = LlmVideoRule(
      id: _id,
      text: _text.text.trim(),
      enabled: _enabled,
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
          const Text('适用于通用模型线的视频筛选；取消不会修改已保存规则。'),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('rule-text'),
            controller: _text,
            enabled: !_saving,
            maxLines: 5,
            maxLength: LlmVideoRule.maxTextRunes,
            decoration: const InputDecoration(
              labelText: '屏蔽规则（自然语言描述）',
              border: OutlineInputBorder(),
            ),
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
