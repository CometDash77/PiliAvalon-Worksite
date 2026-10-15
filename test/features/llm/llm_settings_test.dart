import 'package:PiliPlus/features/jev/jev_settings.dart' show JevSettingsBox;
import 'package:PiliPlus/features/llm/llm.dart';
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

LlmProviderConfig _openai({bool insecure = false}) => LlmProviderConfig(
  protocol: LlmProtocol.openAICompatible,
  baseUrl: 'https://api.example.com/v1',
  model: 'm1',
  httpInsecureConfirmed: insecure,
);

void main() {
  test('an empty config lists every structural gap', () {
    final issues = LlmProviderConfig.empty.issues;
    expect(issues, contains(LlmConfigIssue.missingProtocol));
    expect(issues, contains(LlmConfigIssue.missingBaseUrl));
    expect(issues, contains(LlmConfigIssue.missingModel));
  });

  test('a complete https config has no issues', () {
    expect(_openai().issues, isEmpty);
  });

  test('http needs the explicit insecure confirmation', () {
    const config = LlmProviderConfig(
      protocol: LlmProtocol.openAICompatible,
      baseUrl: 'http://192.168.1.10:1234/v1',
      model: 'm1',
    );
    expect(config.issues, [LlmConfigIssue.insecureBaseUrl]);
    expect(
      config.copyWith(httpInsecureConfirmed: true).issues,
      isEmpty,
    );
  });

  test('non-http(s) addresses and hostless strings are invalid', () {
    for (final bad in ['ftp://x', 'not a url', 'https:///path']) {
      final config = LlmProviderConfig(
        protocol: LlmProtocol.openAICompatible,
        baseUrl: bad,
        model: 'm1',
      );
      expect(
        config.issues,
        contains(LlmConfigIssue.invalidBaseUrl),
        reason: bad,
      );
    }
  });

  test('endpoints append the protocol path to the normalized base URL', () {
    const openai = LlmProviderConfig(
      protocol: LlmProtocol.openAICompatible,
      baseUrl: 'https://api.example.com/v1///',
      model: 'm1',
    );
    expect(
      openai.chatEndpoint,
      'https://api.example.com/v1/chat/completions',
    );
    expect(openai.catalogEndpoint, 'https://api.example.com/v1/models');

    const anthropic = LlmProviderConfig(
      protocol: LlmProtocol.anthropicCompatible,
      baseUrl: 'https://api.example.com',
      model: 'm1',
    );
    expect(anthropic.chatEndpoint, 'https://api.example.com/v1/messages');
    expect(anthropic.catalogEndpoint, 'https://api.example.com/v1/models');
  });

  test('endpoints are null while protocol or base URL is unusable', () {
    expect(LlmProviderConfig.empty.chatEndpoint, isNull);
    expect(
      const LlmProviderConfig(
        protocol: LlmProtocol.openAICompatible,
        baseUrl: 'nope',
        model: 'm1',
      ).chatEndpoint,
      isNull,
    );
  });

  test('settings store round-trips the config', () async {
    final box = _FakeBox();
    final store = LlmSettingsStore(box: box);
    const config = LlmProviderConfig(
      protocol: LlmProtocol.openAICompatible,
      baseUrl: 'https://api.example.com/v1',
      model: 'm1',
      confirmed: true,
    );
    await store.save(config);
    expect(LlmSettingsStore.snapshot, config);
    expect(await store.load(), config);
    expect(box.map[LlmSettingsStore.baseUrlKey], config.baseUrl);
  });

  test('saving an unselected protocol clears the stored id', () async {
    final box = _FakeBox();
    final store = LlmSettingsStore(box: box);
    box.map[LlmSettingsStore.protocolKey] = 'openai_compatible';
    await store.save(const LlmProviderConfig(baseUrl: 'x', model: 'm'));
    expect(box.map.containsKey(LlmSettingsStore.protocolKey), isFalse);
    expect((await store.load()).protocol, isNull);
  });

  test('garbage types from a bad migration fail safe', () async {
    final box = _FakeBox();
    final store = LlmSettingsStore(box: box);
    box.map[LlmSettingsStore.protocolKey] = 123;
    box.map[LlmSettingsStore.baseUrlKey] = 456;
    box.map[LlmSettingsStore.modelKey] = true;
    box.map[LlmSettingsStore.confirmedKey] = 'yes';
    final config = await store.load();
    expect(config.protocol, isNull);
    expect(config.baseUrl, '');
    expect(config.model, '');
    expect(config.confirmed, isFalse);
  });

  test('snapshot follows loads and resetCache clears it', () async {
    final box = _FakeBox();
    final store = LlmSettingsStore(box: box);
    expect(LlmSettingsStore.snapshot, LlmProviderConfig.empty);
    await store.load();
    expect(LlmSettingsStore.snapshot, LlmProviderConfig.empty);
    LlmSettingsStore.resetCache();
    expect(LlmSettingsStore.snapshot, LlmProviderConfig.empty);
  });
}
