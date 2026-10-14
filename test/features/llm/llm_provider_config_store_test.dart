import 'dart:convert';

import 'package:PiliPlus/features/jev/jev_credential_store.dart'
    show JevCredentialException, JevKeyStoreStatus;
import 'package:PiliPlus/features/jev/jev_contract.dart' show JevSettingsBox;
import 'package:PiliPlus/features/llm/llm_credential_store.dart';
import 'package:PiliPlus/features/llm/llm_provider_config_store.dart';
import 'package:PiliPlus/features/llm/llm_provider_presets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBox implements JevSettingsBox {
  final map = <String, Object?>{};

  @override
  Object? get(String key, {Object? defaultValue}) => map[key] ?? defaultValue;

  @override
  Future<void> put(String key, Object? value) async {
    map[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    map.remove(key);
  }
}

class _FakeCredentials implements LlmProviderCredentialStore {
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

const _keyA = 'sk-secret-a-111';
const _keyB = 'sk-secret-b-222';

LlmProviderConfigStore _store(_FakeBox box, _FakeCredentials credentials) =>
    LlmProviderConfigStore(box: box, credentials: credentials);

void main() {
  group('per-provider slots', () {
    test('save/load round-trips one account', () async {
      final box = _FakeBox();
      final credentials = _FakeCredentials();
      final store = _store(box, credentials);
      const account = LlmProviderAccount(
        providerId: 'deepseek',
        model: 'deepseek-chat',
        confirmed: true,
      );
      await store.save(account);
      expect(await store.load('deepseek'), account);
      expect(await store.loadAll(), {'deepseek': account});
    });

    test('two providers keep independent configs', () async {
      final box = _FakeBox();
      final store = _store(box, _FakeCredentials());
      const deepseek = LlmProviderAccount(
        providerId: 'deepseek',
        model: 'deepseek-chat',
      );
      const siliconflow = LlmProviderAccount(
        providerId: 'siliconflow',
        model: 'Qwen/Qwen2.5-72B-Instruct',
      );
      await store.save(deepseek);
      await store.save(siliconflow);
      expect(await store.load('deepseek'), deepseek);
      expect(await store.load('siliconflow'), siliconflow);
      expect((await store.loadAll()).keys.toSet(),
          {'deepseek', 'siliconflow'});
    });
  });

  group('config-change invalidation (acceptance 3)', () {
    test('model change invalidates confirmation and bumps generation', () async {
      final box = _FakeBox();
      final store = _store(box, _FakeCredentials());
      const base = LlmProviderAccount(
        providerId: 'deepseek',
        model: 'deepseek-chat',
        confirmed: true,
      );
      await store.save(base);
      final generationBefore = store.generation;

      await store.save(base.copyWith(model: 'deepseek-reasoner', confirmed: true));

      final saved = await store.load('deepseek');
      expect(saved!.confirmed, isFalse,
          reason: '模型变更必须使旧验证状态失效');
      expect(store.generation, generationBefore + 1);
    });

    test('baseUrl / protocol / includesV1 / auth changes each invalidate', () async {
      for (final changed in <LlmProviderAccount Function(LlmProviderAccount)>[
        (a) => a.copyWith(baseUrl: 'https://mirror.example.com'),
        (a) => a.copyWith(
            protocol: LlmRouteProtocol.anthropicMessages,
            baseUrl: 'https://api.deepseek.com'),
        (a) => a.copyWith(includesV1Override: false),
        (a) => a.copyWith(authOverride: LlmPresetAuth.anthropicNative),
      ]) {
        final box = _FakeBox();
        final store = _store(box, _FakeCredentials());
        const base = LlmProviderAccount(
          providerId: 'deepseek',
          model: 'deepseek-chat',
          confirmed: true,
        );
        await store.save(base);
        final generationBefore = store.generation;

        await store.save(changed(base.copyWith(confirmed: true)));

        expect((await store.load('deepseek'))!.confirmed, isFalse,
            reason: changed.toString());
        expect(store.generation, generationBefore + 1,
            reason: changed.toString());
      }
    });

    test('identical save keeps confirmation and generation', () async {
      final box = _FakeBox();
      final store = _store(box, _FakeCredentials());
      const base = LlmProviderAccount(
        providerId: 'deepseek',
        model: 'deepseek-chat',
        confirmed: true,
      );
      await store.save(base);
      final generationBefore = store.generation;

      await store.save(base);

      expect((await store.load('deepseek'))!.confirmed, isTrue);
      expect(store.generation, generationBefore);
    });

    test('first save keeps the caller-provided confirmation', () async {
      final box = _FakeBox();
      final store = _store(box, _FakeCredentials());
      await store.save(const LlmProviderAccount(
        providerId: 'deepseek',
        model: 'deepseek-chat',
        confirmed: true,
      ));
      expect((await store.load('deepseek'))!.confirmed, isTrue);
      expect(store.generation, 0);
    });

    test('insecure-confirmation-only change does not invalidate', () async {
      final box = _FakeBox();
      final store = _store(box, _FakeCredentials());
      const base = LlmProviderAccount(
        providerId: 'custom-openai',
        baseUrl: 'http://192.168.1.10:1234',
        model: 'm1',
        httpInsecureConfirmed: true,
        confirmed: true,
      );
      await store.save(base);
      final generationBefore = store.generation;

      await store.save(base.copyWith(httpInsecureConfirmed: false));

      expect((await store.load('custom-openai'))!.confirmed, isTrue);
      expect(store.generation, generationBefore);
    });
  });

  group('key lifecycle', () {
    test('writeKey resets confirmation and bumps generation', () async {
      final box = _FakeBox();
      final credentials = _FakeCredentials();
      final store = _store(box, credentials);
      await store.save(const LlmProviderAccount(
        providerId: 'deepseek',
        model: 'deepseek-chat',
        confirmed: true,
      ));
      final generationBefore = store.generation;

      await store.writeKey('deepseek', _keyA);

      expect(await store.readKey('deepseek'), _keyA);
      expect((await store.load('deepseek'))!.confirmed, isFalse);
      expect(store.generation, generationBefore + 1);
    });

    test('deleteKey also invalidates', () async {
      final box = _FakeBox();
      final credentials = _FakeCredentials();
      final store = _store(box, credentials);
      await store.writeKey('deepseek', _keyA);
      await store.save(const LlmProviderAccount(
        providerId: 'deepseek',
        model: 'deepseek-chat',
        confirmed: true,
      ));
      final generationBefore = store.generation;

      await store.deleteKey('deepseek');

      expect(await store.readKey('deepseek'), isNull);
      expect((await store.load('deepseek'))!.confirmed, isFalse);
      expect(store.generation, generationBefore + 1);
    });

    test('keys are isolated per provider', () async {
      final store = _store(_FakeBox(), _FakeCredentials());
      await store.writeKey('deepseek', _keyA);
      await store.writeKey('siliconflow', _keyB);
      expect(await store.readKey('deepseek'), _keyA);
      expect(await store.readKey('siliconflow'), _keyB);
      expect(await store.readKey('unknown-provider'), isNull);
    });
  });

  group('active provider and removal', () {
    test('setActive round-trips and clears', () async {
      final store = _store(_FakeBox(), _FakeCredentials());
      expect(await store.activeProvider(), isNull);
      await store.setActive('deepseek');
      expect(await store.activeProvider(), 'deepseek');
      await store.setActive(null);
      expect(await store.activeProvider(), isNull);
    });

    test('remove deletes account, credential and active pointer', () async {
      final box = _FakeBox();
      final credentials = _FakeCredentials();
      final store = _store(box, credentials);
      await store.save(const LlmProviderAccount(
        providerId: 'deepseek',
        model: 'deepseek-chat',
      ));
      await store.writeKey('deepseek', _keyA);
      await store.setActive('deepseek');
      final generationBefore = store.generation;

      await store.remove('deepseek');

      expect(await store.load('deepseek'), isNull);
      expect((await store.loadAll()), isEmpty);
      expect(credentials.deleted, contains('deepseek'));
      expect(await store.activeProvider(), isNull);
      expect(store.generation, generationBefore + 1);
    });
  });

  group('key leakage surfaces (acceptance 2)', () {
    test('settings box never contains a key, account blob has no key field', () async {
      final box = _FakeBox();
      final store = _store(box, _FakeCredentials());
      await store.save(const LlmProviderAccount(
        providerId: 'deepseek',
        model: 'deepseek-chat',
      ));
      await store.writeKey('deepseek', _keyA);

      final dump = jsonEncode(box.map);
      expect(dump.contains(_keyA), isFalse,
          reason: 'API Key 不得进入设置存储（Hive 导出/备份面）');
      final accountBlob =
          box.map[LlmProviderConfigStore.accountKey('deepseek')] as String;
      expect(accountBlob.contains('api_key'), isFalse);
      expect(jsonDecode(accountBlob), isA<Map>());
    });

    test('secure entry keys are provider-scoped and validated', () async {
      expect(SecureLlmProviderCredentialStore.entryKey('deepseek'),
          'piliavalon.llm.v2.api_key.deepseek');
      // providerId guard fires before any platform storage call.
      final store = SecureLlmProviderCredentialStore();
      await expectLater(
        store.write('a/b', _keyA),
        throwsA(isA<JevCredentialException>()),
      );
      await expectLater(
        store.write('..%2Fx', _keyA),
        throwsA(isA<JevCredentialException>()),
      );
    });

    test('provider switch resolves headers from the new provider only', () async {
      final box = _FakeBox();
      final store = _store(box, _FakeCredentials());
      await store.writeKey('deepseek', _keyA);
      await store.writeKey('siliconflow', _keyB);

      final deepseek = LlmResolvedProvider(
        preset: llmProviderPresetById('deepseek')!,
        account: const LlmProviderAccount(providerId: 'deepseek'),
      );
      final siliconflow = LlmResolvedProvider(
        preset: llmProviderPresetById('siliconflow')!,
        account: const LlmProviderAccount(providerId: 'siliconflow'),
      );
      final deepseekHeaders =
          deepseek.authHeaders((await store.readKey('deepseek'))!);
      final siliconflowHeaders =
          siliconflow.authHeaders((await store.readKey('siliconflow'))!);
      expect(deepseekHeaders.values.join(), contains(_keyA));
      expect(deepseekHeaders.values.join().contains(_keyB), isFalse);
      expect(siliconflowHeaders.values.join(), contains(_keyB));
      expect(siliconflowHeaders.values.join().contains(_keyA), isFalse);
      // And the request endpoints live on different domains: the resolved
      // header map is per-provider, so no cross-domain key carry-over.
      expect(Uri.parse(deepseek.chatEndpoint!).host,
          isNot(Uri.parse(siliconflow.chatEndpoint!).host));
    });
  });
}