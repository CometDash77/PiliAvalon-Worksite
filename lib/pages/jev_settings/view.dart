import 'package:PiliPlus/features/jev/jev_feedback_profile.dart';
import 'package:PiliPlus/features/jev/jev_models.dart';
import 'package:PiliPlus/features/jev/jev_evaluator.dart';
import 'package:PiliPlus/features/jev/jev_secure_key_store.dart';
import 'package:PiliPlus/features/jev/jev_storage.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the failure copy for one validation round-trip (issue #101): the
/// classification stays stable, the upstream status + message summary rides
/// along only when present, and copy falls back cleanly when it is not.
String jevValidationFailureMessage(DioException error) {
  final base = switch (error.response?.statusCode) {
    401 => '当前 Provider 未接受此密钥。请检查 provider 选择和密钥后重新保存。',
    429 || 529 => '当前 Provider 暂时限流或繁忙，请稍后重试。',
    400 || 422 => '当前 Provider 拒绝了验证请求；请更新应用后重试。',
    _ => '无法连接当前 Provider。请检查网络后重试。',
  };
  final detail = jevUpstreamErrorDetail(error.response?.statusCode, error.response?.data);
  return detail == null
      ? '$base 密钥不会尝试发送给其他 Provider。'
      : '$base 上游响应：$detail。密钥不会尝试发送给其他 Provider。';
}

class JevSettingsPage extends StatefulWidget {
  const JevSettingsPage({super.key});

  @override
  State<JevSettingsPage> createState() => _JevSettingsPageState();
}

class _JevSettingsPageState extends State<JevSettingsPage> {
  final _settingsStore = createJevSettingsStore();
  final _profile = createJevFeedbackProfile();
  final _credentials = JevCredentialStore(FlutterJevSecretStorage());
  late JevSettings _settings;
  bool _secureStoreAvailable = false;
  bool _hasKey = false;
  bool _privacyExpanded = false;
  bool _busy = true;
  bool _validating = false;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _settings = _settingsStore.load();
    _loadSecureState();
  }

  Future<void> _loadSecureState() async {
    await _profile.pruneExpired();
    final available = await _credentials.available;
    final provider = _settings.provider;
    final storedKey = available && provider != null ? await _credentials.read(provider) : null;
    if (!mounted) return;
    setState(() {
      _secureStoreAvailable = available;
      _hasKey = storedKey?.isNotEmpty == true;
      _busy = false;
    });
  }

  Future<void> _update(JevSettings next) async {
    await _settingsStore.save(next);
    if (mounted) setState(() => _settings = next);
  }

  Future<void> _enterKey() async {
    if (!_secureStoreAvailable || _settings.provider == null) return;
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('保存 provider 密钥'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: '密钥'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              try {
              final input = controller.text.trim();
              if (_settings.provider == JevProvider.typeSafe && input.startsWith('sk-or-v1-')) {
                final confirmed = await showDialog<bool>(
                  context: dialogContext,
                  builder: (context) => AlertDialog(
                    title: const Text('密钥格式与所选 Provider 不同'),
                    content: const Text('此格式常见于 OpenRouter。系统不会替你更换 Provider，也不会把密钥发送给另一个 Provider。确认继续将其保存为 TypeSafe 密钥吗？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('返回')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('仍保存到 TypeSafe')),
                    ],
                  ),
                );
                if (confirmed != true) return;
              }
              await _credentials.save(provider: _settings.provider!, value: input);
                controller.clear();
                if (!mounted) return;
                Navigator.pop(dialogContext);
                await _loadSecureState();
                SmartDialog.showToast('密钥已保存在系统安全存储中');
              } catch (_) {
                controller.clear();
                SmartDialog.showToast('安全存储不可用，未保存密钥');
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.clear();
    controller.dispose();
  }

  Future<void> _deleteKey() async {
    try {
      final provider = _settings.provider;
      if (provider == null) return;
      await _credentials.delete(provider);
      await _update(_settings.copyWith(enabled: false));
      if (mounted) setState(() => _hasKey = false);
      SmartDialog.showToast('已删除密钥');
    } catch (_) {
      SmartDialog.showToast('无法访问安全存储');
    }
  }

  Future<void> _validateProvider() async {
    final provider = _settings.provider;
    if (provider == null || !_secureStoreAvailable) return;
    setState(() {
      _validating = true;
      _validationMessage = null;
    });
    try {
      final key = await _credentials.read(provider);
      if (key == null || key.isEmpty) throw StateError('missing credential');
      final result = await JevHttpEvaluator().evaluate(
        provider: provider,
        key: key,
        candidates: const [
          JevCandidate(title: '合成测试推荐：夜间列车旅行纪录片', category: '旅行'),
        ],
        negativeThemes: const [
          {'label': '列车旅行', 'approximate_count': 1},
        ],
        timeout: const Duration(seconds: 12),
      );
      if (!result.containsKey(0)) throw StateError('missing answer');
      if (mounted) setState(() => _validationMessage = 'Provider 验证成功');
    } on DioException catch (error) {
      if (mounted) setState(() => _validationMessage = jevValidationFailureMessage(error));
    } catch (_) {
      if (mounted) setState(() => _validationMessage = '验证失败。请检查所选 Provider、密钥和网络；密钥不会尝试发送给其他 Provider。');
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  @override
  Widget build(BuildContext context) => SimpleScaffold(
    appBar: AppBar(title: const Text('Jev 个性化筛选')),
    body: _busy
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.only(bottom: 48),
            children: [
              SwitchListTile(
                title: const Text('启用 Jev'),
                subtitle: Text(_secureStoreAvailable && _hasKey
                    ? '仅在本地规则过滤后评估推荐'
                    : '需要可用的安全存储、provider 和密钥'),
                value: _settings.enabled,
                onChanged: _secureStoreAvailable && _hasKey && _settings.provider != null
                    ? (value) => _update(_settings.copyWith(enabled: value))
                    : null,
              ),
              ListTile(
                title: const Text('Provider'),
                subtitle: Text('${_settings.provider?.name == 'typeSafe' ? 'TypeSafe' : _settings.provider == null ? '尚未选择' : 'OpenRouter'}；必须手动选择，密钥格式不会自动切换 Provider'),
                trailing: DropdownButton<JevProvider>(
                  value: _settings.provider,
                  hint: const Text('选择'),
                  items: const [
                    DropdownMenuItem(value: JevProvider.typeSafe, child: Text('TypeSafe')),
                    DropdownMenuItem(value: JevProvider.openRouter, child: Text('OpenRouter')),
                  ],
                  onChanged: (provider) {
                    if (provider != null && provider != _settings.provider) {
                      _update(_settings.copyWith(provider: provider, enabled: false)).then((_) => _loadSecureState());
                    }
                  },
                ),
              ),
              ListTile(
                title: const Text('Provider 连接验证'),
                subtitle: Text(_validationMessage ?? '使用合成样例，只请求当前选择的 Provider'),
                trailing: FilledButton.tonal(
                  onPressed: _hasKey && _settings.provider != null && !_validating ? _validateProvider : null,
                  child: _validating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('验证'),
                ),
              ),
              ListTile(
                title: const Text('Provider 密钥'),
                subtitle: Text(!_secureStoreAvailable ? '本设备的安全存储不可用；Jev 已禁用' : _hasKey ? '密钥仅保存在系统安全存储中' : '尚未保存'),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    TextButton(onPressed: _secureStoreAvailable && _settings.provider != null ? _enterKey : null, child: Text(_hasKey ? '更换' : '添加')),
                    if (_hasKey) IconButton(onPressed: _deleteKey, icon: const Icon(Icons.delete_outline), tooltip: '删除密钥'),
                  ],
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('独立推荐场景开关', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              for (final surface in JevSurface.values)
                SwitchListTile(
                  title: Text(surface.label),
                  value: _settings.surfaceEnabled[surface] ?? true,
                  onChanged: (value) => _update(_settings.copyWith(
                    surfaceEnabled: {..._settings.surfaceEnabled, surface: value},
                  )),
                ),
              const Divider(),
              ListTile(
                title: const Text('本地负反馈主题'),
                subtitle: Text('${_profile.load().length} / ${JevFeedbackProfile.maxThemes} 个主题；六个月后过期'),
                trailing: TextButton(
                  onPressed: _profile.load().isEmpty ? null : () async {
                    await _profile.deleteAll();
                    if (mounted) setState(() {});
                  },
                  child: const Text('清空'),
                ),
              ),
              for (final theme in _profile.load())
                ListTile(
                    title: Text(theme.label),
                  subtitle: Text('约 ${theme.count} 次'),
                  trailing: IconButton(
                    tooltip: '删除主题',
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      await _profile.deleteTheme(theme.label);
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              const Divider(),
              ListTile(
                title: const Text('隐私说明'),
                subtitle: Text(_privacyExpanded
                    ? '只发送候选标题及已有的短简介、分类或标签，以及最多 20 个本地归纳主题和大致次数。不发送观看/浏览历史、账号标识、Cookie、原始点踩记录、视频 ID、链接或作者信息。关闭 Jev 时暂停收集，已有主题继续过期。'
                    : '发送最少候选信息与本地负反馈主题'),
                trailing: Icon(_privacyExpanded ? Icons.expand_less : Icons.expand_more),
                onTap: () => setState(() => _privacyExpanded = !_privacyExpanded),
              ),
              if (!_secureStoreAvailable)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('安全存储不可用时不会使用或保存 Jev 密钥。', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
  );
}
