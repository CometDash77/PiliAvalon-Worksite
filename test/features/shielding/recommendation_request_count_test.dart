import 'dart:io';

import 'package:PiliPlus/features/shielding/home_feed_comment_gate.dart';
import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/shielding/recommendation_tag_store.dart';
import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/features/shielding/shielding_recommend_tag_enricher.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/models_new/video/video_tag/data.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'package:hive_ce/hive.dart';

// -----------------------------------------------------------------------------
// ticket #79（map #47）：每页上游请求数 量具
//
// 量的是什么：首页推荐面跑「一页」时打出去的**上游请求个数**（标签 + 评论），
// 以及这发生在跨页重复候选上的变化。
//
// 量具诚实边界（读的时候请连同这一段一起读）：
// 1. 驱动的全是已入库产品类：RecommendationPipeline、
//    RecommendationSurfaces.homeFeed 的 judge / gateComments 闭包、
//    RecommendationTagEnricher + RecommendationTagStore、HomeFeedCommentGate。
// 2. 唯二被替换的是两个**传输端点**：标签的 fetchTags、评论门的 loader。
//    不换掉它们就量不到——产品装配处（recommendation_surfaces.dart:42/:48）
//    走的是 defaultVideoTagFetch 与 _defaultLoader 的真实网络。
// 3. 取列表这一次请求不经过本量具（它发生在 lib/http/video.dart 的调用点），
//    因此表里按构造记为固定 1 次/页，并在标题里注明。
// 4. 曝光记录阶段不发上游请求；且它要 GStorage.exposureTracker 箱（测试里未开），
//    对请求数无影响，故本量具不装配它。
// -----------------------------------------------------------------------------

/// 开关打开，且短评论不算「可见评论」——评论门真的会做判定。
const _guardOn = CommentShieldingConfig(
  hideHomeFeedItemsWithoutVisibleComments: true,
  minCharCount: 3,
);

/// 一页 20 条候选，与 #48 记录的历史基线样本量一致。
const _pageSize = 20;

/// 一条能把候选留下来的评论。
LoadingState<MainListReply> _visible() =>
    Success(MainListReply(replies: [_reply('visible comment')]));

ReplyInfo _reply(String message) => ReplyInfo(
  mid: Int64(42),
  member: Member(mid: Int64(42), name: 'user'),
  content: Content(message: message),
);

/// 计数的标签取数：一次调用 = 一次上游请求，按 `bvid|cid` 记录。
class _CountingTagFetcher {
  int requests = 0;
  final List<String> keyLog = [];

  Future<LoadingState<List<VideoTagItem>?>> call(
    String bvid,
    Object? cid,
  ) async {
    requests++;
    keyLog.add(RecommendationTagStore.cacheKey(bvid, cid));
    // 标签本身不触发屏蔽：本量具量请求数，不量命中率。
    return Success(<VideoTagItem>[VideoTagItem(tagName: 'tag-$bvid')]);
  }
}

/// 计数的评论 loader：一次调用 = 一次上游请求，按 aid 记录。
class _CountingCommentLoader {
  final List<int> requested = [];

  /// 推断参数类型的闭包，与 test/features/shielding/home_feed_comment_gate_test.dart:631 的
  /// _counting 同一写法：Loader 具名参数的具体类型由 typedef 决定。
  HomeFeedCommentLoader get asLoader =>
      ({
        required oid,
        required type,
        required mode,
        required offset,
        required cursorNext,
      }) async {
        requested.add(oid);
        return _visible();
      };
}

class _TestVideo extends BaseVideoItemModel {
  _TestVideo(int index) {
    title = 'video $index';
    bvid = 'BV$index';
    cid = 1000 + index;
    aid = 9000 + index;
    duration = 600;
    owner = _TestOwner();
    stat = _TestStat();
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

RecommendationFeedEntry<_TestVideo> _entry(int index) =>
    RecommendationFeedEntry(
      item: _TestVideo(index),
      candidate: ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: 'video $index',
        uid: '42',
      ),
    );

RecommendationBatch _batch() => RecommendationBatch(
  ruleSet: ShieldRuleSet(
    rules: const [],
    globalEnabled: true,
    recommendationEnabled: true,
    relatedVideoEnabled: true,
  ),
  config: RecommendationFilterConfig(),
);

/// 首页面的装配：judge 与 gateComments 直接取产品闭包，只把两个传输端点换成计次假件。
RecommendationSurface<RecommendationFeedEntry<_TestVideo>> _homeFeedSurface({
  required _CountingTagFetcher tagFetcher,
  required _CountingCommentLoader commentLoader,
}) {
  final production = RecommendationSurfaces.homeFeed<_TestVideo>(
    jevSurface: JevSurface.homeWeb,
  );
  return RecommendationSurface<RecommendationFeedEntry<_TestVideo>>(
    judge: production.judge,
    enrichTags: (entries, batch) =>
        RecommendationTagEnricher(
          fetchTags: tagFetcher.call,
        ).enrichAndFilter(
          entries,
          batch.ruleSet,
          getBvid: (entry) => entry.item.bvid,
          getCid: (entry) => entry.item.cid,
        ),
    gateComments: (entries, batch) => HomeFeedCommentGate.filter(
      entries,
      config: _guardOn,
      ruleSet: batch.ruleSet,
      getAid: (entry) => entry.item.aid,
      loader: commentLoader.asLoader,
    ),
  );
}

class _PageResult {
  const _PageResult(this.survivors, this.tagRequests, this.commentRequests);

  final int survivors;
  final int tagRequests;
  final int commentRequests;

  /// 上游请求数 = 取列表 1（构造常数，不经本量具）+ 标签 + 评论。
  int get upstream => tagRequests + commentRequests;
}

/// 清掉进程级共享缓存。在量具里它是「口径」开关、不是产品行为：
/// 口径 A（#74/#75 落地前）每页都清一次，口径 B（当前 production）整段只清一次。
void _clearSharedCaches() {
  RecommendationTagEnricher.resetCache();
  HomeFeedCommentGate.resetDecisionCache();
}

Future<_PageResult> _runPage({
  required List<RecommendationFeedEntry<_TestVideo>> candidates,
  required _CountingTagFetcher tagFetcher,
  required _CountingCommentLoader commentLoader,
}) async {
  final tagBefore = tagFetcher.requests;
  final commentBefore = commentLoader.requested.length;

  final kept =
      await RecommendationPipeline<RecommendationFeedEntry<_TestVideo>>(
        supplyBatch: _batch,
        surface: _homeFeedSurface(
          tagFetcher: tagFetcher,
          commentLoader: commentLoader,
        ),
        candidateSource: (batch) => candidates,
      ).run();

  return _PageResult(
    kept.length,
    tagFetcher.requests - tagBefore,
    commentLoader.requested.length - commentBefore,
  );
}

/// 第 2 页：前 `repeats` 条与第 1 页重复（同一 bvid|cid|aid），其余为新候选。
List<RecommendationFeedEntry<_TestVideo>> _pageTwo(
  List<RecommendationFeedEntry<_TestVideo>> pageOne,
  int repeats,
) => [
  ...pageOne.take(repeats),
  for (var i = 0; i < _pageSize - repeats; i++) _entry(1000 + i),
];

void main() {
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('request_count_test_');
    Hive.init(directory.path);
    GStorage.setting = await Hive.openBox('setting');
    GStorage.localCache = await Hive.openBox('localCache');
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  setUp(() {
    RecommendationTagEnricher.resetCache();
    HomeFeedCommentGate.resetDecisionCache();
    HomeFeedCommentGate.decisionCacheClock = DateTime.now;
  });

  group('每页上游请求数（量具）', () {
    test('冷缓存一页：对齐 #48 记录的历史基线（标签 20/页、评论 20/页）', () async {
      final tagFetcher = _CountingTagFetcher();
      final commentLoader = _CountingCommentLoader();

      _clearSharedCaches();
      final page = await _runPage(
        candidates: [for (var i = 0; i < _pageSize; i++) _entry(i)],
        tagFetcher: tagFetcher,
        commentLoader: commentLoader,
      );

      // 判定没砍掉候选：这一页的请求数才有代表性。
      expect(page.survivors, _pageSize);
      expect(
        page.tagRequests,
        _pageSize,
        reason: '与 #48 记录的历史基线一致：每个候选一次标签请求',
      );
      expect(
        page.commentRequests,
        _pageSize,
        reason: '与 #48 记录的历史基线一致：每个存活候选一次评论请求',
      );
      expect(page.upstream, 2 * _pageSize);
    });

    test('跨页重复率扫描：逐页清缓存 vs 缓存存活（当前 production）', () async {
      final lines = <String>[
        '| 第 2 页重复率 | 口径 | 第 1 页 标签/评论 | 第 2 页 标签/评论 | 第 2 页上游请求数(+1 取列表) |',
        '| --- | --- | --- | --- | --- |',
      ];

      for (final percent in const [0, 25, 50, 75, 100]) {
        final repeats = _pageSize * percent ~/ 100;
        final pageOne = [for (var i = 0; i < _pageSize; i++) _entry(i)];
        final pageTwo = _pageTwo(pageOne, repeats);

        for (final clearEachPage in const [true, false]) {
          final tagFetcher = _CountingTagFetcher();
          final commentLoader = _CountingCommentLoader();

          // 每个口径都从冷缓存起步（第 1 页按定义是冷的）；口径 A 在换页时再清一次。
          _clearSharedCaches();
          final first = await _runPage(
            candidates: pageOne,
            tagFetcher: tagFetcher,
            commentLoader: commentLoader,
          );
          if (clearEachPage) _clearSharedCaches();
          final second = await _runPage(
            candidates: pageTwo,
            tagFetcher: tagFetcher,
            commentLoader: commentLoader,
          );

          expect(first.survivors, _pageSize);
          expect(second.survivors, _pageSize);

          if (clearEachPage) {
            // 口径 A：缓存被逐页清掉 = #74/#75 落地前「每页各自取数」的行为。
            // 两页的请求数与重复率无关，永远满额。
            expect(first.tagRequests, _pageSize);
            expect(first.commentRequests, _pageSize);
            expect(second.tagRequests, _pageSize);
            expect(second.commentRequests, _pageSize);
          } else {
            // 口径 B：缓存存活 = 当前 production 行为。重复候选不再打上游。
            final fresh = _pageSize - repeats;
            expect(second.tagRequests, fresh);
            expect(second.commentRequests, fresh);
          }

          lines.add(
            '| $percent% | ${clearEachPage ? 'A 逐页清缓存' : 'B 缓存存活'} | '
            '${first.tagRequests}/${first.commentRequests} | '
            '${second.tagRequests}/${second.commentRequests} | '
            '${second.upstream + 1} |',
          );
        }
      }

      // ignore: avoid_print
      print(
        '\n每页上游请求数（每页 $_pageSize 条候选；第 2 页重复率见首列）\n'
        '${lines.join('\n')}',
      );
    });

    test('缓存窗口边界：评论判定缓存 30s 过期后重新发请求', () async {
      // 判定缓存这一代在建立时就抓住了当时的 decisionCacheClock，所以注入的时钟
      // 必须在第一次运行之前装上，之后再拨快。
      var now = DateTime.now();
      HomeFeedCommentGate.decisionCacheClock = () => now;

      final tagFetcher = _CountingTagFetcher();
      final commentLoader = _CountingCommentLoader();
      final pageOne = [for (var i = 0; i < _pageSize; i++) _entry(i)];

      _clearSharedCaches();
      final first = await _runPage(
        candidates: pageOne,
        tagFetcher: tagFetcher,
        commentLoader: commentLoader,
      );
      expect(first.commentRequests, _pageSize);

      // 窗口内：同一页再走一遍，评论判定命中缓存。
      final warm = await _runPage(
        candidates: pageOne,
        tagFetcher: tagFetcher,
        commentLoader: commentLoader,
      );
      expect(warm.commentRequests, 0, reason: '30s 判定缓存窗口内不再打上游');
      expect(warm.tagRequests, 0, reason: '30min 成功缓存窗口内不再打上游');

      // 越过 30s：评论判定缓存过期，重新判定；标签成功缓存是 30min，仍在窗口内。
      now = now.add(
        HomeFeedCommentGate.decisionCacheTtl + const Duration(seconds: 1),
      );
      final expired = await _runPage(
        candidates: pageOne,
        tagFetcher: tagFetcher,
        commentLoader: commentLoader,
      );
      expect(expired.commentRequests, _pageSize, reason: '越过 30s 窗口后重新判定');
      expect(expired.tagRequests, 0, reason: '30min 标签成功缓存仍在窗口内');
    });

    test('其余推荐面没有每页上游请求阶段', () {
      // 结构断言：这三个面在产品的面定义里根本不挂标签/评论阶段。
      expect(
        RecommendationSurfaces.hotAndRanking(jevSurface: JevSurface.hot)
            .enrichTags,
        isNull,
      );
      expect(
        RecommendationSurfaces.hotAndRanking(jevSurface: JevSurface.hot)
            .gateComments,
        isNull,
      );
      expect(
        RecommendationSurfaces.relatedVideos(jevSurface: JevSurface.related)
            .enrichTags,
        isNull,
      );
      expect(
        RecommendationSurfaces.relatedVideos(jevSurface: JevSurface.related)
            .gateComments,
        isNull,
      );
      // 首页面则挂着两个阶段——差异就是每页请求数差异的来源。
      expect(
        RecommendationSurfaces.homeFeed<_TestVideo>(
          jevSurface: JevSurface.homeWeb,
        ).enrichTags,
        isNotNull,
      );
      expect(
        RecommendationSurfaces.homeFeed<_TestVideo>(
          jevSurface: JevSurface.homeWeb,
        ).gateComments,
        isNotNull,
      );
    });
  });
}
