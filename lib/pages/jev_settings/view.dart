// ignore_for_file: deprecated_member_use

import 'package:PiliPlus/common/widgets/flutter/list_tile.dart' as custom;
import 'package:PiliPlus/features/jev/jev.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

/// Settings surface for Jev screening (issue #35, one-page layout).
///
/// The page never selects a provider from the key's shape and never retries a
/// credential against another provider; both rules are visible in the copy.
class JevSettingsPage extends StatefulWidget {
  const JevSettingsPage({
    super.key,
    this.showAppBar = true,
    this.store,
    this.credentialStore,
    this.validator,
    this.preferenceStore,
    this.onMessage,
  });

  final bool showAppBar;
  final JevSettingsStore? store;
  final JevCredentialStore? credentialStore;
  final JevKeyValidator? validator;

  /// The local negative-feedback profile surface (issue #33).
  final JevPreferenceStore? preferenceStore;

  /// Replaces the toast sink in tests.
  final ValueChanged<String>? onMessage;

  @override
  State<JevSettingsPage> createState() => _JevSettingsPageState();
}

class _JevSettingsPageState extends State<JevSettingsPage> {
  late final JevSettingsStore _store = widget.store ?? JevSettingsStore();
  late final JevCredentialStore _credentials =
      widget.credentialStore ?? SecureJevCredentialStore();
  late final JevKeyValidator _validator = widget.validator ?? JevKeyValidator();
  late final JevPreferenceStore _preferences =
      widget.preferenceStore ??
      JevPreferenceStore(box: _store.box, settings: _store);

  final TextEditingController _keyController = TextEditingController();

  late JevSettings _settings = JevSettingsStore.snapshot;
  JevSelectionState _selection = const JevSelectionState();
  JevPreferenceProfile _profile = JevPreferenceProfile.empty;
  JevKeyStoreStatus _keyStoreStatus = JevKeyStoreStatus.available;
  JevValidationResult? _validation;
  bool _busy = false;
  bool _obscureKey = true;
  bool _hasStoredKey = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    final sink = widget.onMessage;
    if (sink != null) {
      sink(message);
      return;
    }
    SmartDialog.showToast(message);
  }

  Future<void> _load() async {
    final settings = await _store.load();
    final profile = await _preferences.load();
    final status = await _credentials.status();
    String? storedKey;
    if (status == JevKeyStoreStatus.available) {
      try {
        storedKey = await _credentials.read();
      } catch (_) {
        storedKey = null;
      }
    }
    if (!mounted) return;
    if (status == JevKeyStoreStatus.unavailable && settings.enabled) {
      // Issue #32: without a usable credential store Jev stays disabled.
      await _saveSettings(settings.copyWith(enabled: false));
      if (!mounted) return;
    }
    setState(() {
      _settings = JevSettingsStore.snapshot;
      _profile = profile;
      _keyStoreStatus = status;
      _hasStoredKey = storedKey != null;
      if (storedKey != null) {
        _keyController.text = storedKey;
      }
      _selection = JevSelectionState(
        provider: _settings.provider,
        keyText: storedKey ?? '',
        mismatchAcknowledged: _settings.providerConfirmed,
      );
    });
  }

  Future<void> _saveSettings(JevSettings next) async {
    try {
      await _store.save(next);
      if (!mounted) return;
      setState(() => _settings = next);
    } catch (error) {
      _toast('保存失败：$error');
    }
  }

  Future<void> _selectProvider(JevProvider provider) async {
    setState(() {
      _selection = _selection.withProvider(provider);
      _validation = null;
    });
    await _saveSettings(
      _settings.copyWith(provider: provider, providerConfirmed: false),
    );
  }

  Future<void> _acknowledgeMismatch() async {
    setState(() => _selection = _selection.acknowledgeMismatch());
    await _saveSettings(
      _settings.copyWith(
        provider: _selection.provider,
        providerConfirmed: true,
      ),
    );
  }

  Future<void> _saveKey() async {
    final key = _selection.trimmedKey;
    try {
      await _credentials.write(key);
    } catch (error) {
      _toast('密钥保存失败：$error');
      return;
    }
    if (!mounted) return;
    setState(() {
      _hasStoredKey = true;
      _validation = null;
    });
    await _saveSettings(
      _settings.copyWith(
        provider: _selection.provider,
        providerConfirmed: _selection.mismatchAcknowledged,
      ),
    );
    _toast('密钥已保存到系统安全存储');
  }

  Future<void> _deleteKey() async {
    if (_keyStoreStatus == JevKeyStoreStatus.available) {
      try {
        await _credentials.delete();
      } catch (error) {
        _toast('清除密钥失败：$error');
        return;
      }
    }
    _keyController.clear();
    if (!mounted) return;
    setState(() {
      _selection = _selection.withKey('');
      _validation = null;
      _hasStoredKey = false;
    });
    await _saveSettings(_settings.copyWith(providerConfirmed: false));
    _toast('已清除密钥');
  }

  Future<void> _validateKey() async {
    setState(() {
      _busy = true;
      _validation = null;
    });
    try {
      final result = await _validator.validate(
        selection: _selection,
        apiKey: _selection.trimmedKey,
      );
      if (!mounted) return;
      setState(() {
        _validation = result;
        _busy = false;
      });
      if (result.validated) {
        await _saveSettings(
          _settings.copyWith(
            provider: result.provider,
            providerConfirmed: true,
          ),
        );
        _toast('验证通过：${result.provider?.label ?? ''}');
      } else {
        _toast(_validationMessage(result));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('验证失败：$error');
    }
  }

  String _keyHintText() => switch (_selection.keyHint) {
    JevKeyHint.empty => 'Key 只保存在系统安全存储，不会写入设置或备份',
    JevKeyHint.openRouterSuggested => '该 Key 形似 OpenRouter 密钥；格式只作提示，提供方仍需你确认',
    JevKeyHint.unrecognized => '无法从格式推断提供方，请在上方手动选择',
  };

  String _validationMessage(JevValidationResult result) {
    final provider = result.provider?.label ?? '所选提供方';
    final base = switch (result.outcome) {
      JevProbeOutcome.ok => '验证通过：$provider',
      JevProbeOutcome.invalidKey => '$provider 拒绝了该密钥（401），请检查密钥与提供方选择',
      JevProbeOutcome.rateLimited => '$provider 限流或过载，稍后再试；候选保持可见',
      JevProbeOutcome.rejectedRequest => '$provider 拒绝了请求格式（不判定为密钥问题）',
      JevProbeOutcome.serverError => '$provider 服务端错误，稍后再试',
      JevProbeOutcome.timeout => '$provider 请求超时，稍后再试',
      JevProbeOutcome.networkError => '网络不可达，请检查网络后重试',
      JevProbeOutcome.malformedResponse => '$provider 响应无法解析，稍后再试',
      null => '尚未发起验证',
    };
    // Issue #101: when the provider explained itself (status + message), show
    // it; without a detail the stable copy above stays the whole message.
    final detail = result.detail;
    if (detail == null || detail.isEmpty || result.validated) return base;
    return '$base（上游：$detail）';
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    final showAppBar = widget.showAppBar;
    final errorColor = ColorScheme.of(context).error;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: showAppBar ? AppBar(title: const Text('Jev 智能筛选')) : null,
      body: ListView(
        padding: EdgeInsets.only(
          left: showAppBar ? padding.left : 0,
          right: showAppBar ? padding.right : 0,
          bottom: padding.bottom + 100,
        ),
        children: [
          ..._buildSwitchSection(),
          const Divider(height: 1),
          ..._buildProfileSection(),
          const Divider(height: 1),
          ..._buildProviderSection(errorColor),
          const Divider(height: 1),
          ..._buildKeySection(errorColor),
          const Divider(height: 1),
          ..._buildComplianceSection(),
          _buildPrivacySection(),
        ],
      ),
    );
  }

  List<Widget> _buildSwitchSection() => [
    SwitchListTile(
      secondary: const Icon(Icons.psychology_outlined),
      title: const Text('启用 Jev 智能筛选'),
      subtitle: const Text('在所有更便宜的过滤之后，对幸存候选做最后一次语义判断'),
      value: _settings.enabled,
      onChanged: _keyStoreStatus == JevKeyStoreStatus.unavailable
          ? null
          : (value) => _saveSettings(_settings.copyWith(enabled: value)),
    ),
    const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text('推荐面（各自的开关）'),
    ),
    for (final surface in JevSurface.values)
      SwitchListTile(
        dense: true,
        secondary: const Icon(Icons.filter_alt_outlined),
        title: Text(surface.label),
        value: _settings.surfaces.contains(surface),
        onChanged: _settings.enabled
            ? (value) =>
                  _saveSettings(_settings.withSurface(surface, value: value))
            : null,
      ),
  ];

  List<Widget> _buildProviderSection(Color errorColor) => [
    const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text('服务提供方（必须显式选择）'),
    ),
    for (final provider in JevProvider.values)
      custom.ListTile(
        leading: Icon(
          _settings.provider == provider
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
        ),
        title: Text(provider.label),
        subtitle: Text(
          provider == JevProvider.typeSafe
              ? '直连 TypeSafe System One（model: ${provider.model}）'
              : '经 OpenRouter Jev Decisions（model: ${provider.model}）',
        ),
        onTap: () => _selectProvider(provider),
      ),
    if (_selection.isBlockedByMismatch)
      custom.ListTile(
        leading: Icon(Icons.warning_amber_outlined, color: errorColor),
        title: Text(
          '格式提示与已选提供方不一致',
          style: TextStyle(color: errorColor),
        ),
        subtitle: const Text('格式识别不决定提供方。确认后才会按已选提供方验证，绝不会把该 Key 发给另一个提供方。'),
        trailing: TextButton(
          onPressed: _acknowledgeMismatch,
          child: const Text('确认'),
        ),
      ),
  ];

  List<Widget> _buildKeySection(Color errorColor) => [
    if (_keyStoreStatus == JevKeyStoreStatus.unavailable)
      custom.ListTile(
        leading: Icon(Icons.lock_outline, color: errorColor),
        title: Text(
          '系统安全存储不可用，Jev 保持关闭',
          style: TextStyle(color: errorColor),
        ),
        subtitle: const Text('无法安全保存密钥时不会使用任何凭据，也不会退回明文存储。'),
      ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _keyController,
        obscureText: _obscureKey,
        enabled: _keyStoreStatus == JevKeyStoreStatus.available,
        decoration: InputDecoration(
          labelText: 'API Key（你自己的密钥）',
          border: const OutlineInputBorder(),
          helperMaxLines: 3,
          helperText: _keyHintText(),
          suffixIcon: IconButton(
            tooltip: _obscureKey ? '显示' : '隐藏',
            onPressed: () => setState(() => _obscureKey = !_obscureKey),
            icon: Icon(
              _obscureKey
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        onChanged: (value) => setState(() {
          _selection = _selection.withKey(value);
          _validation = null;
        }),
      ),
    ),
    custom.ListTile(
      leading: Icon(
        _hasStoredKey ? Icons.check_circle_outline : Icons.help_outline,
      ),
      title: Text(_hasStoredKey ? '密钥已保存在系统安全存储' : '尚未保存密钥'),
      subtitle: const Text('密钥不进 Hive、不进设置导出，也不进 WebDAV 备份'),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          TextButton(
            onPressed:
                _keyStoreStatus == JevKeyStoreStatus.available &&
                    _selection.canValidate
                ? _saveKey
                : null,
            child: const Text('保存密钥'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _busy || !_selection.canValidate ? null : _validateKey,
            child: Text(_busy ? '验证中…' : '验证'),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: _deleteKey, child: const Text('清除密钥')),
        ],
      ),
    ),
    for (final issue in _selection.issues)
      custom.ListTile(
        dense: true,
        leading: Icon(Icons.error_outline, color: errorColor),
        title: Text(issue.message, style: TextStyle(color: errorColor)),
      ),
    if (_validation != null)
      custom.ListTile(
        dense: true,
        leading: Icon(
          _validation!.validated
              ? Icons.verified_outlined
              : Icons.error_outline,
          color: _validation!.validated ? null : errorColor,
        ),
        title: Text(_validationMessage(_validation!)),
      ),
  ];

  String _themeAge(JevPreferenceTheme theme) {
    final days = DateTime.now().difference(theme.lastFeedbackAt).inDays;
    final age = days <= 0 ? '今天' : '$days 天前';
    final count = theme.count;
    return '≈$count 次 · 最后反馈 $age';
  }

  Future<void> _deleteTheme(String theme) async {
    await _preferences.deleteTheme(theme);
    if (!mounted) return;
    setState(() => _profile = JevPreferenceStore.snapshot);
  }

  Future<void> _clearProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空本地偏好档'),
        content: const Text('清空后不再向 Jev 发送任何负主题。平台侧已提交的反馈不受影响，也不会被撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _preferences.clear();
    if (!mounted) return;
    setState(() => _profile = JevPreferenceStore.snapshot);
  }

  /// The local explicit negative profile is visible and deletable at all times,
  /// including while Jev is off — that is when it stops collecting, not when it
  /// stops existing (issue #33).
  List<Widget> _buildProfileSection() => [
    const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text('本地负反馈档（只收集推荐卡片上的显式「不感兴趣」）'),
    ),
    if (!_settings.enabled)
      const custom.ListTile(
        dense: true,
        leading: Icon(Icons.pause_circle_outline),
        title: Text('Jev 已关闭：暂停收集，档与过期计时保留'),
      ),
    if (_profile.isEmpty)
      const custom.ListTile(
        dense: true,
        leading: Icon(Icons.inbox_outlined),
        title: Text('档为空'),
        subtitle: Text('详情页点踩、评论互动、跳过与观看行为都不进这份档'),
      )
    else ...[
      for (final theme in _profile.themes)
        custom.ListTile(
          dense: true,
          leading: const Icon(Icons.label_outline),
          title: Text(theme.theme),
          subtitle: Text(_themeAge(theme)),
          trailing: IconButton(
            tooltip: '删除该主题',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteTheme(theme.theme),
          ),
        ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Text(
          '最多保留 20 个主题：满额时先淘汰最近反馈最早的一个，6 个月没有新反馈的主题自动删除。',
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextButton(
          onPressed: _clearProfile,
          child: const Text('清空偏好档'),
        ),
      ),
    ],
  ];

  List<Widget> _buildComplianceSection() => const [
    custom.ListTile(
      dense: true,
      leading: Icon(Icons.info_outline),
      title: Text('格式识别不决定提供方：密钥形似某个提供方也不会自动切换'),
    ),
    custom.ListTile(
      dense: true,
      leading: Icon(Icons.info_outline),
      title: Text('密钥只在已选提供方上验证，失败时绝不会拿去另一个提供方重试'),
    ),
    custom.ListTile(
      dense: true,
      leading: Icon(Icons.info_outline),
      title: Text('平台侧「撤销」只取消平台反馈，不回滚本地主题计数：档里的计数只能由你手动删除'),
    ),
  ];

  Widget _buildPrivacySection() => const ExpansionTile(
    leading: Icon(Icons.privacy_tip_outlined),
    title: Text('隐私说明'),
    subtitle: Text('只发送最小候选字段与本地显式负反馈摘要'),
    childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 12),
    children: [
      Text('发送：候选标题，以及候选数据自带时的短简介或分类/标签；最多 20 个未过期负主题及大致次数。'),
      SizedBox(height: 8),
      Text('不发送：完整浏览/观看历史、账号标识、cookie、原始点踩记录、UP 主、视频 ID、链接、长篇元数据。'),
      SizedBox(height: 8),
      Text('低置信、超时、限流、缺答、密钥缺失或无效、provider 报错、安全存储不可用时，候选一律保持可见。'),
    ],
  );
}
