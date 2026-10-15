import 'dart:async';

import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/llm/llm.dart';
import 'package:PiliPlus/features/llm/llm_credential_store.dart';
import 'package:PiliPlus/features/llm/llm_provider_config_store.dart';
import 'package:PiliPlus/features/llm/llm_provider_presets.dart';
import 'package:PiliPlus/features/screening/screening_mode.dart';
import 'package:PiliPlus/pages/jev_settings/view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

class _MemoryBox implements JevSettingsBox {
  final Map<String, Object?> values = <String, Object?>{};

  @override
  Object? get(String key, {Object? defaultValue}) =>
      values.containsKey(key) ? values[key] : defaultValue;

  @override
  Future<void> put(String key, Object? value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _FakeCredentialStore implements JevCredentialStore {
  _FakeCredentialStore({this.keyStoreStatus = JevKeyStoreStatus.available});

  JevKeyStoreStatus keyStoreStatus;
  String? stored;
  int writeCount = 0;
  int deleteCount = 0;

  @override
  Future<JevKeyStoreStatus> status() async => keyStoreStatus;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String apiKey) async {
    writeCount++;
    stored = apiKey;
  }

  @override
  Future<void> delete() async {
    deleteCount++;
    stored = null;
  }
}

class _FakeCatalog extends JevModelCatalog {
  final response = Completer<JevModelCatalogResult>();
  @override
  Future<JevModelCatalogResult> load({
    required JevProvider provider,
    required String apiKey,
  }) => response.future;
}

class _FakeLlmCredentials implements LlmCredentialStore {
  JevKeyStoreStatus keyStoreStatus = JevKeyStoreStatus.available;
  final Map<LlmProtocol, String> stored = <LlmProtocol, String>{};
  int writeCount = 0;
  int deleteCount = 0;

  @override
  Future<JevKeyStoreStatus> status(LlmProtocol protocol) async =>
      keyStoreStatus;

  @override
  Future<String?> read(LlmProtocol protocol) async => stored[protocol];

  @override
  Future<void> write(LlmProtocol protocol, String apiKey) async {
    writeCount++;
    stored[protocol] = apiKey;
  }

  @override
  Future<void> delete(LlmProtocol protocol) async {
    deleteCount++;
    stored.remove(protocol);
  }
}

class _FakeLlmProviderCredentials implements LlmProviderCredentialStore {
  final keys = <String, String>{};
  final deleted = <String>[];

  @override
  Future<JevKeyStoreStatus> status(String providerId) async =>
      JevKeyStoreStatus.available;

  @override
  Future<String?> read(String providerId) async => keys[providerId];

  @override
  Future<void> write(String providerId, String apiKey) async {
    keys[providerId] = apiKey;
  }

  @override
  Future<void> delete(String providerId) async {
    keys.remove(providerId);
    deleted.add(providerId);
  }
}

class _FakeLlmResolvedCatalog extends LlmModelCatalog {
  final calls = <LlmResolvedProvider>[];
  final _completers = <Completer<LlmModelCatalogResult>>[];

  Completer<LlmModelCatalogResult> next() {
    final completer = Completer<LlmModelCatalogResult>();
    _completers.add(completer);
    return completer;
  }

  @override
  Future<LlmModelCatalogResult> loadResolved({
    required LlmResolvedProvider resolved,
    required String apiKey,
  }) {
    calls.add(resolved);
    return _completers.removeAt(0).future;
  }
}

class _FakeLlmResolvedProbe extends LlmHttpProbe {
  _FakeLlmResolvedProbe(this.result);

  final LlmProbeResult result;
  final calls = <LlmResolvedProvider>[];

  @override
  Future<LlmProbeResult> callResolved({
    required LlmResolvedProvider resolved,
    required String apiKey,
  }) {
    calls.add(resolved);
    return Future.value(result);
  }
}

void main() {
  setUp(() {
    JevSettingsStore.resetCache();
    JevPreferenceStore.resetCache();
    LlmSettingsStore.resetCache();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required JevSettingsStore store,
    required JevCredentialStore credentials,
    required JevKeyValidator validator,
    required List<String> messages,
    JevModelCatalog? catalog,
    LlmSettingsStore? llmStore,
    LlmCredentialStore? llmCredentials,
    LlmModelCatalog? llmCatalog,
    LlmHttpProbe? llmProbe,
    LlmProviderConfigStore? llmProviderStore,
    double height = 3200,
    double width = 1400,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final mode = llmProviderStore != null ||
            llmStore != null ||
            llmCatalog != null ||
            llmProbe != null
        ? ScreeningEngineMode.llm
        : ScreeningEngineMode.decision;
    await store.box.put(ScreeningModeStore.modeKey, mode.id);
    await tester.pumpWidget(
      MaterialApp(
        home: JevSettingsPage(
          store: store,
          credentialStore: credentials,
          validator: validator,
          catalog: catalog,
          onMessage: messages.add,
          llmStore: llmStore,
          llmCredentials: llmCredentials,
          llmCatalog: llmCatalog,
          llmProbe: llmProbe,
          llmProviderStore: llmProviderStore,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('old validation cannot confirm a changed provider or model', (
    tester,
  ) async {
    final completion = Completer<JevProbeResult>();
    final store = JevSettingsStore(box: _MemoryBox());
    final messages = <String>[];
    await pumpPage(
      tester,
      store: store,
      credentials: _FakeCredentialStore(),
      messages: messages,
      validator: JevKeyValidator(
        probe: ({
          required JevProvider provider,
          required String apiKey,
          String? model,
        }) => completion.future,
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('jev-provider-openrouter')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('jev-api-key')),
      'sk-or-v1-synthetic',
    );
    await tester.tap(find.text('验证'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('jev-model')),
      '~vendor/new',
    );
    await tester.tap(find.text('保存模型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TypeSafe'));
    await tester.pumpAndSettle();
    completion.complete(const JevProbeResult(JevProbeOutcome.ok));
    await tester.pumpAndSettle();
    expect((await store.load()).provider, JevProvider.typeSafe);
    expect((await store.load()).providerConfirmed, isFalse);
    expect(messages.where((m) => m.startsWith('验证通过')), isEmpty);
  });
  testWidgets(
    'catalog fills draft only and failure retains saved model and input',
    (tester) async {
      final store = JevSettingsStore(box: _MemoryBox());
      final catalog = _FakeCatalog();
      await pumpPage(
        tester,
        store: store,
        credentials: _FakeCredentialStore(),
        messages: [],
        validator: JevKeyValidator(),
        catalog: catalog,
      );
      await tester.tap(
      find.byKey(const ValueKey('jev-provider-openrouter')),
    );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('jev-model')),
        '~vendor/manual',
      );
      await tester.tap(find.text('获取上游模型'));
      await tester.pump();
      expect(find.text('获取中…'), findsOneWidget);
      catalog.response.complete(
        const JevModelCatalogResult(['~vendor/candidate']),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('jev-model')))
            .controller!
            .text,
        '~vendor/manual',
      );
      await tester.tap(find.text('~vendor/candidate'));
      await tester.pumpAndSettle();
      expect(
        (await store.load()).modelFor(JevProvider.openRouter),
        '~typesafe/jev-latest',
      );
      await tester.tap(find.text('保存模型'));
      await tester.pumpAndSettle();
      expect(
        (await store.load()).modelFor(JevProvider.openRouter),
        '~vendor/candidate',
      );
      await tester.tap(find.text('恢复默认'));
      await tester.pumpAndSettle();
      expect(
        (await store.load()).modelFor(JevProvider.openRouter),
        '~typesafe/jev-latest',
      );
    },
  );

  testWidgets(
    'failed catalog and retry keep manual draft and persisted configuration',
    (tester) async {
      final store = JevSettingsStore(box: _MemoryBox());
      final catalog = _FakeCatalog();
      await pumpPage(
        tester,
        store: store,
        credentials: _FakeCredentialStore(),
        messages: [],
        validator: JevKeyValidator(),
        catalog: catalog,
      );
      await tester.tap(
      find.byKey(const ValueKey('jev-provider-openrouter')),
    );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('jev-model')),
        '~vendor/manual',
      );
      await tester.tap(find.text('获取上游模型'));
      await tester.pump();
      catalog.response.complete(
        const JevModelCatalogResult([], error: '目录失败，可重试'),
      );
      await tester.pumpAndSettle();
      expect(find.text('重试'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('jev-model')))
            .controller!
            .text,
        '~vendor/manual',
      );
      expect(
        (await store.load()).modelFor(JevProvider.openRouter),
        '~typesafe/jev-latest',
      );
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('jev-model')))
            .controller!
            .text,
        '~vendor/manual',
      );
    },
  );

  testWidgets(
    'model controls are available after explicit provider selection',
    (tester) async {
      await pumpPage(
        tester,
        store: JevSettingsStore(box: _MemoryBox()),
        credentials: _FakeCredentialStore(),
        validator: JevKeyValidator(),
        messages: [],
      );
      await tester.tap(
      find.byKey(const ValueKey('jev-provider-openrouter')),
    );
      await tester.pumpAndSettle();
      expect(find.text('模型 ID'), findsOneWidget);
      expect(find.text('保存模型'), findsOneWidget);
      expect(find.text('获取上游模型'), findsOneWidget);
      expect(find.text('恢复默认'), findsOneWidget);
    },
  );

  testWidgets('an unusable secure store keeps Jev off', (tester) async {
    final box = _MemoryBox();
    box.values[JevSettingsStore.enabledKey] = true;
    final credentials = _FakeCredentialStore(
      keyStoreStatus: JevKeyStoreStatus.unavailable,
    );
    final probes = <JevProvider>[];

    await pumpPage(
      tester,
      store: JevSettingsStore(box: box),
      credentials: credentials,
      validator: JevKeyValidator(
        probe:
            ({
              required JevProvider provider,
              required String apiKey,
              String? model,
            }) async {
              probes.add(provider);
              return const JevProbeResult(JevProbeOutcome.ok);
            },
      ),
      messages: <String>[],
    );

    expect(find.text('系统安全存储不可用，Jev 保持关闭'), findsOneWidget);
    expect(box.values[JevSettingsStore.enabledKey], isFalse);
    expect(credentials.writeCount, 0);
    expect(probes, isEmpty);
    expect(
      tester.widget<RadioListTile<ScreeningEngineMode>>(
        find.byKey(const ValueKey('screening-mode-decision')),
      ).groupValue,
      ScreeningEngineMode.decision,
    );
  });

  testWidgets('Decision surfaces can be configured independently', (tester) async {
    final box = _MemoryBox();
    await pumpPage(
      tester,
      store: JevSettingsStore(box: box),
      credentials: _FakeCredentialStore(),
      validator: JevKeyValidator(
        probe: ({
          required JevProvider provider,
          required String apiKey,
          String? model,
        }) async => const JevProbeResult(JevProbeOutcome.ok),
      ),
      messages: <String>[],
    );

    final surfaces = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .toList();
    // Cache plus each wired surface. No second engine-wide master switch.
    expect(surfaces.length, JevSurface.values.length + 1);
    final wired = surfaces.where((tile) => tile.subtitle == null);
    expect(wired.length, JevSurface.values.length - 1);
    for (final tile in wired) {
      expect(tile.onChanged, isNotNull);
    }
    // A surface with no call site says so and cannot be switched on.
    // 判定缓存开关(issue #123)自带副标题但不是生效入口，按 key 排除。
    for (final tile
        in surfaces.where(
          (tile) =>
              tile.subtitle != null &&
              tile.key != const ValueKey('jev-verdict-cache-enabled'),
        )) {
      expect(tile.onChanged, isNull);
      expect(tile.value, isFalse);
    }

    await tester.tap(find.text(JevSurface.related.label));
    await tester.pumpAndSettle();
    expect(box.values[JevSettingsStore.surfaceKey(JevSurface.related)], isTrue);
    expect(
      JevSettingsStore.snapshot.surfaces.contains(JevSurface.related),
      isTrue,
    );

    await tester.tap(find.text(JevSurface.live.label), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(box.values[JevSettingsStore.surfaceKey(JevSurface.live)], isFalse);
    expect(
      JevSettingsStore.snapshot.isSurfaceEnabled(JevSurface.live),
      isFalse,
    );
  });

  testWidgets('a hinted key never validates against the wrong provider', (
    tester,
  ) async {
    final box = _MemoryBox();
    final credentials = _FakeCredentialStore();
    final probes = <JevProvider>[];

    await pumpPage(
      tester,
      store: JevSettingsStore(box: box),
      credentials: credentials,
      validator: JevKeyValidator(
        probe:
            ({
              required JevProvider provider,
              required String apiKey,
              String? model,
            }) async {
              probes.add(provider);
              return const JevProbeResult(JevProbeOutcome.ok);
            },
      ),
      messages: <String>[],
    );

    await tester.tap(find.text('TypeSafe'));
    await tester.pumpAndSettle();
    expect(box.values[JevSettingsStore.providerKey], 'typesafe');

    await tester.enterText(
      find.byKey(const ValueKey('jev-api-key')),
      'sk-or-v1-abc',
    );
    await tester.pumpAndSettle();
    expect(find.text('格式提示与已选提供方不一致'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '验证'));
    await tester.pumpAndSettle();
    expect(probes, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, '确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '验证'));
    await tester.pumpAndSettle();

    expect(probes, <JevProvider>[JevProvider.typeSafe]);
    expect(box.values[JevSettingsStore.providerConfirmedKey], isTrue);
  });

  testWidgets('saving a key writes it to the credential store only', (
    tester,
  ) async {
    final box = _MemoryBox();
    final credentials = _FakeCredentialStore();
    final messages = <String>[];

    await pumpPage(
      tester,
      store: JevSettingsStore(box: box),
      credentials: credentials,
      validator: JevKeyValidator(
        probe: ({
          required JevProvider provider,
          required String apiKey,
          String? model,
        }) async => const JevProbeResult(JevProbeOutcome.ok),
      ),
      messages: messages,
    );

    await tester.tap(
      find.byKey(const ValueKey('jev-provider-openrouter')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('jev-api-key')),
      'plain-key',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('jev-save-key')));
    await tester.pumpAndSettle();

    expect(credentials.stored, 'plain-key');
    expect(credentials.writeCount, 1);
    expect(find.text('密钥已保存在系统安全存储'), findsOneWidget);
    expect(box.values.toString().contains('plain-key'), isFalse);

    await tester.tap(find.byKey(const ValueKey('jev-clear-key')));
    await tester.pumpAndSettle();
    expect(credentials.deleteCount, 1);
    expect(credentials.stored, isNull);
    expect(find.text('尚未保存密钥'), findsOneWidget);
  });

  testWidgets('the local profile lists its themes and deletes one', (
    tester,
  ) async {
    final box = _MemoryBox();
    box.values[JevPreferenceStore.profileKey] = JevPreferenceProfile.empty
        .recordTheme(
          '甲主题',
          now: DateTime.now().subtract(const Duration(days: 3)),
        )
        .recordTheme(
          '乙主题',
          now: DateTime.now().subtract(const Duration(days: 1)),
        )
        .encode();

    await pumpPage(
      tester,
      store: JevSettingsStore(box: box),
      credentials: _FakeCredentialStore(),
      validator: JevKeyValidator(
        probe: ({
          required JevProvider provider,
          required String apiKey,
          String? model,
        }) async => const JevProbeResult(JevProbeOutcome.ok),
      ),
      messages: <String>[],
    );

    expect(find.text('Jev 已关闭：暂停收集，档与过期计时保留'), findsOneWidget);
    expect(find.text('甲主题'), findsOneWidget);
    expect(find.text('乙主题'), findsOneWidget);

    // Newest feedback first, so the first delete icon belongs to 乙主题.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('乙主题'), findsNothing);
    expect(find.text('甲主题'), findsOneWidget);
    expect(box.values.containsKey(JevPreferenceStore.profileKey), isTrue);
  });

  testWidgets('clearing the local profile removes the stored themes', (
    tester,
  ) async {
    final box = _MemoryBox();
    box.values[JevPreferenceStore.profileKey] = JevPreferenceProfile.empty
        .recordTheme(
          '甲主题',
          now: DateTime.now().subtract(const Duration(days: 3)),
        )
        .encode();

    await pumpPage(
      tester,
      store: JevSettingsStore(box: box),
      credentials: _FakeCredentialStore(),
      validator: JevKeyValidator(
        probe: ({
          required JevProvider provider,
          required String apiKey,
          String? model,
        }) async => const JevProbeResult(JevProbeOutcome.ok),
      ),
      messages: <String>[],
    );

    await tester.tap(find.widgetWithText(TextButton, '清空偏好档'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '清空'));
    await tester.pumpAndSettle();

    expect(find.text('档为空'), findsOneWidget);
    expect(box.values.containsKey(JevPreferenceStore.profileKey), isFalse);
  });

  testWidgets('a rejected request shows the upstream status and message', (
    tester,
  ) async {
    final box = _MemoryBox();
    final messages = <String>[];

    await pumpPage(
      tester,
      store: JevSettingsStore(box: box),
      credentials: _FakeCredentialStore(),
      validator: JevKeyValidator(
        probe:
            ({
              required JevProvider provider,
              required String apiKey,
              String? model,
            }) async => const JevProbeResult(
              JevProbeOutcome.rejectedRequest,
              detail: 'HTTP 400：No endpoint found.',
            ),
      ),
      messages: messages,
    );

    await tester.tap(
      find.byKey(const ValueKey('jev-provider-openrouter')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('jev-api-key')),
      'sk-or-v1-abc',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '验证'));
    await tester.pumpAndSettle();

    expect(find.textContaining('拒绝了请求格式'), findsOneWidget);
    expect(
      find.textContaining('（上游：HTTP 400：No endpoint found.）'),
      findsOneWidget,
    );
    expect(messages.last, contains('上游：HTTP 400：No endpoint found.'));
  });

  testWidgets('a rejected request without detail keeps the stable copy', (
    tester,
  ) async {
    final box = _MemoryBox();

    await pumpPage(
      tester,
      store: JevSettingsStore(box: box),
      credentials: _FakeCredentialStore(),
      validator: JevKeyValidator(
        probe: ({
          required JevProvider provider,
          required String apiKey,
          String? model,
        }) async => const JevProbeResult(JevProbeOutcome.rejectedRequest),
      ),
      messages: <String>[],
    );

    await tester.tap(
      find.byKey(const ValueKey('jev-provider-openrouter')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('jev-api-key')),
      'sk-or-v1-abc',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '验证'));
    await tester.pumpAndSettle();

    expect(find.textContaining('拒绝了请求格式'), findsOneWidget);
    expect(find.textContaining('上游：'), findsNothing);
  });

  testWidgets(
    'provider flow saves config, key, and switches screening via probe',
    (tester) async {
      final v1Store = LlmSettingsStore(box: _MemoryBox());
      final v1Credentials = _FakeLlmCredentials();
      final provStore = LlmProviderConfigStore(
        box: _MemoryBox(),
        credentials: _FakeLlmProviderCredentials(),
      );
      final probe =
          _FakeLlmResolvedProbe(const LlmProbeResult(LlmProbeOutcome.ok));
      final messages = <String>[];

      await pumpPage(
        tester,
        store: JevSettingsStore(box: _MemoryBox()),
        credentials: _FakeCredentialStore(),
        validator: JevKeyValidator(),
        messages: messages,
        llmStore: v1Store,
        llmCredentials: v1Credentials,
        llmProbe: probe,
        llmProviderStore: provStore,
        height: 9600,
      );

      await tester.tap(find.byKey(const ValueKey('llm-provider-openrouter')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('llm-api-key')),
        'sk-or-k',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('llm-save-key')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('llm-model')),
        'm/or',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '保存配置'));
      await tester.pumpAndSettle();
      expect((await provStore.load('openrouter'))!.model, 'm/or');

      await tester.tap(find.widgetWithText(TextButton, '测试连接'));
      await tester.pumpAndSettle();
      expect(
        probe.calls.single.chatEndpoint,
        'https://openrouter.ai/api/v1/chat/completions',
      );
      final legacy = await v1Store.load();
      expect(legacy.protocol, LlmProtocol.openAICompatible);
      expect(legacy.baseUrl, 'https://openrouter.ai/api/v1');
      expect(legacy.model, 'm/or');
      expect(legacy.confirmed, isTrue);
      expect(v1Credentials.stored[LlmProtocol.openAICompatible], 'sk-or-k');
      expect((await provStore.load('openrouter'))!.confirmed, isTrue);
      expect(messages.last, '测试通过，筛选线已切换到该提供方');
    },
  );

  testWidgets(
    'catalog states keep the saved model on failure and fill drafts on tap',
    (tester) async {
      final provStore = LlmProviderConfigStore(
        box: _MemoryBox(),
        credentials: _FakeLlmProviderCredentials(),
      );
      final catalog = _FakeLlmResolvedCatalog();

      await pumpPage(
        tester,
        store: JevSettingsStore(box: _MemoryBox()),
        credentials: _FakeCredentialStore(),
        validator: JevKeyValidator(),
        messages: <String>[],
        llmCatalog: catalog,
        llmProviderStore: provStore,
        height: 9600,
      );

      // 保存一个带特殊字符的模型；目录的任何状态都不得清掉它。
      await tester.enterText(
        find.byKey(const ValueKey('llm-model')),
        '~/x/y',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '保存配置'));
      await tester.pumpAndSettle();

      // 成功态：列出目录并按搜索词过滤。
      final ok = catalog.next();
      await tester.tap(find.widgetWithText(TextButton, '获取模型目录'));
      await tester.pump();
      expect(find.text('获取中…'), findsOneWidget);
      ok.complete(
        const LlmModelCatalogResult(['m/deepseek-chat', 'm/reasoner']),
      );
      await tester.pumpAndSettle();
      expect(find.text('m/deepseek-chat'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('llm-model-search')),
        'reasoner',
      );
      await tester.pumpAndSettle();
      expect(find.text('m/deepseek-chat'), findsNothing);
      // 点选只回填草稿，不落盘。
      await tester.tap(find.text('m/reasoner'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('llm-model')))
            .controller!
            .text,
        'm/reasoner',
      );
      expect((await provStore.load('deepseek'))!.model, '~/x/y');

      // 失败态：错误提示 + 已存模型原样。
      catalog.next().complete(
        const LlmModelCatalogResult(
          [],
          error: '目录请求失败（HTTP 500），可重试或手动填写',
        ),
      );
      await tester.tap(find.widgetWithText(TextButton, '获取模型目录'));
      await tester.pumpAndSettle();
      expect(find.textContaining('目录请求失败（HTTP 500）'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('llm-model')))
            .controller!
            .text,
        '~/x/y',
      );
      expect((await provStore.load('deepseek'))!.model, '~/x/y');

      // 空目录态。
      catalog.next().complete(const LlmModelCatalogResult([]));
      await tester.tap(find.widgetWithText(TextButton, '重试目录'));
      await tester.pumpAndSettle();
      expect(find.text('目录为空，可重试或手动填写；现有配置已保留'),
          findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('llm-model')))
            .controller!
            .text,
        '~/x/y',
      );
    },
  );

  testWidgets(
    'stale catalog responses from a previous provider never land',
    (tester) async {
      final provStore = LlmProviderConfigStore(
        box: _MemoryBox(),
        credentials: _FakeLlmProviderCredentials(),
      );
      final catalog = _FakeLlmResolvedCatalog();
      final stale = catalog.next();

      await pumpPage(
        tester,
        store: JevSettingsStore(box: _MemoryBox()),
        credentials: _FakeCredentialStore(),
        validator: JevKeyValidator(),
        messages: <String>[],
        llmCatalog: catalog,
        llmProviderStore: provStore,
        height: 9600,
      );

      await tester.tap(find.widgetWithText(TextButton, '获取模型目录'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('llm-provider-openrouter')));
      await tester.pumpAndSettle();
      stale.complete(const LlmModelCatalogResult(['stale-model']));
      await tester.pumpAndSettle();
      expect(find.text('stale-model'), findsNothing);

      final fresh = catalog.next();
      await tester.tap(find.widgetWithText(TextButton, '获取模型目录'));
      await tester.pump();
      fresh.complete(const LlmModelCatalogResult(['or-model']));
      await tester.pumpAndSettle();
      expect(find.text('or-model'), findsOneWidget);
      expect(catalog.calls.map((r) => r.preset.id).toList(),
          ['deepseek', 'openrouter']);
    },
  );

  testWidgets(
    'shape none providers never fetch and list verified defaults',
    (tester) async {
      final catalog = _FakeLlmResolvedCatalog();

      await pumpPage(
        tester,
        store: JevSettingsStore(box: _MemoryBox()),
        credentials: _FakeCredentialStore(),
        validator: JevKeyValidator(),
        messages: <String>[],
        llmCatalog: catalog,
        llmProviderStore: LlmProviderConfigStore(
          box: _MemoryBox(),
          credentials: _FakeLlmProviderCredentials(),
        ),
        height: 9600,
      );

      await tester.tap(find.byKey(const ValueKey('llm-provider-xiaomimimo')));
      await tester.pumpAndSettle();
      expect(find.text(LlmPresetIssue.catalogUnavailable.message),
          findsOneWidget);
      expect(find.text('mimo-v2.6-pro'), findsOneWidget);
      expect(find.text('mimo-v2.6-flash'), findsOneWidget);
      expect(catalog.calls, isEmpty);
    },
  );

  testWidgets(
    'an http address stays blocked until the user confirms it explicitly',
    (tester) async {
      final provStore = LlmProviderConfigStore(
        box: _MemoryBox(),
        credentials: _FakeLlmProviderCredentials(),
      );

      await pumpPage(
        tester,
        store: JevSettingsStore(box: _MemoryBox()),
        credentials: _FakeCredentialStore(),
        validator: JevKeyValidator(),
        messages: <String>[],
        llmProviderStore: provStore,
        height: 9600,
      );

      await tester.tap(
        find.byKey(const ValueKey('llm-provider-custom-openai')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('llm-base-url')),
        'http://127.0.0.1:8080',
      );
      await tester.pumpAndSettle();
      expect(find.text('HTTP 地址不加密，请求会明文经过网络'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, '保存配置'));
      await tester.pumpAndSettle();
      expect((await provStore.load('custom-openai'))!.baseUrl, isEmpty);

      await tester.tap(find.widgetWithText(TextButton, '确认使用 HTTP'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '保存配置'));
      await tester.pumpAndSettle();
      final saved = (await provStore.load('custom-openai'))!;
      expect(saved.baseUrl, 'http://127.0.0.1:8080');
      expect(saved.httpInsecureConfirmed, isTrue);
    },
  );

  testWidgets(
    'a non-screenable route is flagged and blocks the save',
    (tester) async {
      final v1Store = LlmSettingsStore(box: _MemoryBox());
      final provStore = LlmProviderConfigStore(
        box: _MemoryBox(),
        credentials: _FakeLlmProviderCredentials(),
      );
      final probe = _FakeLlmResolvedProbe(
        const LlmProbeResult(
          null,
          detail: '该请求路线暂不支持语义筛选，请改用 OpenAI Chat Completions 或 Anthropic Messages',
        ),
      );
      final messages = <String>[];

      await pumpPage(
        tester,
        store: JevSettingsStore(box: _MemoryBox()),
        credentials: _FakeCredentialStore(),
        validator: JevKeyValidator(),
        messages: messages,
        llmStore: v1Store,
        llmProbe: probe,
        llmProviderStore: provStore,
        height: 9600,
      );

      await tester.tap(find.byKey(const ValueKey('llm-provider-openrouter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('llm-route-openai_responses')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('llm-model')),
        'm/or',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('暂不支持语义筛选'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '保存配置'));
      await tester.pumpAndSettle();
      expect(messages, isNotEmpty);
      expect((await provStore.load('openrouter'))!.protocol, isNull);
    },
  );

  testWidgets('settings exposes generic video rule editing (issue #136)', (
    tester,
  ) async {
    final box = _MemoryBox();
    final store = JevSettingsStore(box: box);
    await pumpPage(
      tester,
      store: store,
      credentials: _FakeCredentialStore(),
      validator: JevKeyValidator(),
      messages: [],
    );
    final hub = find.text('判断规则').first;
    await tester.ensureVisible(hub);
    await tester.tap(hub);
    await tester.pumpAndSettle();
    await tester.tap(find.text('视频文本规则'));
    await tester.pumpAndSettle();
    // 进入通用线视频规则页并完成一次创建。
    expect(find.text('添加规则'), findsOneWidget);
    await tester.tap(find.text('添加规则'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rule-text')),
      '屏蔽标题含有剧透的视频',
    );
    await tester.tap(find.text('保存规则'));
    await tester.pumpAndSettle();
    final saved = await JevRuleStore(box: store.box).load();
    expect(saved.videoTextRules.single.text, '屏蔽标题含有剧透的视频');
  });
  testWidgets('narrow settings layout remains scrollable without overflow', (
    tester,
  ) async {
    await pumpPage(
      tester,
      store: JevSettingsStore(box: _MemoryBox()),
      credentials: _FakeCredentialStore(),
      validator: JevKeyValidator(),
      messages: <String>[],
      width: 360,
      height: 800,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('筛选模式'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('隐私说明'),
      400,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 100,
      continuous: true,
    );
    expect(find.text('隐私说明'), findsOneWidget);
  });

  testWidgets('mode selection keeps only the active engine configuration visible', (
    tester,
  ) async {
    final box = _MemoryBox();
    final store = JevSettingsStore(box: box);
    await pumpPage(
      tester,
      store: store,
      credentials: _FakeCredentialStore(),
      validator: JevKeyValidator(),
      messages: <String>[],
    );

    expect(find.text('Jev（专用模型）'), findsOneWidget);
    expect(find.text('通用模型（提供方预设）'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('screening-mode-llm')));
    await tester.pumpAndSettle();
    expect(find.text('Jev（专用模型）'), findsNothing);
    expect(find.text('通用模型（提供方预设）'), findsOneWidget);
    expect(box.values[ScreeningModeStore.modeKey], 'llm');

    await tester.tap(find.byKey(const ValueKey('screening-mode-off')));
    await tester.pumpAndSettle();
    expect(find.text('Jev（专用模型）'), findsNothing);
    expect(find.text('通用模型（提供方预设）'), findsNothing);
    expect(find.text('语义筛选已关闭'), findsOneWidget);
    expect(box.values[ScreeningModeStore.modeKey], 'off');
  });

  // 评论过滤标准区块已在 issue #122 中随双轨合并移除：独立开关与标准文本
  // 不复存在，评论面只消费「判断规则」页的评论规则。
}
