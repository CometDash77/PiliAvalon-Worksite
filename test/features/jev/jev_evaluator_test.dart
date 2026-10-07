import 'package:PiliPlus/features/jev/jev.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _FakeCredentials implements JevCredentialStore {
  _FakeCredentials({this.stored = 'sk-test-key', this.throwOnRead = false});

  String? stored;
  bool throwOnRead;

  @override
  Future<JevKeyStoreStatus> status() async => JevKeyStoreStatus.available;

  @override
  Future<String?> read() async {
    if (throwOnRead) {
      throw const JevCredentialException('locked');
    }
    return stored;
  }

  @override
  Future<void> write(String apiKey) async {
    stored = apiKey;
  }

  @override
  Future<void> delete() async {
    stored = null;
  }
}

class _CapturingTransport {
  _CapturingTransport({this.reply});

  /// Optional per-call answer; a null return or a throw fails the batch.
  Object? Function(int callIndex)? reply;

  final List<Map<String, Object?>> bodies = <Map<String, Object?>>[];
  int calls = 0;

  JevTransport get transport =>
      ({required provider, required apiKey, required body}) async {
        final index = calls++;
        bodies.add(body);
        final answer = reply?.call(index);
        if (answer == null) {
          throw StateError('transport failure');
        }
        return answer;
      };
}

Map<String, Object?> _answers(
  Map<String, num> noul, {
  Map<String, num>? confidence,
}) => <String, Object?>{
  'answers': <String, Object?>{
    for (final entry in noul.entries)
      entry.key: <String, Object?>{
        'noul': entry.value,
        if (confidence?[entry.key] != null)
          'confidence': confidence![entry.key],
      },
  },
};

class _Harness {
  _Harness({
    this.confirmed = true,
    _FakeCredentials? credentials,
    JevPreferenceProfile? profile,
  }) : credentials = credentials ?? _FakeCredentials() {
    settingsBox = _MemoryBox();
    settingsBox.values[JevSettingsStore.enabledKey] = true;
    settingsBox.values[JevSettingsStore.surfaceKey(JevSurface.homeWeb)] = true;
    settingsBox.values[JevSettingsStore.providerKey] = 'typesafe';
    if (confirmed) {
      settingsBox.values[JevSettingsStore.providerConfirmedKey] = true;
    }
    preferenceBox = _MemoryBox();
    if (profile != null) {
      preferenceBox.values[JevPreferenceStore.profileKey] = profile.encode();
    }
  }

  final bool confirmed;

  late final _MemoryBox settingsBox;
  late final _MemoryBox preferenceBox;
  final _FakeCredentials credentials;

  JevEvaluator evaluator(_CapturingTransport capture) => JevEvaluator(
    transport: capture.transport,
    credentials: credentials,
    settings: JevSettingsStore(box: settingsBox),
    preferences: JevPreferenceStore(box: preferenceBox),
  );
}

void main() {
  setUp(() {
    JevSettingsStore.resetCache();
    JevPreferenceStore.resetCache();
  });

  JevCandidate candidate(String title) => JevCandidate(title: title);

  test('面开关关着时什么都不发', () async {
    final capture = _CapturingTransport();
    final result = await _Harness().evaluator(capture).screen([
      candidate('a'),
      candidate('b'),
    ], surface: JevSurface.hot);

    expect(result.status, JevScreenStatus.disabled);
    expect(result.requests, 0);
    expect(capture.calls, 0);
    expect(result.hidden, [false, false]);
  });

  test('未确认的 provider 绝不路由', () async {
    final capture = _CapturingTransport();
    final result = await _Harness(
      confirmed: false,
    ).evaluator(capture).screen([candidate('a')], surface: JevSurface.homeWeb);

    expect(result.status, JevScreenStatus.noCredential);
    expect(capture.calls, 0);
    expect(result.hidden, [false]);
  });

  test('没有可用密钥或读取失败时全部保持可见', () async {
    final capture = _CapturingTransport();

    final locked = _Harness(credentials: _FakeCredentials(throwOnRead: true));
    final lockedResult = await locked.evaluator(capture).screen([
      candidate('a'),
    ], surface: JevSurface.homeWeb);
    expect(lockedResult.status, JevScreenStatus.noCredential);
    expect(lockedResult.hidden, [false]);

    final missing = _Harness(credentials: _FakeCredentials(stored: null));
    final missingResult = await missing.evaluator(capture).screen([
      candidate('a'),
    ], surface: JevSurface.homeWeb);
    expect(missingResult.status, JevScreenStatus.noCredential);
    expect(capture.calls, 0);
  });

  test('按批上限串行分批，请求体只装共享偏好档与键位问题', () async {
    final capture = _CapturingTransport(
      reply: (index) => _answers({
        'candidate_1': 0.1,
        'candidate_2': 0.1,
        'candidate_3': 0.1,
      }),
    );
    final harness = _Harness(
      profile: JevPreferenceProfile.empty.recordTheme(
        '某主题',
        now: DateTime.now(),
      ),
    );
    final candidates = [
      candidate('1'),
      candidate('2'),
      candidate('3'),
      candidate('4'),
      candidate('5'),
      candidate('6'),
      candidate('7'),
    ];
    final result = await harness
        .evaluator(capture)
        .screen(candidates, surface: JevSurface.homeWeb);

    expect(result.status, JevScreenStatus.evaluated);
    expect(result.requests, 3);
    expect(capture.calls, 3);

    final first = capture.bodies[0];
    expect(first['model'], 'jev-latest');
    final questions = first['questions'] as List;
    expect((questions[0] as Map)['id'], 'candidate_1');
    expect((questions[2] as Map)['id'], 'candidate_3');
    expect((questions[0] as Map)['question'], JevQuestion.text);
    expect((capture.bodies[2]['questions'] as List), hasLength(1));
    expect(first['state'], {
      'themes': [
        {'theme': '某主题', 'count': 1},
      ],
    });
  });

  test('只有达到阈值才隐藏', () async {
    final capture = _CapturingTransport(
      reply: (index) => _answers({'candidate_1': 0.95, 'candidate_2': 0.949}),
    );
    final result = await _Harness().evaluator(capture).screen([
      candidate('a'),
      candidate('b'),
    ], surface: JevSurface.homeWeb);

    expect(result.hidden, [true, false]);
  });

  test('已报告的低置信度保持候选可见', () async {
    final capture = _CapturingTransport(
      reply: (index) => _answers(
        {'candidate_1': 0.99, 'candidate_2': 0.99},
        confidence: {'candidate_1': 0.89, 'candidate_2': 0.9},
      ),
    );
    final result = await _Harness().evaluator(capture).screen([
      candidate('a'),
      candidate('b'),
    ], surface: JevSurface.homeWeb);

    expect(result.hidden, [false, true]);
  });

  test('缺答的候选保持可见', () async {
    final capture = _CapturingTransport(
      reply: (index) => _answers({'candidate_1': 0.99}),
    );
    final result = await _Harness().evaluator(capture).screen([
      candidate('a'),
      candidate('b'),
    ], surface: JevSurface.homeWeb);

    expect(result.hidden, [true, false]);
  });

  test('provider 失败或响应不可解析时整批放行', () async {
    final failing = _CapturingTransport();
    final failingResult = await _Harness().evaluator(failing).screen([
      candidate('a'),
    ], surface: JevSurface.homeWeb);
    expect(failingResult.status, JevScreenStatus.providerUnavailable);
    expect(failingResult.hidden, [false]);
    expect(failingResult.requests, 1);

    final malformed = _CapturingTransport(reply: (index) => 'not-a-map');
    final malformedResult = await _Harness().evaluator(malformed).screen([
      candidate('a'),
    ], surface: JevSurface.homeWeb);
    expect(malformedResult.status, JevScreenStatus.providerUnavailable);
    expect(malformedResult.hidden, [false]);
  });

  test('前一批失败不拖垮后面的批', () async {
    final capture = _CapturingTransport(
      reply: (index) {
        if (index == 0) {
          throw StateError('first batch down');
        }
        return _answers({
          'candidate_1': 0.99,
          'candidate_2': 0.2,
          'candidate_3': 0.99,
        });
      },
    );
    final candidates = [
      candidate('1'),
      candidate('2'),
      candidate('3'),
      candidate('4'),
      candidate('5'),
      candidate('6'),
    ];
    final result = await _Harness()
        .evaluator(capture)
        .screen(candidates, surface: JevSurface.homeWeb);

    expect(result.status, JevScreenStatus.evaluated);
    expect(result.requests, 2);
    expect(result.hidden, [false, false, false, true, false, true]);
  });

  test('请求体不带任何身份字段', () async {
    final capture = _CapturingTransport(
      reply: (index) => _answers({'candidate_1': 0.1}),
    );
    await _Harness().evaluator(capture).screen(
      const [
        JevCandidate(
          title: '某个标题',
          snippet: '短简介',
          tags: ['游戏', '攻略'],
        ),
      ],
      surface: JevSurface.homeWeb,
    );

    final body = capture.bodies.single;
    final context =
        ((body['questions'] as List).single as Map)['candidate'] as Map;
    expect(context.keys.toSet(), {'title', 'snippet', 'tags'});
    final encoded = body.toString();
    expect(encoded.contains('http'), isFalse);
    expect(encoded.contains('BV1'), isFalse);
    expect(encoded.contains('aid'), isFalse);
    expect(encoded.contains('owner'), isFalse);
  });

  test('空候选列表不发请求', () async {
    final capture = _CapturingTransport();
    final result = await _Harness()
        .evaluator(capture)
        .screen(const [], surface: JevSurface.homeWeb);

    expect(result.status, JevScreenStatus.evaluated);
    expect(result.requests, 0);
    expect(capture.calls, 0);
    expect(result.hidden, isEmpty);
  });
}
