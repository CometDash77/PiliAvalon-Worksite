import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/utils/storage_key.dart';
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
  _FakeCredentials();

  String? stored = 'sk-test-key';

  @override
  Future<JevKeyStoreStatus> status() async => JevKeyStoreStatus.available;

  @override
  Future<String?> read() async => stored;

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
  _CapturingTransport({this.reply, this.gate});

  /// Optional per-call answer; a null return or a throw fails the batch.
  Object? Function(int callIndex)? reply;

  /// Optional one-shot gate: the transport waits until it completes, so a
  /// test can hold one pass open while starting another against the same
  /// identities.
  Completer<void>? gate;

  final List<Map<String, Object?>> bodies = <Map<String, Object?>>[];
  int calls = 0;

  JevTransport get transport =>
      ({required provider, required apiKey, required body}) async {
        final index = calls++;
        bodies.add(body);
        final pending = gate;
        if (pending != null && !pending.isCompleted) {
          await pending.future;
        }
        final answer = reply?.call(index);
        if (answer == null) {
          throw StateError('transport failure');
        }
        return answer;
      };
}

/// A bare num is a Noul answer; a Map is copied verbatim so tests can pin
/// 'type' and 'confidence' exactly as the provider would send them.
Map<String, Object?> _answers(Map<String, Object?> values) =>
    <String, Object?>{
      'answers': <String, Object?>{
        for (final entry in values.entries)
          entry.key: entry.value is Map
              ? (entry.value as Map).cast<String, Object?>()
              : <String, Object?>{'noul': entry.value},
      },
    };

JevCandidate candidate(String title, {String? localKey}) =>
    JevCandidate(title: title, localKey: localKey);

List<JevCandidate> videos(int count) => [
  for (var i = 0; i < count; i++)
    JevCandidate(title: '视频 $i', localKey: 'bvid:BVTEST$i'),
];

Future<JevScreening> screen(JevEvaluator evaluator, List<JevCandidate> cs) =>
    evaluator.screen(cs, surface: JevSurface.homeWeb);

class _Rig {
  _Rig() {
    settingsBox = _MemoryBox();
    settingsBox.values[JevSettingsStore.enabledKey] = true;
    settingsBox.values[JevSettingsStore.surfaceKey(JevSurface.homeWeb)] = true;
    settingsBox.values[JevSettingsStore.providerKey] = 'typesafe';
    settingsBox.values[JevSettingsStore.providerConfirmedKey] = true;
    preferenceBox = _MemoryBox();
  }

  late final _MemoryBox settingsBox;
  late final _MemoryBox preferenceBox;
  final _FakeCredentials credentials = _FakeCredentials();
  final _CapturingTransport capture = _CapturingTransport();

  /// Mutable clock for TTL tests; advance with [advance].
  DateTime current = DateTime(2024, 1, 1);
  void advance(Duration delta) => current = current.add(delta);

  JevEvaluator evaluator() => JevEvaluator(
    transport: capture.transport,
    credentials: credentials,
    settings: JevSettingsStore(box: settingsBox),
    preferences: JevPreferenceStore(box: preferenceBox),
    verdictCache: JevVerdictCache(box: settingsBox, clock: () => current),
  );
}

void main() {
  setUp(() {
    JevSettingsStore.resetCache();
    JevPreferenceStore.resetCache();
    JevVerdictCache.resetCache();
  });

  test('TTL 内二次终审：上游请求数为 0 且判定一致', () async {
    final rig = _Rig();
    rig.capture.reply = (_) => _answers({
      'candidate_1': 0.99,
      'candidate_2': 0.10,
      'candidate_3': 0.10,
      'candidate_4': 0.10,
    });
    final evaluator = rig.evaluator();
    final first = await screen(evaluator, videos(4));
    expect(first.status, JevScreenStatus.evaluated);
    expect(first.requests, 2); // ceil(4 / 3)
    expect(first.hidden, [true, false, false, false]);
    rig.capture.calls = 0;
    final second = await screen(evaluator, videos(4));
    expect(second.requests, 0);
    expect(second.hidden, first.hidden);
  });

  test('TTL 过期后照常发送上游请求', () async {
    final rig = _Rig();
    rig.settingsBox.values[SettingBoxKey.jevVerdictCacheTtlMinutes] = 1;
    rig.capture.reply = (_) => _answers({
      'candidate_1': 0.99,
      'candidate_2': 0.10,
      'candidate_3': 0.10,
    });
    final evaluator = rig.evaluator();
    final first = await screen(evaluator, videos(3));
    expect(first.requests, 1);
    rig.advance(const Duration(minutes: 2));
    rig.capture.calls = 0;
    final second = await screen(evaluator, videos(3));
    expect(second.requests, 1);
    expect(second.hidden, first.hidden);
  });

  test('超过条目上限时最旧的判定先淘汰', () async {
    final rig = _Rig();
    rig.settingsBox.values[SettingBoxKey.jevVerdictCacheMaxEntries] = 2;
    rig.capture.reply = (_) => _answers({
      'candidate_1': 0.10,
      'candidate_2': 0.10,
      'candidate_3': 0.10,
    });
    final evaluator = rig.evaluator();
    await screen(evaluator, videos(4));
    expect(JevVerdictCache.cachedEntryCount, 2);
    rig.capture.calls = 0;
    await screen(evaluator, videos(4));
    expect(rig.capture.calls, 2); // BVTEST0/1 已淘汰：全量重发
    rig.capture.calls = 0;
    await screen(evaluator, [videos(4)[2], videos(4)[3]]);
    expect(rig.capture.calls, 0); // 最新两条仍在
  });

  test('provider、模型、偏好档或规则集变化使整代失效', () async {
    final rig = _Rig();
    rig.capture.reply = (_) => _answers({'candidate_1': 0.99});
    final evaluator = rig.evaluator();
    await screen(evaluator, videos(1));
    rig.capture.calls = 0;
    await screen(evaluator, videos(1));
    expect(rig.capture.calls, 0); // 基线：命中

    // 换 provider：整代作废，重新发送
    rig.settingsBox.values[JevSettingsStore.providerKey] = 'openrouter';
    rig.capture.reply = (_) => _answers({'candidate_1': 0.10});
    await screen(evaluator, videos(1));
    expect(rig.capture.calls, 1);
    rig.capture.calls = 0;
    await screen(evaluator, videos(1));
    expect(rig.capture.calls, 0); // 新代已缓存

    // 换模型 override：再换一代
    rig.settingsBox.values[JevSettingsStore.modelKey(JevProvider.openRouter)] =
        '~vendor/custom';
    await screen(evaluator, videos(1));
    expect(rig.capture.calls, 1);
    rig.capture.calls = 0;
    await screen(evaluator, videos(1));
    expect(rig.capture.calls, 0);

    // 偏好档变化：state 进入代键，再换一代
    rig.preferenceBox.values[JevPreferenceStore.profileKey] =
        JevPreferenceProfile(
          themes: [
            JevPreferenceTheme(
              theme: '剧透',
              count: 2,
              lastFeedbackAt: DateTime(2024, 1, 1),
            ),
          ],
        ).encode();
    await screen(evaluator, videos(1));
    expect(rig.capture.calls, 1);
    rig.capture.calls = 0;
    await screen(evaluator, videos(1));
    expect(rig.capture.calls, 0);

    // 规则集变化：启用一条视频规则 → 新代全重送并命中
    final ruleStore = JevRuleStore(box: rig.settingsBox);
    await ruleStore.save(
      JevRuleConfig(
        rules: [
          JevRule(id: 'r1', target: JevRuleTarget.video, question: '是否剧透'),
        ],
      ),
    );
    rig.capture.reply = (_) => _answers({
      'candidate_1': 0.10,
      'candidate_1_rule_1_context': {'type': 'noul', 'noul': 1.0},
      'candidate_1_rule_1': {'type': 'noul', 'noul': 0.99},
    });
    final withRule = await screen(evaluator, videos(1));
    expect(rig.capture.calls, 1);
    expect(withRule.hidden, [true]);
    rig.capture.calls = 0;
    await screen(evaluator, videos(1));
    expect(rig.capture.calls, 0); // 规则代命中

    // 移除规则：回到「无规则 + 该偏好档」代，其旧判定仍然有效
    await ruleStore.save(const JevRuleConfig());
    rig.capture.reply = (_) => _answers({'candidate_1': 0.10});
    final back = await screen(evaluator, videos(1));
    expect(back.requests, 0);
    expect(back.hidden, [false]);
  });

  test('失败、解析失败与低置信不入缓存', () async {
    // 传输失败：整批 fail-open，判定不缓存
    var rig = _Rig();
    rig.capture.reply = (_) => null;
    var evaluator = rig.evaluator();
    final failed = await screen(evaluator, videos(1));
    expect(failed.status, JevScreenStatus.providerUnavailable);
    rig.capture.reply = (_) => _answers({'candidate_1': 0.10});
    final recovered = await screen(evaluator, videos(1));
    expect(recovered.requests, 1);
    expect(recovered.status, JevScreenStatus.evaluated);

    // 解析失败（answers 非法）：同样不缓存
    rig = _Rig();
    rig.capture.reply = (_) => {'answers': 'nope'};
    evaluator = rig.evaluator();
    final malformed = await screen(evaluator, videos(1));
    expect(malformed.status, JevScreenStatus.providerUnavailable);
    rig.capture.reply = (_) => _answers({'candidate_1': 0.10});
    expect((await screen(evaluator, videos(1))).requests, 1);

    // 低置信 keep：可见但不入缓存
    rig = _Rig();
    rig.capture.reply = (_) => _answers({
      'candidate_1': {'noul': 0.10, 'confidence': 0.5},
    });
    evaluator = rig.evaluator();
    final low = await screen(evaluator, videos(1));
    expect(low.status, JevScreenStatus.evaluated);
    expect(low.hidden, [false]);
    rig.capture.reply = (_) => _answers({'candidate_1': 0.10});
    expect((await screen(evaluator, videos(1))).requests, 1);
  });

  test('关闭缓存时行为与现状等价', () async {
    final rig = _Rig();
    rig.settingsBox.values[SettingBoxKey.jevVerdictCacheEnabled] = false;
    rig.capture.reply = (_) => _answers({
      'candidate_1': 0.99,
      'candidate_2': 0.10,
      'candidate_3': 0.10,
      'candidate_4': 0.10,
      'candidate_5': 0.10,
    });
    final evaluator = rig.evaluator();
    final first = await screen(evaluator, videos(5));
    expect(first.requests, 2); // ceil(5 / 3)
    expect(first.hidden, [true, false, false, false, false]);
    final second = await screen(evaluator, videos(5));
    expect(second.requests, 2);
    expect(second.hidden, first.hidden);
    expect(JevVerdictCache.cachedEntryCount, 0);
  });

  test('同一视频多槽去重：一个批位一次判定', () async {
    final rig = _Rig();
    rig.capture.reply = (_) => _answers({'candidate_1': 0.99});
    final evaluator = rig.evaluator();
    final aliases = [
      candidate('同一视频', localKey: 'bvid:BVDUP'),
      candidate('同一视频', localKey: 'bvid:BVDUP'),
      candidate('同一视频', localKey: 'bvid:BVDUP'),
      candidate('同一视频', localKey: 'bvid:BVDUP'),
    ];
    final screening = await screen(evaluator, aliases);
    expect(screening.requests, 1);
    expect(screening.hidden, [true, true, true, true]);
    rig.capture.calls = 0;
    final again = await screen(evaluator, aliases);
    expect(again.requests, 0);
    expect(again.hidden, screening.hidden);
  });

  test('并发同键终审合并为单次请求', () async {
    final rig = _Rig();
    final gate = Completer<void>();
    rig.capture.gate = gate;
    rig.capture.reply = (_) => _answers({'candidate_1': 0.99});
    final evaluator = rig.evaluator();
    final aliases = [
      candidate('同一视频', localKey: 'bvid:BVDUP'),
      candidate('同一视频', localKey: 'bvid:BVDUP'),
    ];
    final first = screen(evaluator, aliases);
    final second = screen(evaluator, aliases);
    gate.complete();
    final results = await Future.wait([first, second]);
    expect(rig.capture.calls, 1);
    expect(results[0].hidden, [true, true]);
    expect(results[1].hidden, [true, true]);
  });

  test('上游载荷保持不含视频身份', () async {
    final rig = _Rig();
    rig.capture.reply = (_) => _answers({
      'candidate_1': 0.99,
      'candidate_2': 0.10,
    });
    final evaluator = rig.evaluator();
    await screen(evaluator, [
      candidate('标题甲', localKey: 'bvid:SECRET-BV1'),
      candidate('标题乙', localKey: 'aid:999999'),
      candidate('标题丙'),
    ]);
    expect(rig.capture.bodies, isNotEmpty);
    for (final body in rig.capture.bodies) {
      final encoded = jsonEncode(body);
      expect(encoded.contains('SECRET'), isFalse, reason: encoded);
      expect(encoded.contains('bvid:'), isFalse, reason: encoded);
      expect(encoded.contains('aid:'), isFalse, reason: encoded);
      final state = body['state'] as Map;
      final candidates = state['candidates'] as Map;
      for (final key in candidates.keys) {
        expect(
          (candidates[key] as Map).keys.toSet(),
          equals({'title'}),
          reason: encoded,
        );
      }
    }
  });

  test('无 id 面回退到规范化标题身份；空标题不可缓存', () async {
    final rig = _Rig();
    rig.capture.reply = (_) => _answers({'candidate_1': 0.10});
    final evaluator = rig.evaluator();
    final first = await screen(evaluator, [
      candidate('大  集 同一 Title!'),
    ]);
    expect(first.requests, 1);
    rig.capture.calls = 0;
    final second = await screen(evaluator, [candidate('大集同一title!')]);
    expect(second.requests, 0); // 标题规范化后同一身份
    final third = await screen(evaluator, [candidate('   ')]);
    expect(third.requests, 1); // 空标题照发
    expect((await screen(evaluator, [candidate('  ')])).requests, 1);
  });

  test('JevVerdictCache 直测：TTL、上限、换代与单飞登记', () async {
    var now = DateTime(2024, 1, 1);
    final cache = JevVerdictCache(box: _MemoryBox(), clock: () => now);
    expect(cache.lookup('g1', 'a'), isNull);
    cache.put('g1', 'a', hide: true);
    expect(cache.lookup('g1', 'a'), isTrue);
    now = now.add(const Duration(days: 2));
    expect(cache.lookup('g1', 'a'), isNull); // 默认 TTL 1440 分钟

    final box = _MemoryBox();
    box.values[SettingBoxKey.jevVerdictCacheMaxEntries] = 2;
    final capped = JevVerdictCache(box: box, clock: () => now);
    capped.put('g', 'a', hide: false);
    capped.put('g', 'b', hide: false);
    capped.put('g', 'c', hide: false);
    expect(capped.lookup('g', 'a'), isNull); // 最旧淘汰
    expect(capped.lookup('g', 'b'), isFalse);
    expect(capped.lookup('g', 'c'), isFalse);

    // 换代作废
    capped.put('g2', 'a', hide: true);
    expect(capped.lookup('g2', 'a'), isTrue);
    expect(capped.lookup('g', 'b'), isNull);
    expect(JevVerdictCache.cachedEntryCount, 1);

    // 单飞登记
    final completer = Completer<bool?>();
    expect(capped.registerInFlight('g2', 'a', completer), isTrue);
    expect(capped.registerInFlight('g2', 'a', Completer<bool?>()), isFalse);
    expect(capped.inFlightFuture('g2', 'a'), same(completer.future));
    completer.complete(true);
    capped.releaseInFlight('g2', 'a');
    expect(capped.inFlightFuture('g2', 'a'), isNull);

    JevVerdictCache.resetCache();
    expect(JevVerdictCache.cachedEntryCount, 0);
  });
}
