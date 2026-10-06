import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/features/shielding/home_feed_comment_gate.dart';
import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/grpc/bilibili/pagination.pb.dart';
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// 开关打开，且短评论不算「可见评论」——评论门真的会做判定。
const _guardOn = CommentShieldingConfig(
  hideHomeFeedItemsWithoutVisibleComments: true,
  minCharCount: 3,
);

/// 开关默认关闭。
const _guardOff = CommentShieldingConfig();

/// 一条能把候选留下来的评论。
LoadingState<MainListReply> _visible() =>
    Success(MainListReply(replies: [_reply('visible comment')]));

void main() {
  late Directory directory;

  setUpAll(() async {
    // 策略键里含 ReplyGrpc 的过滤开关，而这些静态量首次读取时会去取本地设置；
    // 准备方式与 test/features/shielding/upstream_reply_selection_test.dart 一致。
    directory = await Directory.systemTemp.createTemp('comment_gate_test_');
    Hive.init(directory.path);
    GStorage.setting = await Hive.openBox('setting');
    GStorage.localCache = await Hive.openBox('localCache');
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  setUp(() {
    HomeFeedCommentGate.resetDecisionCache();
    HomeFeedCommentGate.decisionCacheClock = DateTime.now;
  });

  group('HomeFeedCommentGate', () {
    test(
      'switch off leaves items unchanged and does not fetch comments',
      () async {
        var calls = 0;

        final result = await HomeFeedCommentGate.filter<int>(
          [1, 2],
          config: const CommentShieldingConfig(),
          ruleSet: ShieldRuleSet(),
          getAid: (item) => item,
          loader:
              ({
                required oid,
                required type,
                required mode,
                required offset,
                required cursorNext,
              }) async {
                calls++;
                return Success(MainListReply());
              },
        );

        expect(result, [1, 2]);
        expect(calls, 0);
      },
    );

    test(
      'switch on keeps item when at least one checked comment is visible',
      () async {
        final result = await HomeFeedCommentGate.filter<int>(
          [1],
          config: const CommentShieldingConfig(
            hideHomeFeedItemsWithoutVisibleComments: true,
            minCharCount: 3,
          ),
          ruleSet: ShieldRuleSet(),
          getAid: (item) => item,
          loader:
              ({
                required oid,
                required type,
                required mode,
                required offset,
                required cursorNext,
              }) async => Success(
                MainListReply(replies: [_reply('visible comment')]),
              ),
        );

        expect(result, [1]);
      },
    );

    test(
      'switch on hides item when all checked comments are cleaned',
      () async {
        final result = await HomeFeedCommentGate.filter<int>(
          [1],
          config: const CommentShieldingConfig(
            hideHomeFeedItemsWithoutVisibleComments: true,
          ),
          ruleSet: ShieldRuleSet(
            rules: [
              ShieldRule(
                id: 'comment-keyword',
                type: ShieldRuleType.keyword,
                matchMode: ShieldMatchMode.exact,
                scope: ShieldScope.comment,
                action: ShieldAction.block,
                pattern: 'hidden',
                updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
              ),
            ],
          ),
          getAid: (item) => item,
          loader:
              ({
                required oid,
                required type,
                required mode,
                required offset,
                required cursorNext,
              }) async => Success(MainListReply(replies: [_reply('hidden')])),
        );

        expect(result, isEmpty);
      },
    );

    test('comment request failure fails open', () async {
      final result = await HomeFeedCommentGate.filter<int>(
        [1],
        config: const CommentShieldingConfig(
          hideHomeFeedItemsWithoutVisibleComments: true,
        ),
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader:
            ({
              required oid,
              required type,
              required mode,
              required offset,
              required cursorNext,
            }) async => const Error('permission denied'),
      );

      expect(result, [1]);
    });

    test('non-exhausted checked comments fail open', () async {
      final result = await HomeFeedCommentGate.filter<int>(
        [1],
        config: const CommentShieldingConfig(
          hideHomeFeedItemsWithoutVisibleComments: true,
          minCharCount: 100,
        ),
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader:
            ({
              required oid,
              required type,
              required mode,
              required offset,
              required cursorNext,
            }) async => Success(
              MainListReply(
                replies: [_reply('short')],
                paginationReply: FeedPaginationReply(nextOffset: 'more'),
              ),
            ),
      );

      expect(result, [1]);
    });

    test('keeps candidates without a usable aid and asks nothing for them', () async {
      final requested = <int>[];
      final items = <int?>[null, 0, -3, 9];

      final result = await HomeFeedCommentGate.filter<int?>(
        items,
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(requested, (oid) async => _visible()),
      );

      expect(result, items);
      expect(requested, [9]);
    });

    // 票面「要恢复的设计 2)」：固定分批屏障 → 3 个持续补位 worker。
    test('a slow check does not hold later candidates back', () async {
      final slow = Completer<LoadingState<MainListReply>>();
      final requested = <int>[];
      var active = 0;
      var peak = 0;

      final future = HomeFeedCommentGate.filter<int>(
        [1, 2, 3, 4, 5],
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(requested, (oid) {
          active++;
          if (active > peak) peak = active;
          final response = oid == 1 ? slow.future : Future.value(_visible());
          return response.whenComplete(() => active--);
        }),
      );

      await _settle();

      // 1 号还挂着，后面的候选已经占了让出来的槽位（固定分批这时只会发 3 条）。
      expect(slow.isCompleted, isFalse);
      expect(requested, [1, 2, 3, 4, 5]);
      expect(peak, HomeFeedCommentGate.defaultMaxConcurrent);

      slow.complete(_visible());
      expect(await future, [1, 2, 3, 4, 5]);
      expect(peak, HomeFeedCommentGate.defaultMaxConcurrent);
    });

    test('never runs more than maxConcurrent checks at once', () async {
      final gates = <int, Completer<LoadingState<MainListReply>>>{};
      final requested = <int>[];
      var active = 0;
      var peak = 0;

      final future = HomeFeedCommentGate.filter<int>(
        [for (var aid = 1; aid <= 8; aid++) aid],
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(requested, (oid) {
          active++;
          if (active > peak) peak = active;
          final gate = gates.putIfAbsent(oid, Completer.new);
          return gate.future.whenComplete(() => active--);
        }),
      );

      await _settle();
      // 8 条候选、3 个槽位：先起 3 条，剩下的排队等着补位。
      expect(requested, [1, 2, 3]);
      expect(active, 3);
      expect(peak, 3);

      // 一条条放行：每放行一条才补一条，在飞数始终不越界。
      for (var aid = 1; aid <= 8; aid++) {
        gates[aid]!.complete(_visible());
        await _settle();
        expect(active, lessThanOrEqualTo(3));
      }
      expect(await future, hasLength(8));
      expect(requested, hasLength(8));
      expect(peak, 3);
    });

    // 票面「要恢复的设计 3)」：同 aid in-flight 合并。
    test('merges duplicate aids of one page into a single check', () async {
      final requested = <int>[];

      final result = await HomeFeedCommentGate.filter<int>(
        [7, 7, 7],
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(requested, (oid) async => _visible()),
      );

      expect(result, [7, 7, 7]);
      expect(requested, [7]);
    });

    test('merges a check that is still in flight across pages', () async {
      final gate = Completer<LoadingState<MainListReply>>();
      final requested = <int>[];

      final first = HomeFeedCommentGate.filter<int>(
        [7],
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(requested, (oid) => gate.future),
      );
      final second = HomeFeedCommentGate.filter<int>(
        [7],
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(requested, (oid) => gate.future),
      );

      await _settle();
      expect(requested, [7]);

      gate.complete(_visible());
      expect(await first, [7]);
      expect(await second, [7]);
      expect(requested, [7]);
    });

    // 票面「要恢复的设计 4)」：成功判定缓存。
    test('reuses a cached decision instead of asking again', () async {
      final requested = <int>[];

      final first = await HomeFeedCommentGate.filter<int>(
        [7],
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(requested, (oid) async => _visible()),
      );
      final second = await HomeFeedCommentGate.filter<int>(
        [7],
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(requested, (oid) async => _visible()),
      );

      expect(first, [7]);
      expect(second, [7]);
      expect(requested, [7]);
      expect(HomeFeedCommentGate.decisionCacheEntryCount, 1);

      // 缓存按 aid 分条目：换一个 aid 仍要问一次。
      await HomeFeedCommentGate.filter<int>(
        [8],
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(requested, (oid) async => _visible()),
      );
      expect(requested, [7, 8]);
      expect(HomeFeedCommentGate.decisionCacheEntryCount, 2);
    });

    test('a hidden decision is cached too', () async {
      final requested = <int>[];

      final blocked = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'comment-keyword',
            type: ShieldRuleType.keyword,
            matchMode: ShieldMatchMode.exact,
            scope: ShieldScope.comment,
            action: ShieldAction.block,
            pattern: 'hidden',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );
      Future<List<int>> run() => HomeFeedCommentGate.filter<int>(
        [7],
        config: _guardOn,
        ruleSet: blocked,
        getAid: (item) => item,
        loader: _counting(
          requested,
          (oid) async => Success(MainListReply(replies: [_reply('hidden')])),
        ),
      );

      expect(await run(), isEmpty);
      expect(await run(), isEmpty);
      expect(requested, [7]);
    });

    test('expires a cached decision after ttl', () async {
      var now = DateTime(2026, 10, 6, 12);
      HomeFeedCommentGate.decisionCacheClock = () => now;
      final requested = <int>[];

      Future<List<int>> run() => HomeFeedCommentGate.filter<int>(
        [7],
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(requested, (oid) async => _visible()),
      );

      await run();
      now = now.add(
        HomeFeedCommentGate.decisionCacheTtl - const Duration(seconds: 1),
      );
      await run();
      expect(requested, [7]);
      expect(HomeFeedCommentGate.decisionCacheEntryCount, 1);

      now = now.add(const Duration(seconds: 2));
      expect(HomeFeedCommentGate.decisionCacheEntryCount, 0);
      await run();
      expect(requested, [7, 7]);
    });

    test('caps the decision cache and drops the oldest decisions', () async {
      final requested = <int>[];
      final ids = [
        for (var aid = 1; aid <= HomeFeedCommentGate.decisionCacheMaxEntries + 4; aid++)
          aid,
      ];

      Future<List<int>> run(List<int> items) => HomeFeedCommentGate.filter<int>(
        items,
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(requested, (oid) async => _visible()),
      );

      expect(await run(ids), ids);
      expect(requested, ids);
      expect(
        HomeFeedCommentGate.decisionCacheEntryCount,
        HomeFeedCommentGate.decisionCacheMaxEntries,
      );

      // 最新写入的几条还在缓存里：同一页里的判定不该再发请求。
      final warm = requested.length;
      expect(await run([ids.last, ids.last - 1]), [ids.last, ids.last - 1]);
      expect(requested.length, warm);
      expect(
        HomeFeedCommentGate.decisionCacheEntryCount,
        HomeFeedCommentGate.decisionCacheMaxEntries,
      );

      // 最早写入的那条已经被挤掉（写满之后每次写入都先丢最早的一条）：重新发请求。
      expect(await run([ids.first]), [ids.first]);
      expect(requested.length, warm + 1);
      expect(
        HomeFeedCommentGate.decisionCacheEntryCount,
        HomeFeedCommentGate.decisionCacheMaxEntries,
      );
    });

    // 票面「边界」：规则/配置/过滤开关一变，判定缓存就不能再复用。
    test('a changed comment config invalidates the cache', () async {
      final requested = <int>[];

      await HomeFeedCommentGate.filter<int>(
        [7],
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(requested, (oid) async => _visible()),
      );
      await HomeFeedCommentGate.filter<int>(
        [7],
        config: _guardOn.copyWith(maxCharCount: 50),
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(requested, (oid) async => _visible()),
      );

      expect(requested, [7, 7]);
    });

    test('a newly added shield rule takes effect immediately', () async {
      final requested = <int>[];
      final rule = ShieldRule(
        id: 'comment-keyword',
        type: ShieldRuleType.keyword,
        matchMode: ShieldMatchMode.exact,
        scope: ShieldScope.comment,
        action: ShieldAction.block,
        pattern: 'hidden',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
      );

      Future<List<int>> run(ShieldRuleSet ruleSet) =>
          HomeFeedCommentGate.filter<int>(
            [7],
            config: _guardOn,
            ruleSet: ruleSet,
            getAid: (item) => item,
            loader: _counting(
              requested,
              (oid) async => Success(MainListReply(replies: [_reply('hidden')])),
            ),
          );

      expect(await run(ShieldRuleSet()), [7]);
      // 上一条判定还在 30 秒内存活期里，但规则变了 —— 新规则必须立刻生效。
      expect(await run(ShieldRuleSet(rules: [rule])), isEmpty);
      expect(await run(ShieldRuleSet(rules: [rule])), isEmpty);
      expect(requested, [7, 7]);
    });

    test('a changed ReplyGrpc filter switch invalidates the cache', () async {
      final requested = <int>[];
      final original = ReplyGrpc.antiGoodsReply;
      addTearDown(() => ReplyGrpc.antiGoodsReply = original);

      Future<List<int>> run() => HomeFeedCommentGate.filter<int>(
        [7],
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(requested, (oid) async => _visible()),
      );

      ReplyGrpc.antiGoodsReply = original;
      await run();
      ReplyGrpc.antiGoodsReply = !original;
      await run();

      expect(requested, [7, 7]);

      ReplyGrpc.antiGoodsReply = original;
      await run();
      expect(requested, [7, 7, 7]);
    });

    // 票面「要恢复的设计 5)」：失败与超时不进缓存，下次仍会重试。
    test('a failed check is not cached and is retried', () async {
      final requested = <int>[];
      var fail = true;

      Future<List<int>> run() => HomeFeedCommentGate.filter<int>(
        [7],
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(
          requested,
          (oid) async =>
              fail ? const Error('permission denied') : _visible(),
        ),
      );

      expect(await run(), [7]);
      expect(HomeFeedCommentGate.decisionCacheEntryCount, 0);

      fail = false;
      expect(await run(), [7]);
      expect(requested, [7, 7]);
      expect(HomeFeedCommentGate.decisionCacheEntryCount, 1);
    });

    test('a timed out check is not cached and is retried', () async {
      final requested = <int>[];
      const timeout = Duration(milliseconds: 20);

      Future<List<int>> run() => HomeFeedCommentGate.filter<int>(
        [7],
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        timeout: timeout,
        // 永远不回答：只能等到超时。
        loader: _counting(requested, (oid) => Completer<LoadingState<MainListReply>>().future),
      );

      expect(await run(), [7]);
      expect(HomeFeedCommentGate.decisionCacheEntryCount, 0);
      expect(await run(), [7]);
      expect(requested, [7, 7]);

      // 开关关掉时连缓存都不看：零请求。
      expect(
        await HomeFeedCommentGate.filter<int>(
          [7],
          config: _guardOff,
          ruleSet: ShieldRuleSet(),
          getAid: (item) => item,
          loader: _counting(requested, (oid) => Completer<LoadingState<MainListReply>>().future),
        ),
        [7],
      );
      expect(requested, [7, 7]);
    });

    // 票面「验收 1)」的受控场景，把结构性差异放大到 100ms 量级以免受墙钟抖动影响：
    // 1 条 600ms + 4 条 200ms，3 个槽位。固定分批要两轮 600+200=800ms；持续补位只等
    // 最慢的那一条 ≈600ms。取 700ms 作分界，两侧各留 ~100ms 余量。
    test('controlled scenario: one slow check does not serialize the page', () async {
      const slow = Duration(milliseconds: 600);
      const fast = Duration(milliseconds: 200);
      final requested = <int>[];
      var active = 0;
      var peak = 0;

      final watch = Stopwatch()..start();
      final result = await HomeFeedCommentGate.filter<int>(
        [1, 2, 3, 4, 5],
        config: _guardOn,
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: _counting(requested, (oid) async {
          active++;
          if (active > peak) peak = active;
          try {
            await Future.delayed(oid == 1 ? slow : fast);
            return _visible();
          } finally {
            active--;
          }
        }),
      );
      watch.stop();

      expect(result, [1, 2, 3, 4, 5]);
      expect(requested, [1, 2, 3, 4, 5]);
      expect(peak, 3);
      expect(
        watch.elapsed,
        lessThan(slow + fast - const Duration(milliseconds: 100)),
      );
    });
  });
}

/// 计数的 loader：把每次请求的 aid 记进 [requested]，回答交给 [respond]。
HomeFeedCommentLoader _counting(
  List<int> requested,
  Future<LoadingState<MainListReply>> Function(int oid) respond,
) => ({
  required oid,
  required type,
  required mode,
  required offset,
  required cursorNext,
}) {
  requested.add(oid);
  return respond(oid);
};

/// 让出事件循环若干轮，把已排队的 microtask 与零延时定时器都跑完。
Future<void> _settle() async {
  for (var round = 0; round < 3; round++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ReplyInfo _reply(String message) => ReplyInfo(
  mid: Int64(42),
  member: Member(mid: Int64(42), name: 'user'),
  content: Content(message: message),
);
