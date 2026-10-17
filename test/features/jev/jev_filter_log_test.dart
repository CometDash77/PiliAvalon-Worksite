import 'dart:convert';
import 'dart:typed_data';

import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/jev/jev_screen_log.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'decisions_schema.dart';

class MemoryBox implements JevSettingsBox {
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

class ThrowingBox implements JevSettingsBox {
  @override
  Object? get(String key, {Object? defaultValue}) => defaultValue;

  @override
  Future<void> put(String key, Object? value) {
    throw StateError('disk on fire');
  }

  @override
  Future<void> delete(String key) async {}
}

class FakeCredentials implements JevCredentialStore {
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

class CapturingTransport {
  CapturingTransport({this.reply});

  Object? Function(int callIndex)? reply;

  final List<Map<String, Object?>> bodies = <Map<String, Object?>>[];
  int calls = 0;

  JevTransport get transport =>
      ({required provider, required apiKey, required body}) async {
        final index = calls++;
        bodies.add(body);
        if (!acceptsDecisionsRequest(body)) {
          throw StateError('HTTP 400: invalid Decisions request schema');
        }
        final answer = reply?.call(index);
        if (answer == null) {
          throw StateError('transport failure');
        }
        return answer;
      };
}

Map<String, Object?> answers(Map<String, num> noul) => <String, Object?>{
  'answers': <String, Object?>{
    for (final entry in noul.entries)
      entry.key: <String, Object?>{'noul': entry.value},
  },
};

class Harness {
  Harness({Set<JevSurface> surfaces = const {}, bool verdictCache = false})
    : settingsBox = MemoryBox(),
      preferenceBox = MemoryBox() {
    settingsBox.values[JevSettingsStore.enabledKey] = true;
    for (final surface in surfaces) {
      settingsBox.values[JevSettingsStore.surfaceKey(surface)] = true;
    }
    settingsBox.values[JevSettingsStore.providerKey] = 'typesafe';
    settingsBox.values[JevSettingsStore.providerConfirmedKey] = true;
    // 终审判定缓存是进程内静态区;默认关闭以免跨用例命中(#123),
    // 缓存用例显式打开。
    settingsBox.values[SettingBoxKey.jevVerdictCacheEnabled] = verdictCache;
  }

  final MemoryBox settingsBox;
  final MemoryBox preferenceBox;

  JevEvaluator evaluator(CapturingTransport capture) => JevEvaluator(
    transport: capture.transport,
    credentials: FakeCredentials(),
    settings: JevSettingsStore(box: settingsBox),
    preferences: JevPreferenceStore(box: preferenceBox),
  );
}

HotVideoItemModel hot(
  String title, {
  int aid = 1,
  String bvid = 'BV1',
}) => HotVideoItemModel.fromJson({
  'aid': aid,
  'cid': 101,
  'bvid': bvid,
  'videos': 1,
  'tid': 17,
  'tname': '游戏',
  'copyright': 1,
  'pic': '',
  'title': title,
  'pubdate': 1,
  'ctime': 1,
  'desc': '',
  'duration': 600,
  'owner': {'mid': 42, 'name': '玩家UP'},
  'stat': {'view': 1000, 'like': 50, 'danmaku': 1},
});

JevFilterLogEntry entry(
  String title, {
  int? time,
  double? noul = 0.95,
  double? confidence,
  double? threshold = 0.95,
  String? ruleId,
  String? reason,
}) => JevFilterLogEntry(
  time: time ?? DateTime.now().millisecondsSinceEpoch,
  surface: JevSurface.hot.id,
  title: title,
  tags: const ['游戏'],
  noul: noul,
  confidence: confidence,
  threshold: threshold,
  ruleId: ruleId,
  reason: reason,
);

void main() {
  setUp(() {
    JevSettingsStore.resetCache();
    JevPreferenceStore.resetCache();
    JevVerdictCache.resetCache();
  });

  tearDown(() {
    // 默认构造会触碰 GStorage.setting(测试环境未初始化),注入空 box 隔离。
    JevFilterLog.instance = JevFilterLog(box: MemoryBox());
    JevScreenLog.instance = JevScreenLog(box: MemoryBox());
  });

  group('JevFilterLog store', () {
    test('环形上限:超过 5 条只保留最新 5 条,新的在前', () async {
      final log = JevFilterLog(box: MemoryBox());
      await log.record([for (var i = 1; i <= 6; i++) entry('t$i')]);

      final loaded = log.load();

      expect(loaded.map((e) => e.title).toList(), [
        't6', 't5', 't4', 't3', 't2',
      ]);
    });

    test('重启后保留:同一 box 的新实例读到相同记录', () async {
      final box = MemoryBox();
      final log = JevFilterLog(box: box);
      await log.record([entry('旧记录', time: 1), entry('新记录', time: 2)]);

      final reloaded = JevFilterLog(box: box).load();

      expect(reloaded.map((e) => e.title), ['新记录', '旧记录']);
      expect(reloaded.first.noul, 0.95);
      expect(reloaded.first.threshold, 0.95);
      expect(reloaded.first.tags, ['游戏']);
    });

    test('损坏 JSON 读回为空', () {
      final box = MemoryBox();
      box.values[JevFilterLog.key] = '{oops';
      expect(JevFilterLog(box: box).load(), isEmpty);
    });

    test('单条损坏跳过,其余保留', () {
      final box = MemoryBox();
      box.values[JevFilterLog.key] = jsonEncode([
        entry('好').toJson(),
        'garbage',
        entry('也好').toJson(),
      ]);

      final loaded = JevFilterLog(box: box).load();

      expect(loaded.map((e) => e.title), ['好', '也好']);
    });

    test('底层 box 抛异常时 record 静默(fail-open)', () async {
      final log = JevFilterLog(box: ThrowingBox());

      await log.record([entry('x')]);

      expect(log.load(), isEmpty);
      await log.clear();
    });

    test('并发 record 串行合并,不丢记录', () async {
      final log = JevFilterLog(box: MemoryBox());
      await Future.wait([
        log.record([entry('a', time: 1)]),
        log.record([entry('b', time: 2)]),
        log.record([entry('c', time: 3)]),
      ]);

      expect(log.load().map((e) => e.title), ['c', 'b', 'a']);
    });

    test('clear 清空全部记录', () async {
      final log = JevFilterLog(box: MemoryBox());
      await log.record([entry('x')]);

      await log.clear();

      expect(log.load(), isEmpty);
    });
  });

  group('JevFinalScreen 埋点', () {
    test('hidden 条目写入筛选日志(标题/面/数值/阈值)', () async {
      final box = MemoryBox();
      JevFilterLog.instance = JevFilterLog(box: box);
      final capture = CapturingTransport(
        reply: (index) => answers({
          'candidate_1': 0.1,
          'candidate_2': 0.95,
          'candidate_3': 0.1,
        }),
      );
      final screen = JevFinalScreen.hotVideo(
        surface: JevSurface.hot,
        evaluator: Harness(surfaces: {JevSurface.hot}).evaluator(capture),
      );

      final result = await screen.screen([
        hot('a'),
        hot('b', bvid: 'BV2'),
        hot('c', bvid: 'BV3'),
      ]);
      await pumpEventQueue();

      expect(result.map((e) => e.title), ['a', 'c']);
      final entries = JevFilterLog(box: box).load();
      expect(entries, hasLength(1));
      expect(entries.single.surface, JevSurface.hot.id);
      expect(entries.single.title, 'b');
      expect(entries.single.tags, ['游戏']);
      expect(entries.single.noul, 0.95);
      expect(entries.single.threshold, 0.95);
      expect(entries.single.confidence, isNull);
      expect(entries.single.ruleId, isNull);
    });

    test('保留候选不写日志', () async {
      final box = MemoryBox();
      JevFilterLog.instance = JevFilterLog(box: box);
      final capture = CapturingTransport(
        reply: (index) => answers({
          'candidate_1': 0.1,
          'candidate_2': 0.1,
        }),
      );
      final screen = JevFinalScreen.hotVideo(
        surface: JevSurface.hot,
        evaluator: Harness(surfaces: {JevSurface.hot}).evaluator(capture),
      );

      final result = await screen.screen([hot('a'), hot('b', bvid: 'BV2')]);
      await pumpEventQueue();

      expect(result.map((e) => e.title), ['a', 'b']);
      expect(JevFilterLog(box: box).load(), isEmpty);
    });

    test('低置信度保留候选不写日志', () async {
      final box = MemoryBox();
      JevFilterLog.instance = JevFilterLog(box: box);
      final capture = CapturingTransport(
        reply: (index) => {
          'answers': {
            'candidate_1': {'noul': 0.99, 'confidence': 0.5},
          },
        },
      );
      final screen = JevFinalScreen.hotVideo(
        surface: JevSurface.hot,
        evaluator: Harness(surfaces: {JevSurface.hot}).evaluator(capture),
      );

      final result = await screen.screen([hot('a')]);
      await pumpEventQueue();

      expect(result.map((e) => e.title), ['a']);
      expect(JevFilterLog(box: box).load(), isEmpty);
    });

    test('fail-open:transport 失败时不写日志', () async {
      final box = MemoryBox();
      JevFilterLog.instance = JevFilterLog(box: box);
      final capture = CapturingTransport();
      final screen = JevFinalScreen.hotVideo(
        surface: JevSurface.hot,
        evaluator: Harness(surfaces: {JevSurface.hot}).evaluator(capture),
      );

      final result = await screen.screen([hot('a'), hot('b')]);
      await pumpEventQueue();

      expect(result.map((e) => e.title), ['a', 'b']);
      expect(JevFilterLog(box: box).load(), isEmpty);
    });

    test('面开关关闭时不写日志也不发请求', () async {
      final box = MemoryBox();
      JevFilterLog.instance = JevFilterLog(box: box);
      final capture = CapturingTransport();
      final screen = JevFinalScreen.hotVideo(
        surface: JevSurface.hot,
        evaluator: Harness(surfaces: {}).evaluator(capture),
      );

      final items = [hot('a'), hot('b')];
      final result = await screen.screen(items);
      await pumpEventQueue();

      expect(identical(result, items), isTrue);
      expect(JevFilterLog(box: box).load(), isEmpty);
    });

    test('连续 6 次筛除只保留最新 5 条,新的在前', () async {
      final box = MemoryBox();
      JevFilterLog.instance = JevFilterLog(box: box);
      final capture = CapturingTransport(
        reply: (index) => answers({'candidate_1': 0.95}),
      );
      final screen = JevFinalScreen.hotVideo(
        surface: JevSurface.hot,
        evaluator: Harness(surfaces: {JevSurface.hot}).evaluator(capture),
      );
      for (var i = 1; i <= 6; i++) {
        await screen.screen([hot('x$i', bvid: 'BV$i')]);
      }
      await pumpEventQueue();

      expect(
        JevFilterLog(box: box).load().map((e) => e.title).toList(),
        ['x6', 'x5', 'x4', 'x3', 'x2'],
      );
    });

    test('单次 pass 多批次:判定数值与候选一一对应', () async {
      final box = MemoryBox();
      JevFilterLog.instance = JevFilterLog(box: box);
      final capture = CapturingTransport(
        reply: (index) => index == 0
            ? answers({
              'candidate_1': 0.95,
              'candidate_2': 0.1,
              'candidate_3': 0.1,
            })
            : answers({
              'candidate_1': 0.96,
              'candidate_2': 0.1,
              'candidate_3': 0.1,
            }),
      );
      final screen = JevFinalScreen.hotVideo(
        surface: JevSurface.hot,
        evaluator: Harness(surfaces: {JevSurface.hot}).evaluator(capture),
      );
      final result = await screen.screen([
        for (var i = 1; i <= 6; i++) hot('x$i', bvid: 'BV$i'),
      ]);
      await pumpEventQueue();

      // batchSize=3:每批第一个候选被筛除(x1 与 x4),弱判断保留。
      expect(result.map((e) => e.title), ['x2', 'x3', 'x5', 'x6']);
      final entries = JevFilterLog(box: box).load();
      expect(entries.map((e) => e.title), ['x4', 'x1']);
      // 判定数值与所属批次一一对应:x4 取批 1 自己的 0.96,不串用批 0 的 0.95。
      expect(entries[0].noul, 0.96);
      expect(entries[1].noul, 0.95);
      expect(entries.every((e) => e.threshold == 0.95), isTrue);
    });

    test('判定缓存命中的筛除记录无数值(不编造)', () async {
      final box = MemoryBox();
      JevFilterLog.instance = JevFilterLog(box: box);
      final capture = CapturingTransport(
        reply: (index) => answers({'candidate_1': 0.95}),
      );
      final screen = JevFinalScreen.hotVideo(
        surface: JevSurface.hot,
        evaluator: Harness(
          surfaces: {JevSurface.hot},
          verdictCache: true,
        ).evaluator(capture),
      );

      expect((await screen.screen([hot('x1', bvid: 'BV1')])), isEmpty);
      expect((await screen.screen([hot('x1', bvid: 'BV1')])), isEmpty);
      await pumpEventQueue();

      final entries = JevFilterLog(box: box).load();
      expect(entries, hasLength(2));
      // 第二次来自判定缓存:没有本次判定数值,记录如实留空。
      expect(entries.first.noul, isNull);
      expect(entries.first.threshold, isNull);
      expect(entries.last.noul, 0.95);
      expect(entries.last.threshold, 0.95);
    });

    test('连接验证(probe)成功后不产生筛选日志', () async {
      final box = MemoryBox();
      JevFilterLog.instance = JevFilterLog(box: box);
      final probe = JevHttpProbe(dio: Dio()..httpClientAdapter = _ProbeAdapter());

      final result = await probe.call(
        provider: JevProvider.typeSafe,
        apiKey: 'sk-test',
      );
      await pumpEventQueue();

      expect(result.outcome, JevProbeOutcome.ok);
      expect(JevFilterLog(box: box).load(), isEmpty);
    });
  });


  group('直播筛除记录实例(issue #115)', () {
    test('独立 storageKey 与默认实例互不覆盖', () async {
      final box = MemoryBox();
      final liveLog = JevFilterLog(box: box, storageKey: '${JevSettingsStore.namespace}.live_filter_log.v1', capacity: 500);
      await JevFilterLog(box: box).record([entry('通用筛除', time: 1)]);
      await liveLog.record([
        entry('直播筛除', time: 2, reason: '未命中任何保留规则'),
      ]);

      expect(JevFilterLog(box: box).load().single.title, '通用筛除');
      expect(liveLog.load().single.title, '直播筛除');
      expect(liveLog.load().single.reason, '未命中任何保留规则');

      // 清空只影响直播实例自己的 key。
      await liveLog.clear();
      expect(liveLog.load(), isEmpty);
      expect(JevFilterLog(box: box).load(), hasLength(1));
    });

    test('环形上限 500 条:501 条只保留最新 500', () async {
      final box = MemoryBox();
      final liveLog = JevFilterLog(box: box, storageKey: '${JevSettingsStore.namespace}.live_filter_log.v1', capacity: 500);
      final entries = [
        for (var i = 1; i <= 501; i++) entry('直播间 $i', time: i),
      ];
      await liveLog.record(entries);
      final loaded = liveLog.load();
      expect(loaded, hasLength(500));
      expect(loaded.first.title, '直播间 501');
      expect(loaded.last.title, '直播间 2');
    });

    test('重启后仍可读(reason 一并持久化)', () async {
      final box = MemoryBox();
      final first = JevFilterLog(box: box, storageKey: '${JevSettingsStore.namespace}.live_filter_log.v1', capacity: 500);
      await first.record([
        entry('复合原因直播', time: 3, ruleId: 'keep-1', reason: '未命中任何保留规则'),
      ]);

      final second = JevFilterLog(box: box, storageKey: '${JevSettingsStore.namespace}.live_filter_log.v1', capacity: 500);
      final loaded = second.load().single;
      expect(loaded.ruleId, 'keep-1');
      expect(loaded.reason, '未命中任何保留规则');
    });
  });
}

class _ProbeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture
  ) async => ResponseBody.fromString(
    jsonEncode({
      'answers': {
        'probe_1': {'type': 'noul', 'noul': 0.5},
      },
    }),
    200,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
  );

  @override
  void close({bool force = false}) {}
}