import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(_resetLegacyShim);

  // ---------------------------------------------------------------------------
  // 流水线机制：一次快照、固定顺序、阶段可见范围、空列表不提前返回
  // ---------------------------------------------------------------------------
  group('RecommendationPipeline', () {
    test('整批只取一次快照，且同一份快照贯穿所有阶段', () async {
      var batchCalls = 0;
      final seen = <RecommendationBatch>[];

      final pipeline = RecommendationPipeline<int>(
        supplyBatch: () {
          batchCalls++;
          return _batch();
        },
        surface: RecommendationSurface<int>(
          judge: (item, batch) {
            seen.add(batch);
            return true;
          },
          enrichTags: (kept, batch) {
            seen.add(batch);
            return kept;
          },
          gateComments: (kept, batch) {
            seen.add(batch);
            return kept;
          },
          recordExposure: (kept, batch) {
            seen.add(batch);
            return kept;
          },
        ),
        candidateSource: (batch) {
          seen.add(batch);
          return [1, 2, 3];
        },
      );

      final result = await pipeline.run();

      expect(result, [1, 2, 3]);
      expect(batchCalls, 1, reason: '规则与设置整批只读一次');
      expect(seen, hasLength(7)); // 取列表 1 + 判定 3 + 三个阶段（富集/门/曝光）各 1
      for (final batch in seen) {
        expect(identical(batch, seen.first), isTrue);
      }
    });

    test('阶段顺序固定：取列表 → 判定 → 标签富集 → 评论门 → 曝光记录', () async {
      final log = <String>[];

      final pipeline = RecommendationPipeline<int>(
        supplyBatch: _batch,
        surface: RecommendationSurface<int>(
          judge: (item, batch) {
            log.add('judge:$item');
            return item.isEven;
          },
          enrichTags: (kept, batch) {
            log.add('enrich:$kept');
            return kept;
          },
          gateComments: (kept, batch) {
            log.add('gate:$kept');
            return kept;
          },
          recordExposure: (kept, batch) {
            log.add('exposure:$kept');
            return kept;
          },
        ),
        candidateSource: (batch) {
          log.add('source');
          return [1, 2, 3, 4];
        },
      );

      final result = await pipeline.run();

      expect(result, [2, 4]);
      expect(log, [
        'source',
        'judge:1',
        'judge:2',
        'judge:3',
        'judge:4',
        'enrich:[2, 4]',
        'gate:[2, 4]',
        'exposure:[2, 4]',
      ]);
    });

    test('终审阶段固定在评论门之后、曝光记录之前', () async {
      final log = <String>[];

      final pipeline = RecommendationPipeline<int>(
        supplyBatch: _batch,
        surface: RecommendationSurface<int>(
          judge: (item, batch) => true,
          enrichTags: (kept, batch) {
            log.add('enrich:$kept');
            return kept;
          },
          gateComments: (kept, batch) {
            log.add('gate:$kept');
            return kept;
          },
          finalScreen: (kept, batch) {
            log.add('final:$kept');
            return kept.where((item) => item != 4).toList();
          },
          recordExposure: (kept, batch) {
            log.add('exposure:$kept');
            return kept;
          },
        ),
        candidateSource: (batch) => [2, 4, 6],
      );

      final result = await pipeline.run();

      expect(result, [2, 6]);
      expect(log, [
        'enrich:[2, 4, 6]',
        'gate:[2, 4, 6]',
        'final:[2, 4, 6]',
        'exposure:[2, 6]',
      ]);
    });

    test('后续阶段只看到判定留下的候选，异步阶段保持顺序与内容', () async {
      final snapshot = <String, List<int>>{};

      final pipeline = RecommendationPipeline<int>(
        supplyBatch: _batch,
        surface: RecommendationSurface<int>(
          judge: (item, batch) => item != 2,
          enrichTags: (kept, batch) async {
            await Future<void>.delayed(Duration.zero);
            snapshot['enrich'] = List.of(kept);
            return kept;
          },
          gateComments: (kept, batch) async {
            await Future<void>.delayed(Duration.zero);
            snapshot['gate'] = List.of(kept);
            return kept;
          },
          recordExposure: (kept, batch) {
            snapshot['exposure'] = List.of(kept);
            return kept;
          },
        ),
        candidateSource: (batch) => [5, 2, 1, 4, 3],
      );

      final result = await pipeline.run();

      expect(result, [5, 1, 4, 3]);
      expect(snapshot['enrich'], [5, 1, 4, 3]);
      expect(snapshot['gate'], [5, 1, 4, 3]);
      expect(snapshot['exposure'], [5, 1, 4, 3]);
    });

    test('空列表照样走完全程，不提前返回', () async {
      final log = <String>[];

      final pipeline = RecommendationPipeline<int>(
        supplyBatch: _batch,
        surface: RecommendationSurface<int>(
          judge: (item, batch) {
            log.add('judge');
            return true;
          },
          enrichTags: (kept, batch) {
            log.add('enrich');
            return kept;
          },
          gateComments: (kept, batch) {
            log.add('gate');
            return kept;
          },
          recordExposure: (kept, batch) {
            log.add('exposure');
            return kept;
          },
        ),
        candidateSource: (batch) {
          log.add('source');
          return const [];
        },
      );

      expect(await pipeline.run(), isEmpty);
      expect(log, ['source', 'enrich', 'gate', 'exposure']);
    });

    test('面没提供的阶段不会被调用', () async {
      final surface = RecommendationSurface<int>(
        judge: (item, batch) => item > 1,
      );

      final pipeline = RecommendationPipeline<int>(
        supplyBatch: _batch,
        surface: surface,
        candidateSource: (batch) => [1, 2, 3],
      );

      expect(await pipeline.run(), [2, 3]);
      expect(surface.enrichTags, isNull);
      expect(surface.gateComments, isNull);
      expect(surface.recordExposure, isNull);
    });

    test('ShieldingRuntime.batch() 每批只读一次规则与设置', () async {
      var ruleCalls = 0;
      var configCalls = 0;
      final runtime = ShieldingRuntime(
        ruleSetProvider: () {
          ruleCalls++;
          return _ruleSet(rules: []);
        },
        configProvider: () {
          configCalls++;
          return RecommendationFilterConfig();
        },
      );

      final pipeline = RecommendationPipeline<int>(
        supplyBatch: runtime.batch,
        surface: RecommendationSurface<int>(judge: (item, batch) => true),
        candidateSource: (batch) => [1, 2, 3, 4, 5],
      );

      expect(await pipeline.run(), hasLength(5));
      expect(ruleCalls, 1);
      expect(configCalls, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 面的策略：首页 web / 首页 app 同构，热门与排行同链，相关视频独立
  // ---------------------------------------------------------------------------
  group('RecommendationSurfaces.homeFeed', () {
    test('命中屏蔽规则被丢弃，allow 规则优先', () {
      final entry = _entry('广告测试', bvid: 'BV1');
      final surface = RecommendationSurfaces.homeFeed<_TestVideo>();

      expect(
        surface.judge(
          entry,
          _batch(
            ruleSet: _ruleSet(
              rules: [_keywordRule('广告')],
            ),
          ),
        ),
        isFalse,
      );

      expect(
        surface.judge(
          entry,
          _batch(
            ruleSet: _ruleSet(
              rules: [
                _keywordRule('广告'),
                _keywordRule('广告', action: ShieldAction.allow),
              ],
            ),
          ),
        ),
        isTrue,
        reason: 'allow 规则命中时可见，与 ShieldMatcher 既有语义一致',
      );
    });

    test('已关注UP豁免只作用于旧派生指标链路', () {
      final surface = RecommendationSurfaces.homeFeed<_TestVideo>();
      final config = RecommendationFilterConfig(
        rcmdRegExp: RegExp('广告'),
        useLegacyTextFilter: true,
      );
      final ruleSet = _ruleSet(rules: []);

      expect(
        surface.judge(
          _entry('广告测试', isFollowed: false),
          _batch(ruleSet: ruleSet, config: config),
        ),
        isFalse,
      );
      expect(
        surface.judge(
          _entry('广告测试', isFollowed: true),
          _batch(ruleSet: ruleSet, config: config),
        ),
        isTrue,
        reason: '首页豁免：已关注UP 跳过旧派生指标过滤',
      );
    });

    test('推荐屏蔽总开关关闭时整面放行', () {
      final surface = RecommendationSurfaces.homeFeed<_TestVideo>();
      final config = RecommendationFilterConfig(
        rcmdRegExp: RegExp('广告'),
        useLegacyTextFilter: true,
      );

      expect(
        surface.judge(
          _entry('广告测试'),
          _batch(
            ruleSet: _ruleSet(
              rules: [_keywordRule('广告')],
              recommendationEnabled: false,
            ),
            config: config,
          ),
        ),
        isTrue,
      );
    });

    test('首页面带标签富集、评论门与曝光记录三个阶段', () {
      final surface = RecommendationSurfaces.homeFeed<_TestVideo>();

      expect(surface.enrichTags, isNotNull);
      expect(surface.gateComments, isNotNull);
      expect(surface.recordExposure, isNotNull);
    });
  });

  group('RecommendationSurfaces.hotAndRanking', () {
    test('按推荐作用域判定，全局开关关闭时整面放行', () {
      final surface = RecommendationSurfaces.hotAndRanking();

      expect(
        surface.judge(
          _hot('广告测试'),
          _batch(ruleSet: _ruleSet(rules: [_keywordRule('广告')])),
        ),
        isFalse,
      );
      expect(
        surface.judge(
          _hot('广告测试'),
          _batch(
            ruleSet: _ruleSet(
              rules: [_keywordRule('广告')],
              globalEnabled: false,
            ),
          ),
        ),
        isTrue,
      );
    });

    test('不受相关视频独立开关影响', () {
      final surface = RecommendationSurfaces.hotAndRanking();

      expect(
        surface.judge(
          _hot('广告测试'),
          _batch(
            ruleSet: _ruleSet(
              rules: [_keywordRule('广告')],
              relatedVideoEnabled: false,
            ),
          ),
        ),
        isFalse,
      );
    });

    test('热门面没有命中后行为', () {
      final surface = RecommendationSurfaces.hotAndRanking();

      expect(surface.enrichTags, isNull);
      expect(surface.gateComments, isNull);
      expect(surface.recordExposure, isNull);
    });
  });

  group('RecommendationSurfaces.relatedVideos', () {
    test('候选用 videoDetail 作用域，独立开关决定是否生效', () {
      final surface = RecommendationSurfaces.relatedVideos();

      expect(
        surface.judge(
          _hot('广告测试'),
          _batch(
            ruleSet: _ruleSet(
              rules: [_keywordRule('广告', scope: ShieldScope.videoDetail)],
            ),
          ),
        ),
        isFalse,
        reason: 'relatedVideoEnabled 默认 true 时 videoDetail 规则生效',
      );
      expect(
        surface.judge(
          _hot('广告测试'),
          _batch(
            ruleSet: _ruleSet(
              rules: [_keywordRule('广告', scope: ShieldScope.videoDetail)],
              relatedVideoEnabled: false,
            ),
          ),
        ),
        isTrue,
        reason: '相关视频独立开关关闭时规则不生效',
      );
    });

    test('仅 videoDetail 规则作用于相关视频，推荐规则不作用于相关视频', () {
      final videoDetailRule = _keywordRule(
        '广告',
        scope: ShieldScope.videoDetail,
      );
      final batch = _batch(ruleSet: _ruleSet(rules: [videoDetailRule]));

      expect(
        RecommendationSurfaces.relatedVideos().judge(_hot('广告测试'), batch),
        isFalse,
      );
      expect(
        RecommendationSurfaces.hotAndRanking().judge(_hot('广告测试'), batch),
        isTrue,
      );
    });

    test('取列表：开关关闭时原样返回', () {
      final items = [_hot('正常', duration: 30), _hot('正常', duration: 600)];
      final batch = _batch(
        config: RecommendationFilterConfig(
          minDurationForRcmd: 60,
          applyFilterToRelatedVideos: false,
        ),
      );

      expect(
        identical(
          RecommendationSurfaces.relatedVideoCandidates(items, batch),
          items,
        ),
        isTrue,
      );
    });

    test('取列表：开关开启时按旧派生指标前置过滤', () {
      final batch = _batch(
        config: RecommendationFilterConfig(
          minDurationForRcmd: 60,
          applyFilterToRelatedVideos: true,
        ),
      );

      final items = [
        _hot('太短', duration: 30),
        _hot('正常', duration: 600),
      ];
      final kept = RecommendationSurfaces.relatedVideoCandidates(items, batch);
      expect(kept.map((item) => item.title), ['正常']);

      final lowLikeBatch = _batch(
        config: RecommendationFilterConfig(
          minLikeRatioForRecommend: 2,
          applyFilterToRelatedVideos: true,
        ),
      );
      expect(
        RecommendationSurfaces.relatedVideoCandidates(
          [_hot('低点赞率', duration: 600, view: 1000, like: 5)],
          lowLikeBatch,
        ),
        isEmpty,
      );
      expect(
        RecommendationSurfaces.relatedVideoCandidates(
          [_hot('正常点赞率', duration: 600, view: 1000, like: 50)],
          lowLikeBatch,
        ),
        hasLength(1),
      );
    });
  });

  group('五个面的空列表', () {
    test('热门/相关视频面空列表返回空', () async {
      for (final surface in [
        RecommendationSurfaces.hotAndRanking(),
        RecommendationSurfaces.relatedVideos(),
      ]) {
        final pipeline = RecommendationPipeline<HotVideoItemModel>(
          supplyBatch: _batch,
          surface: surface,
          candidateSource: (batch) => const [],
        );
        expect(await pipeline.run(), isEmpty);
      }
    });

    test('首页面空列表返回空（判定从未被调用）', () async {
      var judgeCalls = 0;
      final surface = RecommendationSurfaces.homeFeed<_TestVideo>();
      final pipeline =
          RecommendationPipeline<RecommendationFeedEntry<_TestVideo>>(
            supplyBatch: _batch,
            surface: RecommendationSurface<RecommendationFeedEntry<_TestVideo>>(
              judge: (entry, batch) {
                judgeCalls++;
                return surface.judge(entry, batch);
              },
            ),
            candidateSource: (batch) => const [],
          );

      expect(await pipeline.run(), isEmpty);
      expect(judgeCalls, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // 规则提供者的单一注入口 + 旧入口转发
  // ---------------------------------------------------------------------------
  group('ShieldingRuntime 注入点', () {
    test('实例 provider 优先于静态槽位', () {
      final fromSlot = _ruleSet(rules: []);
      final fromInstance = _ruleSet(rules: [_keywordRule('x')]);
      ShieldingRuntime.shieldRuleSetProvider = () => fromSlot;

      expect(identical(ShieldingRuntime.instance.ruleSet(), fromSlot), isTrue);
      expect(
        identical(
          ShieldingRuntime(ruleSetProvider: () => fromInstance).ruleSet(),
          fromInstance,
        ),
        isTrue,
      );
    });

    test('RecommendFilter 与 ReplyGrpc 的 shieldRuleSetProvider 转发到同一槽位', () {
      ShieldRuleSet provider() => _ruleSet(rules: []);

      RecommendFilter.shieldRuleSetProvider = provider;

      expect(
        identical(ShieldingRuntime.shieldRuleSetProvider, provider),
        isTrue,
      );
      expect(identical(ReplyGrpc.shieldRuleSetProvider, provider), isTrue);

      RecommendFilter.shieldRuleSetProvider = null;
      expect(ShieldingRuntime.shieldRuleSetProvider, isNull);
      expect(ReplyGrpc.shieldRuleSetProvider, isNull);
    });

    test('updateSettings 写入内存镜像并带进 toConfig()', () {
      RecommendFilter.updateSettings(
        filterInteractionRateForRecommend: true,
        minInteractionRateForRecommend: 4.5,
        exemptFilterForFollowed: false,
        applyFilterToRelatedVideos: false,
      );

      final config = RecommendFilter.toConfig();
      expect(config.filterInteractionRateForRecommend, isTrue);
      expect(config.minInteractionRateForRecommend, 4.5);
      expect(config.exemptFilterForFollowed, isFalse);
      expect(config.applyFilterToRelatedVideos, isFalse);
      // 未点名的设置保持原值
      expect(config.minTripleRateForRecommend, 3.0);
    });
  });
}

// -----------------------------------------------------------------------------
// fixtures
// -----------------------------------------------------------------------------

RecommendationBatch _batch({
  ShieldRuleSet? ruleSet,
  RecommendationFilterConfig? config,
}) => RecommendationBatch(
  ruleSet: ruleSet ?? _ruleSet(rules: []),
  config: config ?? RecommendationFilterConfig(),
);

ShieldRuleSet _ruleSet({
  required List<ShieldRule> rules,
  bool globalEnabled = true,
  bool recommendationEnabled = true,
  bool relatedVideoEnabled = true,
}) => ShieldRuleSet(
  rules: rules,
  globalEnabled: globalEnabled,
  recommendationEnabled: recommendationEnabled,
  relatedVideoEnabled: relatedVideoEnabled,
);

ShieldRule _keywordRule(
  String pattern, {
  ShieldScope scope = ShieldScope.recommendation,
  ShieldAction action = ShieldAction.block,
}) => ShieldRule(
  id: 'test-$scope-$action-$pattern',
  type: ShieldRuleType.keyword,
  matchMode: ShieldMatchMode.contains,
  scope: scope,
  action: action,
  pattern: pattern,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
);

RecommendationFeedEntry<_TestVideo> _entry(
  String title, {
  String? bvid,
  bool isFollowed = false,
}) {
  final video = _TestVideo(title: title, bvid: bvid, isFollowed: isFollowed);
  return RecommendationFeedEntry(
    item: video,
    candidate: ShieldCandidate(
      scope: ShieldScope.recommendation,
      title: title,
      uid: '42',
    ),
  );
}

HotVideoItemModel _hot(
  String title, {
  int duration = 600,
  int view = 1000,
  int like = 50,
}) => HotVideoItemModel.fromJson({
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
  'duration': duration,
  'owner': {'mid': 42, 'name': '玩家UP'},
  'stat': {'view': view, 'like': like, 'danmaku': 1},
});

class _TestVideo extends BaseVideoItemModel {
  _TestVideo({
    String title = 'test video',
    String? bvid,
    bool isFollowed = false,
  }) {
    this.title = title;
    this.bvid = bvid;
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

/// 旧兼容 shim 的静态量是全局的，测试之间必须复位。
void _resetLegacyShim() {
  RecommendFilter.updateSettings(
    minDurationForRcmd: 0,
    minPlayForRcmd: 0,
    minLikeRatioForRecommend: 0,
    filterInteractionRateForRecommend: false,
    minInteractionRateForRecommend: 1.0,
    filterTripleRateForRecommend: false,
    minTripleRateForRecommend: 3.0,
    filterContentValueForRecommend: false,
    minContentValueForRecommend: 10.0,
    exemptFilterForFollowed: true,
    applyFilterToRelatedVideos: true,
  );
  RecommendFilter.rcmdRegExp = RegExp('', caseSensitive: false);
  RecommendFilter.enableFilter = false;
  RecommendFilter.useLegacyTextFilter = false;
  RecommendFilter.shieldRuleSetProvider = null;
}
