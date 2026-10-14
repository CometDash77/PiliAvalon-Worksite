import 'dart:async';

import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/llm/llm.dart';
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

class _FakeLlmCatalog extends LlmModelCatalog {
  final response = Completer<LlmModelCatalogResult>();
  @override
  Future<LlmModelCatalogResult> load({
    required LlmProviderConfig config,
    required String apiKey,
  }) => response.future;
}

class _FakeLlmProbe extends LlmHttpProbe {
  _FakeLlmProbe(this.result);

  final LlmProbeResult result;

  @override
  Future<LlmProbeResult> call({
    required LlmProviderConfig config,
    required String apiKey,
    String? model,
  }) async => result;
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
    double height = 3200,
  }) async {
    tester.view.physicalSize = Size(1400, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
    await tester.tap(find.text('OpenRouter'));
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
      await tester.tap(find.text('OpenRouter'));
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
      await tester.tap(find.text('OpenRouter'));
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
      await tester.tap(find.text('OpenRouter'));
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
    final master = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile).first,
    );
    expect(master.value, isFalse);
    expect(master.onChanged, isNull);
  });

  testWidgets('per-surface switches need the master switch', (tester) async {
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
    // 母开关 + 判定缓存开关(issue #123) + 各生效入口；评论过滤开关区块已随
    // issue #122 移除，不再计入。
    expect(surfaces.length, JevSurface.values.length + 2);
    for (final tile in surfaces.skip(1)) {
      expect(tile.onChanged, isNull);
      expect(tile.value, isFalse);
    }

    await tester.tap(find.text('启用 LLM 语义筛选'));
    await tester.pumpAndSettle();
    final enabled = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .toList();
    final wired = enabled.skip(1).where((tile) => tile.subtitle == null);
    expect(wired.length, JevSurface.values.length - 1);
    for (final tile in wired) {
      expect(tile.onChanged, isNotNull);
    }
    // A surface with no call site says so and cannot be switched on.
    // 判定缓存开关(issue #123)自带副标题但不是生效入口，按 key 排除。
    for (final tile
        in enabled
            .skip(1)
            .where(
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
      JevSettingsStore.snapshot.isSurfaceEnabled(JevSurface.related),
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

    await tester.tap(find.text('OpenRouter'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('jev-api-key')),
      'plain-key',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '保存密钥'));
    await tester.pumpAndSettle();

    expect(credentials.stored, 'plain-key');
    expect(credentials.writeCount, 1);
    expect(find.text('密钥已保存在系统安全存储'), findsOneWidget);
    expect(box.values.toString().contains('plain-key'), isFalse);

    await tester.tap(find.widgetWithText(TextButton, '清除密钥'));
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

    await tester.tap(find.text('OpenRouter'));
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

    await tester.tap(find.text('OpenRouter'));
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
    'generic line saves protocol, address, model, key, and confirms via probe',
    (tester) async {
      final llmBox = _MemoryBox();
      final llmStore = LlmSettingsStore(box: llmBox);
      final llmCredentials = _FakeLlmCredentials();
      final messages = <String>[];

      await pumpPage(
        tester,
        store: JevSettingsStore(box: _MemoryBox()),
        credentials: _FakeCredentialStore(),
        validator: JevKeyValidator(),
        messages: messages,
        llmStore: llmStore,
        llmCredentials: llmCredentials,
        llmProbe: _FakeLlmProbe(const LlmProbeResult(LlmProbeOutcome.ok)),
        height: 6400,
      );

      await tester.tap(find.text('OpenAI Compatible'));
      await tester.pumpAndSettle();
      expect(llmBox.values[LlmSettingsStore.protocolKey], 'openai_compatible');

      await tester.enterText(
        find.byKey(const ValueKey('llm-base-url')),
        'https://api.example.com/v1',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '保存地址'));
      await tester.pumpAndSettle();
      expect((await llmStore.load()).baseUrl, 'https://api.example.com/v1');
      expect(messages.last, '通用服务地址已保存');

      await tester.enterText(
        find.byKey(const ValueKey('llm-model')),
        'llm-model-x',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '保存通用模型'));
      await tester.pumpAndSettle();
      expect((await llmStore.load()).model, 'llm-model-x');
      expect(messages.last, '通用模型已保存');

      await tester.enterText(
        find.byKey(const ValueKey('llm-api-key')),
        'sk-llm-secret',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '保存通用密钥'));
      await tester.pumpAndSettle();
      expect(llmCredentials.writeCount, 1);
      expect(
        llmCredentials.stored[LlmProtocol.openAICompatible],
        'sk-llm-secret',
      );
      expect(llmBox.values.toString().contains('sk-llm-secret'), isFalse);
      expect(find.text('通用模型密钥已按协议保存'), findsOneWidget);
      expect(messages.last, '通用模型密钥已按协议保存');

      await tester.tap(find.widgetWithText(TextButton, '测试连接'));
      await tester.pumpAndSettle();
      expect((await llmStore.load()).confirmed, isTrue);
      expect(LlmSettingsStore.snapshot.confirmed, isTrue);
      expect(find.text('通用线已生效：配置已通过测试连接确认'), findsOneWidget);
      expect(messages.last, '测试通过，通用线已生效');
    },
  );

  testWidgets(
    'generic catalog fills the draft and the selection saves after clicking save',
    (tester) async {
      final llmStore = LlmSettingsStore(box: _MemoryBox());
      final catalog = _FakeLlmCatalog();

      await pumpPage(
        tester,
        store: JevSettingsStore(box: _MemoryBox()),
        credentials: _FakeCredentialStore(),
        validator: JevKeyValidator(),
        messages: <String>[],
        llmStore: llmStore,
        llmCredentials: _FakeLlmCredentials(),
        llmCatalog: catalog,
        height: 6400,
      );

      await tester.tap(find.text('OpenAI Compatible'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '获取通用模型目录'));
      await tester.pump();
      expect(find.text('获取中…'), findsOneWidget);
      catalog.response.complete(const LlmModelCatalogResult(['llm-candidate']));
      await tester.pumpAndSettle();
      await tester.tap(find.text('llm-candidate'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('llm-model')))
            .controller!
            .text,
        'llm-candidate',
      );
      await tester.tap(find.widgetWithText(TextButton, '保存通用模型'));
      await tester.pumpAndSettle();
      expect((await llmStore.load()).model, 'llm-candidate');
    },
  );

  testWidgets(
    'an http address stays blocked until the user confirms it explicitly',
    (tester) async {
      final llmStore = LlmSettingsStore(box: _MemoryBox());
      final messages = <String>[];

      await pumpPage(
        tester,
        store: JevSettingsStore(box: _MemoryBox()),
        credentials: _FakeCredentialStore(),
        validator: JevKeyValidator(),
        messages: messages,
        llmStore: llmStore,
        llmCredentials: _FakeLlmCredentials(),
        height: 6400,
      );

      await tester.tap(find.text('OpenAI Compatible'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('llm-base-url')),
        'http://127.0.0.1:8080',
      );
      await tester.pumpAndSettle();
      expect(find.text('HTTP 地址不加密，请求会明文经过网络'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, '保存地址'));
      await tester.pumpAndSettle();
      expect(messages.last, 'HTTP 地址不安全，需在设置中显式确认后才能使用');
      expect((await llmStore.load()).baseUrl, isEmpty);

      await tester.tap(find.widgetWithText(TextButton, '确认使用 HTTP'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '保存地址'));
      await tester.pumpAndSettle();
      expect((await llmStore.load()).baseUrl, 'http://127.0.0.1:8080');
      expect((await llmStore.load()).httpInsecureConfirmed, isTrue);
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
    final tile = find.text('视频屏蔽规则');
    await tester.ensureVisible(tile);
    await tester.tap(tile);
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
  // 评论过滤标准区块已在 issue #122 中随双轨合并移除：独立开关与标准文本
  // 不复存在，评论面只消费「判断规则」页的评论规则。
}
