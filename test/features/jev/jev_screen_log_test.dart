
import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/jev/jev_comment_screening.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/jev/jev_screen_log.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:fixnum/fixnum.dart';
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
  Harness({Set<JevSurface> surfaces = const {}})
    : settingsBox = MemoryBox(),
      preferenceBox = MemoryBox() {
    settingsBox.values[JevSettingsStore.enabledKey] = true;
    for (final surface in surfaces) {
      settingsBox.values[JevSettingsStore.surfaceKey(surface)] = true;
    }
    settingsBox.values[JevSettingsStore.providerKey] = 'typesafe';
    settingsBox.values[JevSettingsStore.providerConfirmedKey] = true;
    // 终审判定缓存是进程内静态区；日志测试关注实时判定，直接关闭以免
    // 跨用例命中（#123）。
    settingsBox.values[SettingBoxKey.jevVerdictCacheEnabled] = false;
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

ReplyInfo reply(String text) => ReplyInfo(
  id: Int64(987654),
  mid: Int64(12345),
  content: Content(message: text),
);

JevScreenLogEntry entry(String title, {JevScreenLogKind kind = JevScreenLogKind.video}) =>
    JevScreenLogEntry(
      time: 1700000000000,
      kind: kind,
      surface: 'hot',
      title: title,
    );

void main() {
  setUp(() {
    JevSettingsStore.resetCache();
    JevPreferenceStore.resetCache();
  });

  tearDown(() {
    // 默认构造会触碰 GStorage.setting(测试环境未初始化),注入空 box 隔离。
    JevScreenLog.instance = JevScreenLog(box: MemoryBox());
  });

  group('JevScreenLog store', () {
    test('record + load 往返,新的在前', () async {
      final box = MemoryBox();
      final log = JevScreenLog(box: box);
      await log.record([entry('第一条'), entry('第二条')]);

      final loaded = log.load();

      expect(loaded.map((e) => e.title), ['第二条', '第一条']);
      expect(loaded.every((e) => e.kind == JevScreenLogKind.video), isTrue);
    });

    test('record 按 kind 与 surface 保真', () async {
      final log = JevScreenLog(box: MemoryBox());
      await log.record([
        const JevScreenLogEntry(
          time: 1,
          kind: JevScreenLogKind.comment,
          surface: 'comment',
          title: '评论正文',
          snippet: '父评论',
        ),
      ]);

      final first = log.load().single;

      expect(first.kind, JevScreenLogKind.comment);
      expect(first.surface, 'comment');
      expect(first.snippet, '父评论');
    });

    test('环形上限:超出 ${JevScreenLog.maxEntries} 条时保留最新', () async {
      final log = JevScreenLog(box: MemoryBox());
      await log.record([
        for (var i = 0; i < JevScreenLog.maxEntries + 10; i++)
          entry('条目$i', kind: JevScreenLogKind.video),
      ]);

      final loaded = log.load();

      expect(loaded, hasLength(JevScreenLog.maxEntries));
      expect(loaded.first.title, '条目${JevScreenLog.maxEntries + 9}');
    });

    test('超长文本截断到 ${JevScreenLog.maxTextLength} 字', () async {
      final log = JevScreenLog(box: MemoryBox());
      final longTitle = '长' * (JevScreenLog.maxTextLength + 50);
      await log.record([entry(longTitle, kind: JevScreenLogKind.comment)]);

      final first = log.load().single;

      expect(first.title.length, JevScreenLog.maxTextLength);
    });

    test('损坏 JSON 返回空列表', () {
      final box = MemoryBox();
      box.values[JevScreenLog.key] = '{not json';
      final log = JevScreenLog(box: box);

      expect(log.load(), isEmpty);
    });

    test('底层 box 抛异常时 record 静默', () async {
      final log = JevScreenLog(box: ThrowingBox());

      await log.record([entry('某条目')]);

      expect(log.load(), isEmpty);
    });

    test('clear 清空全部记录', () async {
      final log = JevScreenLog(box: MemoryBox());
      await log.record([entry('某条目')]);

      await log.clear();

      expect(log.load(), isEmpty);
    });
  });

  group('JevFinalScreen 埋点', () {
    test('视频面:hidden 条目进入日志(kind=video)', () async {
      final box = MemoryBox();
      JevScreenLog.instance = JevScreenLog(box: box);
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

      // 判定缓存按卡片身份分组(issue #123, bvid 优先):三个条目必须携带
      // 不同 bvid,否则会被当作同一视频的别名而只评估一个位置。
      final result = await screen.screen([
        hot('a'),
        hot('b', bvid: 'BV2'),
        hot('c', bvid: 'BV3'),
      ]);
      await pumpEventQueue();

      expect(result.map((e) => e.title), ['a', 'c']);
      final entries = JevScreenLog(box: box).load();
      expect(entries, hasLength(1));
      expect(entries.single.kind, JevScreenLogKind.video);
      expect(entries.single.surface, JevSurface.hot.id);
      expect(entries.single.title, 'b');
      expect(entries.single.snippet, '游戏');
    });

    // 评论面日志走 JevCommentScreening(issue #122:评论过滤合并到判断规则,
    // JevFinalScreen 不再有评论工厂)。
    test('评论面:hidden 条目进入日志(kind=comment,ruleId,snippet=父评论)', () async {
      final box = MemoryBox();
      JevScreenLog.instance = JevScreenLog(box: box);
      final settingsBox = MemoryBox();
      final store = JevSettingsStore(box: settingsBox);
      await store.save(
        const JevSettings(
          enabled: true,
          provider: JevProvider.typeSafe,
          providerConfirmed: true,
          surfaces: {JevSurface.comment},
        ),
      );
      final rulesStore = JevRuleStore(box: settingsBox);
      await rulesStore.save(
        const JevRuleConfig(
          rules: [
            JevRule(
              id: 'r1',
              target: JevRuleTarget.comment,
              question: '这条评论是否在灌水?',
            ),
          ],
        ),
      );
      final screening = JevCommentScreening(
        transport:
            ({required provider, required apiKey, required body}) async => {
              'answers': {
                'candidate_1_rule_1_context': {
                  'type': 'noul',
                  'noul': 0.98,
                },
                'candidate_1_rule_1': {'type': 'noul', 'noul': 0.99},
              },
            },
        settings: store,
        rules: rulesStore,
        credentials: FakeCredentials(),
      );

      final result = await screening.filter(
        [reply('被屏蔽的评论'), reply('正常评论')],
        parents: const ['父评论正文', null],
      );

      expect(result.replies.map((e) => e.content.message), ['正常评论']);
      final entries = JevScreenLog(box: box).load();
      expect(entries, hasLength(1));
      expect(entries.single.kind, JevScreenLogKind.comment);
      expect(entries.single.surface, JevSurface.comment.id);
      expect(entries.single.title, '被屏蔽的评论');
      expect(entries.single.snippet, '父评论正文');
      expect(entries.single.ruleId, 'r1');
    });

    test('fail-open:transport 失败时不写日志', () async {
      final box = MemoryBox();
      JevScreenLog.instance = JevScreenLog(box: box);
      final capture = CapturingTransport();
      final screen = JevFinalScreen.hotVideo(
        surface: JevSurface.hot,
        evaluator: Harness(surfaces: {JevSurface.hot}).evaluator(capture),
      );

      final result = await screen.screen([hot('a'), hot('b')]);
      await pumpEventQueue();

      expect(result.map((e) => e.title), ['a', 'b']);
      expect(JevScreenLog(box: box).load(), isEmpty);
    });

    test('面开关关闭时不写日志也不发请求', () async {
      final box = MemoryBox();
      JevScreenLog.instance = JevScreenLog(box: box);
      final capture = CapturingTransport();
      final screen = JevFinalScreen.hotVideo(
        surface: JevSurface.hot,
        evaluator: Harness(surfaces: {}).evaluator(capture),
      );

      final items = [hot('a'), hot('b')];
      final result = await screen.screen(items);
      await pumpEventQueue();

      expect(identical(result, items), isTrue);
      expect(JevScreenLog(box: box).load(), isEmpty);
    });
  });
}
