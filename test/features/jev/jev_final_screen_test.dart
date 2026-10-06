import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/models_new/music/bgm_recommend_list.dart';
import 'package:PiliPlus/models_new/pgc/pgc_index_result/list.dart';
import 'package:PiliPlus/models_new/pgc/pgc_rank/pgc_rank_item_model.dart';
import 'package:flutter_test/flutter_test.dart';

// 评测器测试假件的轻量复刻（见 jev_evaluator_test.dart）。
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

class _ThrowingBox implements JevSettingsBox {
  @override
  Object? get(String key, {Object? defaultValue}) => defaultValue;

  @override
  Future<void> put(String key, Object? value) {
    throw StateError('disk on fire');
  }

  @override
  Future<void> delete(String key) async {}
}

class _FakeCredentials implements JevCredentialStore {
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
  _CapturingTransport({this.reply});

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

Map<String, Object?> _answers(Map<String, num> noul) => <String, Object?>{
  'answers': <String, Object?>{
    for (final entry in noul.entries)
      entry.key: <String, Object?>{'noul': entry.value},
  },
};

/// enabled=true + 指定面打开 + provider 已确认。
class _Harness {
  _Harness({Set<JevSurface> surfaces = const {JevSurface.homeWeb}})
    : settingsBox = _MemoryBox(),
      preferenceBox = _MemoryBox() {
    settingsBox.values[JevSettingsStore.enabledKey] = true;
    for (final surface in surfaces) {
      settingsBox.values[JevSettingsStore.surfaceKey(surface)] = true;
    }
    settingsBox.values[JevSettingsStore.providerKey] = 'typesafe';
    settingsBox.values[JevSettingsStore.providerConfirmedKey] = true;
  }

  final _MemoryBox settingsBox;
  final _MemoryBox preferenceBox;

  JevEvaluator evaluator(_CapturingTransport capture) => JevEvaluator(
    transport: capture.transport,
    credentials: _FakeCredentials(),
    settings: JevSettingsStore(box: settingsBox),
    preferences: JevPreferenceStore(box: preferenceBox),
  );
}

class _TestVideo extends BaseVideoItemModel {
  _TestVideo({String title = 'test video', bool isFollowed = false}) {
    this.title = title;
    cid = 1;
    aid = 1;
    duration = 600;
    owner = _TestOwner();
    stat = _TestStat();
    this.isFollowed = isFollowed;
  }
}

class _TestOwner extends BaseOwner {}

class _TestStat extends BaseStat {
  _TestStat() {
    view = 1000;
    like = 50;
    danmu = 1;
    reply = 1;
    coin = 1;
    favorite = 1;
  }
}

HotVideoItemModel _hot(String title) => HotVideoItemModel.fromJson({
  'aid': 1,
  'cid': 101,
  'bvid': 'BV1',
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

RecommendationBatch _batch() => RecommendationBatch(
  ruleSet: ShieldRuleSet(rules: []),
  config: RecommendationFilterConfig(),
);

void main() {
  setUp(() {
    JevSettingsStore.resetCache();
    JevPreferenceStore.resetCache();
  });

  group('JevFinalScreen.screen', () {
    test('面开关关着时原样返回且不发请求', () async {
      final capture = _CapturingTransport();
      final screen = JevFinalScreen.hotVideo(
        surface: JevSurface.hot,
        evaluator: _Harness(surfaces: {}).evaluator(capture),
      );
      final items = [_hot('a'), _hot('b')];

      final result = await screen.screen(items);

      expect(identical(result, items), isTrue);
      expect(capture.calls, 0);
    });

    test('hidden 命中的条目被丢弃且保持顺序', () async {
      final capture = _CapturingTransport(
        reply: (index) => _answers({
          'candidate_1': 0.1,
          'candidate_2': 0.95,
          'candidate_3': 0.1,
        }),
      );
      final screen = JevFinalScreen.hotVideo(
        surface: JevSurface.hot,
        evaluator: _Harness(surfaces: {JevSurface.hot}).evaluator(capture),
      );

      final result = await screen.screen([_hot('a'), _hot('b'), _hot('c')]);

      expect(result.map((e) => e.title), ['a', 'c']);
      expect(capture.calls, 1);
      final context =
          ((capture.bodies.single['questions'] as List).single as Map);
      expect(context['id'], 'candidate_1');
    });

    test('transport 失败时全部保留（fail-open）', () async {
      final capture = _CapturingTransport();
      final screen = JevFinalScreen.hotVideo(
        surface: JevSurface.hot,
        evaluator: _Harness(surfaces: {JevSurface.hot}).evaluator(capture),
      );

      final result = await screen.screen([_hot('a'), _hot('b')]);

      expect(result.map((e) => e.title), ['a', 'b']);
    });

    test('没有可送审候选时不发请求原样返回', () async {
      final capture = _CapturingTransport();
      final screen = JevFinalScreen.hotVideo(
        surface: JevSurface.hot,
        evaluator: _Harness(surfaces: {JevSurface.hot}).evaluator(capture),
      );

      final result = await screen.screen([_hot('  '), _hot('')]);

      expect(result, hasLength(2));
      expect(capture.calls, 0);
    });
  });

  group('JEV 候选映射', () {
    test('hotVideo：标题 + 分区标签，无其他字段', () async {
      final capture = _CapturingTransport(
        reply: (index) => _answers({'candidate_1': 0.1}),
      );
      final screen = JevFinalScreen.hotVideo(
        surface: JevSurface.hot,
        evaluator: _Harness(surfaces: {JevSurface.hot}).evaluator(capture),
      );

      await screen.screen([_hot('某标题')]);

      final context =
          ((capture.bodies.single['questions'] as List).single
                  as Map)['candidate']
              as Map;
      expect(context, {
        'title': '某标题',
        'tags': ['游戏'],
      });
    });

    test('pgcRank/pgcIndex：只有标题', () async {
      final capture = _CapturingTransport(
        reply: (index) => _answers({'candidate_1': 0.1}),
      );
      await JevFinalScreen.pgcRank(
        evaluator: _Harness(surfaces: {JevSurface.pgc}).evaluator(capture),
      ).screen([
        PgcRankItemModel.fromJson({'title': '某番剧'}),
      ]);
      var context =
          ((capture.bodies.single['questions'] as List).single
                  as Map)['candidate']
              as Map;
      expect(context, {'title': '某番剧'});

      await JevFinalScreen.pgcIndex(
        evaluator: _Harness(surfaces: {JevSurface.pgc}).evaluator(capture),
      ).screen([
        PgcIndexItem.fromJson({'title': '某索引'}),
      ]);
      context =
          ((capture.bodies.single['questions'] as List).single
                  as Map)['candidate']
              as Map;
      expect(context, {'title': '某索引'});
    });

    test('music：标题 + 标签列表名', () async {
      final capture = _CapturingTransport(
        reply: (index) => _answers({'candidate_1': 0.1}),
      );
      await JevFinalScreen.music(
        evaluator: _Harness(surfaces: {JevSurface.music}).evaluator(capture),
      ).screen([
        BgmRecommend.fromJson({
          'title': '某曲',
          'labelList': [
            {'name': '纯音乐'},
          ],
        }),
      ]);

      final context =
          ((capture.bodies.single['questions'] as List).single
                  as Map)['candidate']
              as Map;
      expect(context, {
        'title': '某曲',
        'tags': ['纯音乐'],
      });
    });

    test('homeFeed 终审：标题 + 理由 + 分区/标签', () async {
      final capture = _CapturingTransport(
        reply: (index) => _answers({'candidate_1': 0.1}),
      );
      final surface = RecommendationSurfaces.homeFeed<_TestVideo>(
        jevSurface: JevSurface.homeWeb,
        jevEvaluator: _Harness(surfaces: {JevSurface.homeWeb}).evaluator(
          capture,
        ),
      );
      final entries = [
        RecommendationFeedEntry(
          item: _TestVideo(title: '某视频'),
          candidate: const ShieldCandidate(
            scope: ShieldScope.recommendation,
            title: '某视频',
            reason: '推荐理由',
            category: '游戏',
            tags: ['单机'],
          ),
        ),
      ];

      final result = await surface.finalScreen!(entries, _batch());

      expect(result, hasLength(1));
      final context =
          ((capture.bodies.single['questions'] as List).single
                  as Map)['candidate']
              as Map;
      expect(context, {
        'title': '某视频',
        'snippet': '推荐理由',
        'tags': ['游戏', '单机'],
      });
    });

    test('hotAndRanking 集成：终审命中后条目被丢弃', () async {
      final capture = _CapturingTransport(
        reply: (index) => _answers({
          'candidate_1': 0.1,
          'candidate_2': 0.95,
        }),
      );
      final surface = RecommendationSurfaces.hotAndRanking(
        jevSurface: JevSurface.hot,
        jevEvaluator: _Harness(surfaces: {JevSurface.hot}).evaluator(capture),
      );

      final result = await surface.finalScreen!([
        _hot('a'),
        _hot('b'),
      ], _batch());

      expect(result.map((e) => e.title), ['a']);
    });

    test('relatedVideos 集成：终审命中后条目被丢弃', () async {
      final capture = _CapturingTransport(
        reply: (index) => _answers({'candidate_1': 0.95}),
      );
      final surface = RecommendationSurfaces.relatedVideos(
        jevSurface: JevSurface.related,
        jevEvaluator: _Harness(surfaces: {JevSurface.related}).evaluator(
          capture,
        ),
      );

      final result = await surface.finalScreen!([_hot('a')], _batch());

      expect(result, isEmpty);
    });
  });

  group('JevCardFunnel', () {
    test('面开关关着时不写偏好档', () async {
      final harness = _Harness(surfaces: {});
      final funnel = JevCardFunnel(
        store: JevPreferenceStore(
          box: harness.preferenceBox,
          settings: JevSettingsStore(box: harness.settingsBox),
        ),
      );

      final wrote = await funnel.recordCardDislike(
        title: '某标题',
        selectedReason: '我不想看',
        surface: JevSurface.hot,
      );

      expect(wrote, isFalse);
      expect(harness.preferenceBox.values, isEmpty);
    });

    test('面开着时写入主题摘要', () async {
      final harness = _Harness(surfaces: {JevSurface.hot});
      final funnel = JevCardFunnel(
        store: JevPreferenceStore(
          box: harness.preferenceBox,
          settings: JevSettingsStore(box: harness.settingsBox),
        ),
      );

      final wrote = await funnel.recordCardDislike(
        title: '【攻略】深渊挑战全流程',
        displayedReason: '为你推荐',
        selectedReason: '不想看此UP主',
        surface: JevSurface.hot,
      );

      expect(wrote, isTrue);
      final profile = JevPreferenceProfile.decode(
        harness.preferenceBox.values[JevPreferenceStore.profileKey],
      );
      expect(profile.statePayload()['themes'], isNotEmpty);
    });

    test('底层异常被吞掉返回 false', () async {
      final harness = _Harness(surfaces: {JevSurface.hot});
      final funnel = JevCardFunnel(
        store: JevPreferenceStore(
          box: _ThrowingBox(),
          settings: JevSettingsStore(box: harness.settingsBox),
        ),
      );

      final wrote = await funnel.recordCardDislike(
        title: '某标题',
        surface: JevSurface.hot,
      );

      expect(wrote, isFalse);
    });
  });
}
