// ignore_for_file: deprecated_member_use

import 'package:PiliPlus/common/widgets/flutter/list_tile.dart' as custom;
import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/llm/llm.dart';
import 'package:PiliPlus/features/screening/screening_mode.dart';
import 'package:PiliPlus/pages/jev_settings/jev_filter_log_section.dart';
import 'package:PiliPlus/pages/jev_settings/jev_rules_hub_page.dart';
import 'package:PiliPlus/pages/jev_settings/jev_screen_log_page.dart';
import 'package:PiliPlus/utils/storage_key.dart';
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
    this.catalog,
    this.llmStore,
    this.llmCredentials,
    this.llmCatalog,
    this.llmProbe,
    this.llmProviderStore,
    this.preferenceStore,
    this.onMessage,
  });

  final bool showAppBar;
  final JevSettingsStore? store;
  final JevCredentialStore? credentialStore;
  final JevKeyValidator? validator;
  final JevModelCatalog? catalog;

  // Issue #131: generic-line provider seams, injected by tests.
  final LlmSettingsStore? llmStore;
  final LlmCredentialStore? llmCredentials;
  final LlmModelCatalog? llmCatalog;
  final LlmHttpProbe? llmProbe;

  // Issue #145: provider-aware store (v2 accounts + per-provider keys).
  final LlmProviderConfigStore? llmProviderStore;

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

  // #105:筛选详情日志与设置共用本 box;测试注入的 store 自动生效。
  late final JevFilterLog _filterLog = JevFilterLog(box: _store.box);

  late final JevModelCatalog _catalog = widget.catalog ?? JevModelCatalog();

  // Issue #131: generic-line provider dependencies and draft state.
  late final LlmSettingsStore _llmStore = widget.llmStore ?? LlmSettingsStore();
  late final LlmCredentialStore _llmCredentials =
      widget.llmCredentials ?? SecureLlmCredentialStore();
  late final LlmModelCatalog _llmCatalog =
      widget.llmCatalog ?? LlmModelCatalog();
  late final LlmHttpProbe _llmProbe = widget.llmProbe ?? LlmHttpProbe();
  // Issue #145: provider-aware section. The v1 store/credentials stay the
  // single write target for the screening line: probe success maps the saved
  // account through llmLegacyMappingFor and writes through, so screening only
  // ever consumes a configuration the probe actually exercised.
  late final LlmProviderConfigStore _provStore =
      widget.llmProviderStore ?? createDefaultLlmProviderConfigStore();
  String _provId = kLlmProviderPresets.first.id;
  LlmProviderAccount _provAccount = LlmProviderAccount(
    providerId: kLlmProviderPresets.first.id,
  );
  // Draft overrides (null = follow the preset default). Nothing here is
  // persisted until 保存配置.
  LlmRouteProtocol? _provDraftProtocol;
  bool? _provDraftIncludesV1;
  bool _provInsecureConfirmed = false;
  bool _provCatalogBusy = false;
  bool _provBusy = false;
  bool _provKeyStored = false;
  bool _llmObscureKey = true;
  int _provGeneration = 0;
  LlmModelCatalogResult? _provCatalogResult;
  LlmProbeResult? _llmProbeResult;
  String? _provMappingError;
  final TextEditingController _llmBaseUrlController = TextEditingController();
  final TextEditingController _llmModelController = TextEditingController();
  final TextEditingController _llmKeyController = TextEditingController();
  final TextEditingController _llmSearchController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  int _generation = 0;
  int _catalogGeneration = 0;
  bool _catalogBusy = false;
  JevModelCatalogResult? _catalogResult;

  void _invalidateValidation() {
    _generation++;
    _validation = null;
    _busy = false;
  }

  final TextEditingController _keyController = TextEditingController();

  late JevSettings _settings = JevSettingsStore.snapshot;
  late final ScreeningModeStore _modeStore = ScreeningModeStore(box: _store.box);
  ScreeningEngineMode _mode = ScreeningEngineMode.decision;
  String? _migrationNotice;
  JevSelectionState _selection = const JevSelectionState();
  JevPreferenceProfile _profile = JevPreferenceProfile.empty;
  JevKeyStoreStatus _keyStoreStatus = JevKeyStoreStatus.available;
  JevValidationResult? _validation;
  bool _busy = false;
  bool _obscureKey = true;
  bool _hasStoredKey = false;

  // Issue #123: verdict-cache bounds, read from the settings box in _load().
  bool _cacheEnabled = true;
  int _cacheEntries = 0;
  final TextEditingController _cacheTtlController = TextEditingController();
  final TextEditingController _cacheMaxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    _cacheTtlController.dispose();
    _cacheMaxController.dispose();
    _llmBaseUrlController.dispose();
    _llmModelController.dispose();
    _llmKeyController.dispose();
    _llmSearchController.dispose();
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
    final mode = await _modeStore.load();
    final notice = await _modeStore.readNotice();
    final profile = await _preferences.load();
    final status = await _credentials.status();
    // Issue #123: verdict-cache bounds live in the settings box; reads are
    // defensive so a broken box keeps the page usable.
    var cacheEnabled = true;
    var cacheTtl = JevVerdictCache.ttlMinutesDefault;
    var cacheMax = JevVerdictCache.maxEntriesDefault;
    try {
      cacheEnabled = JevVerdictCache.enabledIn(_store.box);
      cacheTtl = JevVerdictCache.ttlMinutesIn(_store.box);
      cacheMax = JevVerdictCache.maxEntriesIn(_store.box);
    } catch (_) {}
    String? storedKey;
    if (status == JevKeyStoreStatus.available) {
      try {
        storedKey = await _credentials.read();
      } catch (_) {
        storedKey = null;
      }
    }
    // Issue #145: provider-aware hydration is independent of the Jev
    // settings; a broken store keeps the section at its preset defaults.
    var providerId = kLlmProviderPresets.first.id;
    LlmProviderAccount? providerAccount;
    String? providerKey;
    try {
      providerId = await _provStore.activeProvider() ?? providerId;
      providerAccount = await _provStore.load(providerId);
      providerKey = await _provStore.readKey(providerId);
    } catch (_) {}
    LlmProviderPreset providerPreset =
        kLlmProviderPresets.firstWhere((p) => p.id == providerId);
    if (!mounted) return;
    if (status == JevKeyStoreStatus.unavailable && settings.enabled) {
      // Issue #32: without a usable credential store Jev stays disabled.
      await _saveSettings(settings.copyWith(enabled: false));
      if (!mounted) return;
    }
    setState(() {
      _settings = JevSettingsStore.snapshot;
      _mode = mode;
      _migrationNotice = notice;
      _profile = profile;
      _cacheEnabled = cacheEnabled;
      _cacheEntries = JevVerdictCache.cachedEntryCount;
      _cacheTtlController.text = '$cacheTtl';
      _cacheMaxController.text = '$cacheMax';
      final provider = _settings.provider;
      if (provider != null) {
        _modelController.text = _settings.modelFor(provider);
      }
      _keyStoreStatus = status;
      _hasStoredKey = storedKey != null;
      if (storedKey != null) {
        _keyController.text = storedKey;
      }
      _provId = providerId;
      _provAccount =
          providerAccount ?? LlmProviderAccount(providerId: providerId);
      _provDraftProtocol = _provAccount.protocol;
      _provDraftIncludesV1 = _provAccount.includesV1Override;
      _provInsecureConfirmed = _provAccount.httpInsecureConfirmed;
      _provKeyStored = (providerKey ?? '').isNotEmpty;
      _llmBaseUrlController.text = _provAccount.baseUrl.isEmpty
          ? providerPreset.baseUrl
          : _provAccount.baseUrl;
      _llmModelController.text = _provAccount.model;
      if (providerKey != null) {
        _llmKeyController.text = providerKey;
      }
      _selection = JevSelectionState(
        provider: _settings.provider,
        keyText: storedKey ?? '',
        mismatchAcknowledged: _settings.providerConfirmed,
      );
    });
  }

  Future<void> _saveQueue = Future<void>.value();

  Future<bool> _saveSettings(JevSettings next) async {
    if (!mounted) return false;
    final previous = _settings;
    setState(() => _settings = next);
    final write = _saveQueue.then((_) => _store.save(next));
    _saveQueue = write.catchError((Object _) {});
    try {
      await write;
      return true;
    } catch (error) {
      if (mounted && identical(_settings, next)) {
        setState(() => _settings = previous);
      }
      _toast('保存失败：$error');
      return false;
    }
  }

  Future<void> _selectProvider(JevProvider provider) async {
    setState(() {
      _selection = _selection.withProvider(provider);
      _invalidateValidation();
      _catalogGeneration++;
      _catalogBusy = false;
      _catalogResult = null;
      _modelController.text = _settings.modelFor(provider);
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
      _invalidateValidation();
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
      _invalidateValidation();
      _hasStoredKey = false;
    });
    await _saveSettings(_settings.copyWith(providerConfirmed: false));
    _toast('已清除密钥');
  }

  Future<void> _saveModel({bool restoreDefault = false}) async {
    final provider = _selection.provider;
    if (provider == null) return;
    final model = restoreDefault
        ? provider.model
        : _modelController.text.trim();
    if (model.isEmpty) {
      _toast('模型 ID 不能为空');
      return;
    }
    setState(_invalidateValidation);
    final next = restoreDefault
        ? _settings.withDefaultModel(provider)
        : _settings.withModel(provider, model);
    final generation = _generation;
    final saved = await _saveSettings(next);
    if (!saved ||
        !mounted ||
        generation != _generation ||
        _selection.provider != provider) {
      return;
    }
    _modelController.text = _settings.modelFor(provider);
    _toast('模型已保存，需重新验证');
  }

  Future<void> _loadModels() async {
    final provider = _selection.provider;
    if (provider == null) return;
    final generation = ++_catalogGeneration;
    setState(() {
      _catalogBusy = true;
      _catalogResult = null;
    });
    final result = await _catalog.load(
      provider: provider,
      apiKey: _selection.trimmedKey,
    );
    if (!mounted || generation != _catalogGeneration) return;
    setState(() {
      _catalogBusy = false;
      _catalogResult = result;
    });
  }

  Future<void> _validateKey() async {
    final provider = _selection.provider;
    final generation = _generation;
    final model = provider == null ? null : _settings.modelFor(provider);
    setState(() {
      _busy = true;
      _validation = null;
    });
    try {
      final result = await _validator.validate(
        selection: _selection,
        apiKey: _selection.trimmedKey,
        model: model,
      );
      if (!mounted || generation != _generation) return;
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
        if (!mounted || generation != _generation) return;
        _toast('验证通过：${result.provider?.label ?? ''}');
      } else {
        _toast(_validationMessage(result));
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
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
      JevProbeOutcome.modelNotFound =>
        '$provider 找不到模型 ${result.model ?? ''}，请检查模型 ID、获取上游模型或恢复默认后重新验证',
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
      resizeToAvoidBottomInset: true,
      appBar: showAppBar ? AppBar(title: const Text('LLM 语义筛选')) : null,
      body: ListView(
        padding: EdgeInsets.only(
          left: showAppBar ? padding.left : 0,
          right: showAppBar ? padding.right : 0,
          bottom: padding.bottom + 100,
        ),
        children: [
          ..._buildModeSection(),
          if (_mode == ScreeningEngineMode.decision) ...[
            ..._buildSwitchSection(),
            ..._buildCacheSection(),
            const Divider(height: 1),
          ],
          custom.ListTile(
            leading: const Icon(Icons.rule_outlined),
            title: const Text('判断规则'),
            subtitle: const Text('统一入口：按场景编辑结构化规则或视频文本规则，规则保存在本机'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => JevRulesHubPage(
                  store: JevRuleStore(box: _store.box),
                ),
              ),
            ),
          ),
          // Issue #131: the renamed page keeps the Jev-only config as its own
          // labeled group; the generic line gets a fresh section below.
          if (_mode == ScreeningEngineMode.decision) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Jev（专用模型）'),
            ),
            ..._buildProviderSection(errorColor),
            const Divider(height: 1),
            ..._buildModelSection(),
            const Divider(height: 1),
            ..._buildKeySection(errorColor),
          ],
          if (_mode == ScreeningEngineMode.llm) ...[
            ..._buildLlmSection(errorColor),
          ],
          if (_mode != ScreeningEngineMode.off) ...[
            const Divider(height: 1),
            ..._buildComplianceSection(),
          ],
          if (_mode == ScreeningEngineMode.decision) ...[
            ..._buildProfileSection(),
            const Divider(height: 1),
          ],
          custom.ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('筛选日志'),
            subtitle: const Text('查看最近被屏蔽的视频与评论，确认筛选是否生效'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const JevScreenLogPage()),
            ),
          ),
          JevFilterLogSection(log: _filterLog),
          const Divider(height: 1),
          _buildPrivacySection(),
        ],
      ),
    );
  }

  List<Widget> _buildModeSection() => [
    const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text('筛选模式'),
    ),
    for (final mode in ScreeningEngineMode.values)
      RadioListTile<ScreeningEngineMode>(
        key: ValueKey('screening-mode-${mode.id}'),
        dense: true,
        title: Text(_modeLabel(mode)),
        subtitle: Text(_modeDescription(mode)),
        value: mode,
        groupValue: _mode,
        onChanged: (value) => value == null ? null : _saveMode(value),
      ),
    custom.ListTile(
      dense: true,
      leading: Icon(_mode == ScreeningEngineMode.off
          ? Icons.pause_circle_outline
          : Icons.verified_outlined),
      title: Text(_mode == ScreeningEngineMode.off
          ? '语义筛选已关闭'
          : '当前模式：${_modeLabel(_mode)}'),
      subtitle: Text(_modeSummary()),
    ),
    if (_migrationNotice case final notice?)
      custom.ListTile(
        dense: true,
        leading: const Icon(Icons.info_outline),
        title: Text(notice),
        trailing: IconButton(
          tooltip: '关闭提示',
          icon: const Icon(Icons.close),
          onPressed: () async {
            await _modeStore.saveNotice(null);
            if (mounted) setState(() => _migrationNotice = null);
          },
        ),
      ),
  ];

  String _modeLabel(ScreeningEngineMode mode) => switch (mode) {
    ScreeningEngineMode.off => '关闭',
    ScreeningEngineMode.decision => 'Decision 判断',
    ScreeningEngineMode.llm => 'LLM 语义判断',
  };

  String _modeDescription(ScreeningEngineMode mode) => switch (mode) {
    ScreeningEngineMode.off => '不调用任一语义筛选后端，候选保持可见',
    ScreeningEngineMode.decision => '使用 Jev 结构化规则与模型验证',
    ScreeningEngineMode.llm => '使用通用模型的视频文本规则',
  };

  String _modeSummary() {
    if (_mode == ScreeningEngineMode.off) return '未启用 Decision 或 LLM 上游请求';
    if (_mode == ScreeningEngineMode.decision) {
      final provider = _settings.provider?.label ?? '未选择提供方';
      final model = _settings.provider == null
          ? '未设置模型'
          : _settings.modelFor(_settings.provider!);
      return '主配置：$provider / $model；验证状态：${_validation?.validated == true || _settings.providerConfirmed ? '已确认' : '待验证'}';
    }
    final model = _provAccount.model.trim().isEmpty ? '未设置模型' : _provAccount.model;
    return '主配置：${_provPreset.displayName} / $model；验证状态：${_provAccount.confirmed ? '已确认' : '待测试连接'}';
  }

  Future<void> _saveMode(ScreeningEngineMode mode) async {
    if (mode == _mode) return;
    await _modeStore.save(mode);
    if (!mounted) return;
    setState(() => _mode = mode);
    _toast('已切换为${_modeLabel(mode)}；另一模式配置保留');
  }

  List<Widget> _buildSwitchSection() => [
    const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text('Decision 生效入口（各自的开关）'),
    ),
    for (final surface in JevSurface.values)
      SwitchListTile(
        dense: true,
        secondary: const Icon(Icons.filter_alt_outlined),
        title: Text(surface.label),
        subtitle: surface.screeningWired ? null : const Text('尚未接线：本版本打开也不会生效'),
        value: surface.screeningWired && _settings.surfaces.contains(surface),
        onChanged: _keyStoreStatus == JevKeyStoreStatus.available &&
                surface.screeningWired
            ? (value) =>
                  _saveSettings(_settings.withSurface(surface, value: value))
            : null,
      ),
  ];

  /// Issue #123: configurable bounds for the video-surface verdict cache.
  /// Values clamp to the cache's own limits on save; 清空 wipes the in-memory
  /// cache immediately. In-flight requests are unaffected by design.
  List<Widget> _buildCacheSection() => [
    const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text('判定结果缓存（视频面）'),
    ),
    SwitchListTile(
      key: const ValueKey('jev-verdict-cache-enabled'),
      secondary: const Icon(Icons.cached_outlined),
      title: const Text('缓存判定结果'),
      subtitle: const Text('同一视频在有效期内复用上次的判定，不再重复请求上游；规则、模型或偏好档变化时整批作废'),
      value: _cacheEnabled,
      onChanged: (value) => _saveCacheConfig(enabled: value),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        key: const ValueKey('jev-verdict-cache-ttl'),
        controller: _cacheTtlController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: '缓存有效期（分钟）',
          border: OutlineInputBorder(),
          helperText: '范围 1–10080，默认 1440（24 小时）；过期后照常请求上游',
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        key: const ValueKey('jev-verdict-cache-max-entries'),
        controller: _cacheMaxController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: '缓存条目上限',
          border: OutlineInputBorder(),
          helperText: '范围 1–5000，默认 500；超出后从最旧的开始淘汰',
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        children: [
          TextButton(
            onPressed: () => _saveCacheConfig(),
            child: const Text('保存缓存设置'),
          ),
          TextButton(onPressed: _clearVerdicts, child: const Text('清空判定缓存')),
        ],
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Text('当前缓存 $_cacheEntries 条判定'),
    ),
    const custom.ListTile(
      dense: true,
      leading: Icon(Icons.info_outline),
      title: Text('缓存只保存在内存：重启应用即清空；超时、失败与低置信的判定不会入缓存'),
    ),
  ];

  Future<void> _saveCacheConfig({bool? enabled}) async {
    final nextEnabled = enabled ?? _cacheEnabled;
    if (enabled != null) {
      // Toggle path: only persist the switch; the text fields may still be
      // empty mid-edit and must not block the toggle.
      try {
        await _store.box.put(SettingBoxKey.jevVerdictCacheEnabled, nextEnabled);
      } catch (error) {
        _toast('缓存设置保存失败：$error');
        return;
      }
      if (!mounted) return;
      setState(() => _cacheEnabled = nextEnabled);
      return;
    }
    final ttlText = _cacheTtlController.text.trim();
    final maxText = _cacheMaxController.text.trim();
    final ttl = int.tryParse(ttlText);
    final maxEntries = int.tryParse(maxText);
    if (ttlText.isEmpty ||
        ttl == null ||
        maxText.isEmpty ||
        maxEntries == null) {
      _toast('缓存有效期与条目上限需要填正整数（1–10080 分钟 / 1–5000 条）');
      return;
    }
    final clampedTtl = ttl < JevVerdictCache.ttlMinutesMin
        ? JevVerdictCache.ttlMinutesMin
        : (ttl > JevVerdictCache.ttlMinutesMax
              ? JevVerdictCache.ttlMinutesMax
              : ttl);
    final clampedMax = maxEntries < JevVerdictCache.maxEntriesMin
        ? JevVerdictCache.maxEntriesMin
        : (maxEntries > JevVerdictCache.maxEntriesMax
              ? JevVerdictCache.maxEntriesMax
              : maxEntries);
    try {
      await _store.box.put(SettingBoxKey.jevVerdictCacheEnabled, nextEnabled);
      await _store.box.put(SettingBoxKey.jevVerdictCacheTtlMinutes, clampedTtl);
      await _store.box.put(SettingBoxKey.jevVerdictCacheMaxEntries, clampedMax);
    } catch (error) {
      _toast('缓存设置保存失败：$error');
      return;
    }
    if (!mounted) return;
    setState(() {
      _cacheEnabled = nextEnabled;
      _cacheEntries = JevVerdictCache.cachedEntryCount;
      _cacheTtlController.text = '$clampedTtl';
      _cacheMaxController.text = '$clampedMax';
    });
    _toast('缓存设置已保存');
  }

  void _clearVerdicts() {
    JevVerdictCache.resetCache();
    setState(() => _cacheEntries = JevVerdictCache.cachedEntryCount);
    _toast('已清空判定缓存');
  }

  List<Widget> _buildProviderSection(Color errorColor) => [
    const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text('服务提供方（必须显式选择）'),
    ),
    for (final provider in JevProvider.values)
      custom.ListTile(
        key: ValueKey('jev-provider-${provider.id}'),
        leading: Icon(
          _settings.provider == provider
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
        ),
        title: Text(provider.label),
        subtitle: Text(
          provider == JevProvider.typeSafe
              ? '直连 TypeSafe System One（model: ${_settings.modelFor(provider)}）'
              : '经 OpenRouter Jev Decisions（model: ${_settings.modelFor(provider)}）',
        ),
        onTap: () => _selectProvider(provider),
      ),
    if (_selection.isBlockedByMismatch)
      custom.ListTile(
        leading: Icon(Icons.warning_amber_outlined, color: errorColor),
        title: Text('格式提示与已选提供方不一致', style: TextStyle(color: errorColor)),
        subtitle: const Text('格式识别不决定提供方。确认后才会按已选提供方验证，绝不会把该 Key 发给另一个提供方。'),
        trailing: TextButton(
          onPressed: _acknowledgeMismatch,
          child: const Text('确认'),
        ),
      ),
  ];

  List<Widget> _buildModelSection() => [
    if (_selection.provider != null) ...[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          key: const ValueKey('jev-model'),
          controller: _modelController,
          decoration: const InputDecoration(
            labelText: '模型 ID',
            border: OutlineInputBorder(),
            helperText: '保留 ~ 和 /；选择目录项只回填，保存后才生效',
          ),
          onChanged: (_) => setState(_invalidateValidation),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          children: [
            TextButton(onPressed: _saveModel, child: const Text('保存模型')),
            TextButton(
              onPressed: () => _saveModel(restoreDefault: true),
              child: const Text('恢复默认'),
            ),
            TextButton(
              onPressed: _catalogBusy ? null : _loadModels,
              child: Text(_catalogBusy ? '获取中…' : '获取上游模型'),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          '当前生效：${_settings.modelFor(_selection.provider!)}；候选不代表验证通过',
        ),
      ),
      if (_catalogResult case final result?) ...[
        if (result.error != null || result.models.isEmpty)
          custom.ListTile(
            title: Text(result.error ?? '目录为空，可重试或手动填写；现有配置已保留'),
            trailing: TextButton(
              onPressed: _loadModels,
              child: const Text('重试'),
            ),
          ),
        for (final model in result.models)
          custom.ListTile(
            title: Text(model),
            onTap: () => setState(() {
              _modelController.text = model;
              _invalidateValidation();
            }),
          ),
      ],
    ],
  ];

  List<Widget> _buildKeySection(Color errorColor) => [
    if (_keyStoreStatus == JevKeyStoreStatus.unavailable)
      custom.ListTile(
        leading: Icon(Icons.lock_outline, color: errorColor),
        title: Text('系统安全存储不可用，Jev 保持关闭', style: TextStyle(color: errorColor)),
        subtitle: const Text('无法安全保存密钥时不会使用任何凭据，也不会退回明文存储。'),
      ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        key: const ValueKey('jev-api-key'),
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
          _catalogGeneration++;
          _catalogBusy = false;
          _selection = _selection.withKey(value);
          _invalidateValidation();
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
            key: const ValueKey('jev-save-key'),
            child: const Text('保存密钥'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed:
                _busy ||
                    !_selection.canValidate ||
                    (_selection.provider != null &&
                        _modelController.text.trim() !=
                            _settings.modelFor(_selection.provider!))
                ? null
                : _validateKey,
            child: Text(_busy ? '验证中…' : '验证'),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const ValueKey('jev-clear-key'),
            onPressed: _deleteKey,
            child: const Text('清除密钥'),
          ),
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

  // Issue #145: provider-aware section (通用模型). Presets own the wire
  // shape; the draft (base URL / route / model) is only persisted by 保存配置,
  // and the confirmed latch only flips after a probe against the saved
  // account succeeds — never on catalog success.
  LlmProviderPreset get _provPreset =>
      kLlmProviderPresets.firstWhere((p) => p.id == _provId);

  LlmResolvedProvider _provResolved(LlmProviderAccount account) =>
      LlmResolvedProvider(preset: _provPreset, account: account);

  LlmProviderAccount get _provDraftAccount => LlmProviderAccount(
        providerId: _provId,
        protocol: _provDraftProtocol,
        baseUrl: _llmBaseUrlController.text.trim(),
        model: _llmModelController.text.trim(),
        includesV1Override: _provDraftIncludesV1,
        confirmed: _provAccount.confirmed,
        httpInsecureConfirmed: _provInsecureConfirmed,
      );

  List<Widget> _buildLlmSection(Color errorColor) => [
    const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text('通用模型（提供方预设）'),
    ),
    for (final preset in kLlmProviderPresets)
      custom.ListTile(
        key: ValueKey('llm-provider-${preset.id}'),
        leading: Icon(
          _provId == preset.id
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
        ),
        title: Text(preset.displayName),
        subtitle: Text(
          preset.isCustom ? '自定义 OpenAI / Anthropic 兼容端点' : preset.baseUrl,
        ),
        onTap: () => _selectLlmProvider(preset.id),
      ),
    if (_provPreset.selectableProtocols.length > 1)
      for (final route in _provPreset.selectableProtocols)
        custom.ListTile(
          key: ValueKey('llm-route-${route.id}'),
          dense: true,
          leading: Icon(
            _provDraftProtocol == route ||
                    (_provDraftProtocol == null &&
                        route == _provPreset.primaryProtocol)
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          title: Text(route.label),
          onTap: () => setState(() {
            _provDraftProtocol =
                route == _provPreset.primaryProtocol ? null : route;
            _provGeneration++;
            _provCatalogResult = null;
            _llmProbeResult = null;
          }),
        ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        key: const ValueKey('llm-base-url'),
        controller: _llmBaseUrlController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: '服务地址 Base URL',
          border: const OutlineInputBorder(),
          helperText: '预设默认 ${_provPreset.baseUrl}；改动后随「保存配置」提交',
        ),
      ),
    ),
    if (_provPreset.isCustom)
      SwitchListTile(
        secondary: const Icon(Icons.looks_one_outlined),
        title: const Text('地址已包含 /v1 版本段'),
        subtitle: const Text('关闭时自动补 /v1；仅自定义提供方需要调整'),
        value: _provDraftIncludesV1 ?? _provPreset.baseIncludesV1,
        onChanged: (value) => setState(() {
          _provDraftIncludesV1 = value;
          _provGeneration++;
        }),
      ),
    if (_llmBaseUrlController.text.trim().toLowerCase().startsWith('http://') &&
        !_provInsecureConfirmed)
      custom.ListTile(
        leading: Icon(Icons.warning_amber_outlined, color: errorColor),
        title: Text(
          'HTTP 地址不加密，请求会明文经过网络',
          style: TextStyle(color: errorColor),
        ),
        subtitle: const Text('仅建议本机或内网地址使用；确认后才能保存该地址。'),
        trailing: TextButton(
          onPressed: () => setState(() => _provInsecureConfirmed = true),
          child: const Text('确认使用 HTTP'),
        ),
      ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        key: const ValueKey('llm-api-key'),
        controller: _llmKeyController,
        obscureText: _llmObscureKey,
        decoration: InputDecoration(
          labelText: '提供方 API Key（你自己的密钥）',
          border: const OutlineInputBorder(),
          helperMaxLines: 2,
          helperText: _provPreset.keyRequired
              ? '只保存在系统安全存储，按提供方隔离；不进 Hive、备份或日志'
              : '该提供方可匿名调用，密钥可留空',
          suffixIcon: IconButton(
            tooltip: _llmObscureKey ? '显示' : '隐藏',
            onPressed: () => setState(() => _llmObscureKey = !_llmObscureKey),
            icon: Icon(
              _llmObscureKey
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
    ),
    custom.ListTile(
      leading: Icon(
        _provKeyStored ? Icons.check_circle_outline : Icons.help_outline,
      ),
      title: Text(_provKeyStored ? '该提供方的密钥已保存' : '尚未保存该提供方的密钥'),
      subtitle: const Text('密钥按提供方隔离存放：切换提供方不会带走密钥，也不会读另一个提供方的密钥'),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        children: [
          TextButton(
            key: const ValueKey('llm-save-key'),
            onPressed: _saveProvKey,
            child: const Text('保存密钥'),
          ),
          TextButton(
            key: const ValueKey('llm-clear-key'),
            onPressed: _deleteProvKey,
            child: const Text('清除密钥'),
          ),
        ],
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        key: const ValueKey('llm-model'),
        controller: _llmModelController,
        decoration: const InputDecoration(
          labelText: '提供方模型 ID',
          border: OutlineInputBorder(),
          helperText: '手动填写或从目录选择；字符原样保留（/、~ 等），保存配置后才生效',
        ),
      ),
    ),
    if (_provCatalogResult case final result?)
      if (result.error == null && result.models.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            key: const ValueKey('llm-model-search'),
            controller: _llmSearchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '搜索模型',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        children: [
          TextButton(onPressed: _provBusy ? null : _saveProvConfig, child: const Text('保存配置')),
          TextButton(
            onPressed: _provCatalogBusy || !_provPreset.hasCatalog
                ? null
                : _loadProvModels,
            child: Text(_provCatalogBusy ? '获取中…' : '获取模型目录'),
          ),
          TextButton(
            onPressed: _provBusy ? null : _probeProv,
            child: Text(_provBusy ? '测试中…' : '测试连接'),
          ),
        ],
      ),
    ),
    if (!_provPreset.hasCatalog) ...[
      const custom.ListTile(
        dense: true,
        leading: Icon(Icons.info_outline),
        title: Text('该提供方没有可用的模型目录，请手动填写模型或改用其 OpenAI 兼容地址'),
      ),
      for (final model in _provPreset.verifiedDefaultModels)
        custom.ListTile(
          dense: true,
          leading: const Icon(Icons.verified_outlined),
          title: Text(model),
          subtitle: const Text('已验证的默认模型（点击回填，保存配置后生效）'),
          onTap: () => setState(() => _llmModelController.text = model),
        ),
    ],
    if (_provCatalogResult case final result?) ...[
      if (result.error != null || result.models.isEmpty)
        custom.ListTile(
          title: Text(result.error ?? '目录为空，可重试或手动填写；现有配置已保留'),
          trailing: TextButton(
            onPressed: _provCatalogBusy ? null : _loadProvModels,
            child: const Text('重试目录'),
          ),
        ),
      for (final model in result.models)
        if (_llmSearchController.text.trim().isEmpty ||
            model
                .toLowerCase()
                .contains(_llmSearchController.text.trim().toLowerCase()))
          custom.ListTile(
            dense: true,
            title: Text(model),
            onTap: () => setState(() {
              _llmModelController.text = model;
            }),
          ),
    ],
    if (_llmProbeResult case final probe?)
      custom.ListTile(
        dense: true,
        leading: Icon(
          probe.succeeded ? Icons.verified_outlined : Icons.error_outline,
          color: probe.succeeded ? null : errorColor,
        ),
        title: Text(_llmProbeMessage(probe)),
      ),
    if (_provMappingError case final mappingError?)
      custom.ListTile(
        dense: true,
        leading: Icon(Icons.error_outline, color: errorColor),
        title: Text(
          '筛选线切换受阻：$mappingError',
          style: TextStyle(color: errorColor),
        ),
      ),
    for (final issue in _provResolved(_provDraftAccount).issues)
      if (issue != LlmPresetIssue.missingModel)
        custom.ListTile(
          dense: true,
          leading: Icon(Icons.error_outline, color: errorColor),
          title: Text(issue.message, style: TextStyle(color: errorColor)),
        ),
    custom.ListTile(
      dense: true,
      leading: Icon(
        _provAccount.confirmed ? Icons.verified_outlined : Icons.info_outline,
      ),
      title: Text(
        _provAccount.confirmed
            ? '该提供方已通过测试并驱动筛选线'
            : '该提供方尚未生效：需「测试连接」通过后才驱动筛选线',
      ),
      subtitle: const Text('目录成功只说明能拉到模型；保存配置只落盘；测试通过才锁存确认并写穿到筛选线'),
    ),
  ];

  Future<void> _selectLlmProvider(String id) async {
    if (id == _provId) return;
    LlmProviderAccount account = LlmProviderAccount(providerId: id);
    String? storedKey;
    try {
      account = await _provStore.load(id) ?? account;
      storedKey = await _provStore.readKey(id);
    } catch (_) {}
    if (!mounted) return;
    final preset = kLlmProviderPresets.firstWhere((p) => p.id == id);
    setState(() {
      _provId = id;
      _provAccount = account;
      _provDraftProtocol = account.protocol;
      _provDraftIncludesV1 = account.includesV1Override;
      _provInsecureConfirmed = account.httpInsecureConfirmed;
      _provKeyStored = (storedKey ?? '').isNotEmpty;
      _llmBaseUrlController.text =
          account.baseUrl.isEmpty ? preset.baseUrl : account.baseUrl;
      _llmModelController.text = account.model;
      _llmKeyController.text = storedKey ?? '';
      _llmSearchController.clear();
      _provCatalogResult = null;
      _llmProbeResult = null;
      _provMappingError = null;
      _provGeneration++;
      _provCatalogBusy = false;
      _provBusy = false;
    });
    try {
      await _provStore.setActive(id);
    } catch (_) {}
  }

  /// 显式保存：唯一的落盘动作。目录成功从不触碰账号；confirmed 随上游变更
  /// 由存储层强制失效。
  Future<void> _saveProvConfig() async {
    final preset = _provPreset;
    final base = _llmBaseUrlController.text.trim();
    final account = LlmProviderAccount(
      providerId: _provId,
      protocol: _provDraftProtocol,
      baseUrl: base == preset.baseUrl ? '' : base,
      model: _llmModelController.text.trim(),
      includesV1Override: _provDraftIncludesV1,
      confirmed: _provAccount.confirmed,
      httpInsecureConfirmed: _provInsecureConfirmed,
    );
    // missingModel 允许先存地址；catalogUnavailable 只是没有目录可拉取。
    final blocking = _provResolved(account).issues
        .where((issue) =>
            issue != LlmPresetIssue.missingModel &&
            issue != LlmPresetIssue.catalogUnavailable)
        .toList();
    if (blocking.isNotEmpty) {
      // 清洗式保存：被阻塞的维度回退默认（路线清空回主路线、不安全地址
      // 清空回预设默认），其余字段照常落盘；提示原因。记录必须存在，
      // 否则用户的模型/地址草稿会静默丢失。
      var sanitized = account;
      final stripRoute = blocking.any((issue) =>
          issue == LlmPresetIssue.routeNotScreenable ||
          issue == LlmPresetIssue.unsupportedRoute);
      final stripBase = blocking.any((issue) =>
          issue == LlmPresetIssue.insecureBaseUrl ||
          issue == LlmPresetIssue.missingBaseUrl ||
          issue == LlmPresetIssue.invalidBaseUrl);
      if (stripRoute) sanitized = sanitized.copyWith(protocolSet: false);
      if (stripBase) {
        sanitized = sanitized.copyWith(baseUrl: '', httpInsecureConfirmed: false);
      }
      try {
        await _provStore.save(sanitized);
      } catch (error) {
        _toast('提供方配置保存失败：$error');
        return;
      }
      if (!mounted) return;
      setState(() {
        _provAccount = sanitized;
        _provGeneration++;
      });
      _toast(blocking.first.message);
      return;
    }
    try {
      await _provStore.save(account);
    } catch (error) {
      _toast('提供方配置保存失败：$error');
      return;
    }
    if (!mounted) return;
    setState(() {
      _provAccount = account;
      _provMappingError = null;
      _provCatalogResult = null;
      _llmProbeResult = null;
      _provGeneration++;
    });
    _toast('提供方配置已保存（测试连接通过后才驱动筛选线）');
  }

  Future<void> _saveProvKey() async {
    final key = _llmKeyController.text.trim();
    try {
      if (key.isEmpty) {
        await _provStore.deleteKey(_provId);
      } else {
        await _provStore.writeKey(_provId, key);
      }
      final account = await _provStore.load(_provId);
      if (!mounted) return;
      setState(() {
        if (account != null) _provAccount = account;
        _provKeyStored = key.isNotEmpty;
      });
      _toast(key.isEmpty ? '已清除该提供方的密钥' : '密钥已保存在系统安全存储');
    } catch (error) {
      _toast('密钥保存失败：$error');
    }
  }

  Future<void> _deleteProvKey() async {
    try {
      await _provStore.deleteKey(_provId);
      final account = await _provStore.load(_provId);
      if (!mounted) return;
      setState(() {
        if (account != null) _provAccount = account;
        _provKeyStored = false;
      });
      _llmKeyController.clear();
      _toast('已清除该提供方的密钥');
    } catch (error) {
      _toast('清除密钥失败：$error');
    }
  }

  String _provSavedKey() {
    return _provKeyStored ? _llmKeyController.text.trim() : '';
  }

  Future<void> _loadProvModels() async {
    final resolved = _provResolved(_provAccount);
    final key = _provSavedKey();
    final generation = ++_provGeneration;
    setState(() {
      _provCatalogBusy = true;
      _provCatalogResult = null;
    });
    final result =
        await _llmCatalog.loadResolved(resolved: resolved, apiKey: key);
    if (!mounted || generation != _provGeneration) return;
    setState(() {
      _provCatalogBusy = false;
      _provCatalogResult = result;
      if (result.error != null) {
        // 目录失败：目录态草稿不可信，输入框回退到已保存模型。
        _llmModelController.text = _provAccount.model;
      }
    });
  }

  Future<void> _probeProv() async {
    final resolved = _provResolved(_provAccount);
    final key = _provSavedKey();
    final generation = ++_provGeneration;
    setState(() {
      _provBusy = true;
      _llmProbeResult = null;
      _provMappingError = null;
    });
    final result = await _llmProbe.callResolved(resolved: resolved, apiKey: key);
    if (!mounted || generation != _provGeneration) return;
    if (!result.succeeded) {
      setState(() {
        _provBusy = false;
        _llmProbeResult = result;
      });
      _toast(_llmProbeMessage(result));
      return;
    }
    // 探活通过 → 把已保存账号映射进筛选线（v1）并写穿。目录/保存都不写穿；
    // 筛选线单一写入方是本页，且写入的配置与探活发出请求的配置同源。
    final mapping = llmLegacyMappingFor(resolved, confirmed: true);
    if (mapping.config == null) {
      setState(() {
        _provBusy = false;
        _llmProbeResult = result;
        _provMappingError = mapping.error;
      });
      _toast('上游可连通，但筛选线切换受阻：${mapping.error}');
      return;
    }
    final legacy = mapping.config!;
    try {
      await _llmStore.save(legacy);
      if (key.isEmpty) {
        await _llmCredentials.delete(legacy.protocol!);
      } else {
        await _llmCredentials.write(legacy.protocol!, key);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _provBusy = false;
        _llmProbeResult = result;
      });
      _toast('筛选线切换失败：$error');
      return;
    }
    try {
      await _provStore.save(_provAccount.copyWith(confirmed: true));
      final reloaded = await _provStore.load(_provId);
      if (reloaded != null) _provAccount = reloaded;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _provBusy = false;
      _llmProbeResult = result;
    });
    _toast('测试通过，筛选线已切换到该提供方');
  }

  String _llmProbeMessage(LlmProbeResult probe) {
    if (probe.succeeded) return '测试通过：上游可连通';
    final base = switch (probe.outcome) {
      LlmProbeOutcome.invalidKey => '上游拒绝该密钥（401/403），请检查通用密钥',
      LlmProbeOutcome.rateLimited => '上游限流或过载，稍后再试',
      LlmProbeOutcome.rejectedRequest => '上游拒绝了请求格式（不判定为密钥问题）',
      LlmProbeOutcome.modelNotFound => '上游找不到该模型，请检查通用模型 ID 或目录',
      LlmProbeOutcome.serverError => '上游服务端错误，稍后再试',
      LlmProbeOutcome.timeout => '请求超时，稍后再试',
      LlmProbeOutcome.networkError => '网络不可达，请检查网络后重试',
      LlmProbeOutcome.malformedResponse => '上游响应无法解析，稍后再试',
      _ => '配置不完整，未发起请求',
    };
    final detail = probe.detail;
    if (detail == null || detail.isEmpty) return base;
    return '$base（上游：$detail）';
  }

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
        child: Text('最多保留 20 个主题：满额时先淘汰最近反馈最早的一个，6 个月没有新反馈的主题自动删除。'),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextButton(onPressed: _clearProfile, child: const Text('清空偏好档')),
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
    subtitle: Text('只发送最小候选内容、启用规则与所需负反馈摘要；评论过滤发送正文与规则上下文'),
    childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 12),
    children: [
      Text(
        '发送：启用规则中的问题、答案含义与选项；视频标题及已有短简介/标签，评论正文及必要回复上下文，直播推荐卡标题/分区。启用内置规则时发送最多 20 个未过期负主题及大致次数。',
      ),
      SizedBox(height: 8),
      Text('不发送：完整浏览/观看历史、账号标识、cookie、原始点踩记录、UP 主、视频 ID、链接、长篇元数据。'),
      SizedBox(height: 8),
      Text(
        '不额外抓取：视频字幕、作者历史、直播房间消息。评论规则在视频详情评论列表、楼中楼/对话页与首页评论门控生效。规则保存在本机，编辑保存不会发起模型请求。',
      ),
      SizedBox(height: 8),
      Text('低置信、超时、限流、缺答、密钥缺失或无效、provider 报错、安全存储不可用时，候选一律保持可见。'),
    ],
  );
}
