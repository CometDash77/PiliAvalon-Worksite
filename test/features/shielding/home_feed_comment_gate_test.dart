import 'dart:async';

import 'package:PiliPlus/features/shielding/home_feed_comment_gate.dart';
import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/grpc/bilibili/pagination.pb.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/utils/recommendation_metrics.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeFeedCommentGate', () {
    setUp(() {
      HomeFeedCommentGate.resetCache();
      RecommendationMetrics.disable();
    });
    tearDown(RecommendationMetrics.disable);

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
          loader: ({
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

    test('switch on hides an exhausted item with no comments', () async {
      final result = await HomeFeedCommentGate.filter<int>(
        [1],
        config: const CommentShieldingConfig(
          hideHomeFeedItemsWithoutVisibleComments: true,
        ),
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: ({
          required oid,
          required type,
          required mode,
          required offset,
          required cursorNext,
        }) async => Success(MainListReply()),
      );

      expect(result, isEmpty);
    });

    test('empty but non-exhausted comments fail open', () async {
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
            }) async => Success(
              MainListReply(
                paginationReply: FeedPaginationReply(nextOffset: 'more'),
              ),
            ),
      );

      expect(result, [1]);
    });

    test('comment request failure fails open', () async {
      final result = await HomeFeedCommentGate.filter<int>(
        [1],
        config: const CommentShieldingConfig(
          hideHomeFeedItemsWithoutVisibleComments: true,
        ),
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader: ({
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

    test('duplicate aids in one page share one comment request', () async {
      var calls = 0;
      final result = await HomeFeedCommentGate.filter<String>(
        ['first', 'second'],
        config: const CommentShieldingConfig(
          hideHomeFeedItemsWithoutVisibleComments: true,
        ),
        ruleSet: ShieldRuleSet(),
        getAid: (_) => 7,
        loader:
            ({
              required oid,
              required type,
              required mode,
              required offset,
              required cursorNext,
            }) async {
              calls++;
              await Future<void>.delayed(const Duration(milliseconds: 10));
              return Success(MainListReply(replies: [_reply('visible')]));
            },
      );

      expect(result, ['first', 'second']);
      expect(calls, 1);
    });

    test(
      'successful decisions are cached but config and rule changes invalidate them',
      () async {
        var calls = 0;
        Future<LoadingState<MainListReply>> loader({
          required int oid,
          required int type,
          required Mode mode,
          required String? offset,
          required Int64? cursorNext,
        }) async {
          calls++;
          return Success(MainListReply(replies: [_reply('ok')]));
        }

        final visible = await HomeFeedCommentGate.filter<int>(
          [1],
          config: const CommentShieldingConfig(
            hideHomeFeedItemsWithoutVisibleComments: true,
            minCharCount: 2,
          ),
          ruleSet: ShieldRuleSet(),
          getAid: (_) => 11,
          loader: loader,
        );
        final hidden = await HomeFeedCommentGate.filter<int>(
          [1],
          config: const CommentShieldingConfig(
            hideHomeFeedItemsWithoutVisibleComments: true,
            minCharCount: 10,
          ),
          ruleSet: ShieldRuleSet(),
          getAid: (_) => 11,
          loader: loader,
        );
        final ruleSet = ShieldRuleSet(
          rules: [
            ShieldRule(
              id: 'comment-block',
              type: ShieldRuleType.keyword,
              matchMode: ShieldMatchMode.exact,
              scope: ShieldScope.comment,
              action: ShieldAction.block,
              pattern: 'ok',
              updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          ],
        );
        final hiddenByRule = await HomeFeedCommentGate.filter<int>(
          [1],
          config: const CommentShieldingConfig(
            hideHomeFeedItemsWithoutVisibleComments: true,
            minCharCount: 2,
          ),
          ruleSet: ruleSet,
          getAid: (_) => 11,
          loader: loader,
        );
        final stillHidden = await HomeFeedCommentGate.filter<int>(
          [1],
          config: const CommentShieldingConfig(
            hideHomeFeedItemsWithoutVisibleComments: true,
            minCharCount: 2,
          ),
          ruleSet: ruleSet,
          getAid: (_) => 11,
          loader: loader,
        );

        expect(visible, [1]);
        expect(hidden, isEmpty);
        expect(hiddenByRule, isEmpty);
        expect(stillHidden, isEmpty);
        expect(calls, 3);
      },
    );

    test(
      'worker pool starts a later request while an earlier one is pending',
      () async {
        final recorder = RecommendationMetricsRecorder();
        RecommendationMetrics.observer = recorder;
        final thirdStarted = Completer<void>();
        final resultFuture = HomeFeedCommentGate.filter<int>(
          [1, 2, 3],
          config: const CommentShieldingConfig(
            hideHomeFeedItemsWithoutVisibleComments: true,
          ),
          ruleSet: ShieldRuleSet(),
          getAid: (item) => item,
          maxConcurrent: 2,
          loader:
              ({
                required oid,
                required type,
                required mode,
                required offset,
                required cursorNext,
              }) {
                if (oid == 3) thirdStarted.complete();
                return Future.delayed(
                  Duration(milliseconds: oid == 1 ? 120 : 20),
                  () => Success(MainListReply(replies: [_reply('visible')])),
                );
              },
        );

        await thirdStarted.future.timeout(const Duration(seconds: 1));
        expect(await resultFuture, [1, 2, 3]);
        final gateTime =
            recorder.phases[RecommendationPhase.commentGate]!.single.elapsed;
        expect(gateTime, greaterThan(Duration.zero));
        // A fixed 2-request batch barrier would add the third 20ms request
        // after the 120ms request; the worker pool overlaps those intervals.
        RecommendationMetrics.disable();
      },
    );

    test('failed comment requests are not cached', () async {
      var calls = 0;
      Future<LoadingState<MainListReply>> loader({
        required int oid,
        required int type,
        required Mode mode,
        required String? offset,
        required Int64? cursorNext,
      }) {
        calls++;
        return Future.value(const Error('temporary failure'));
      }

      const config = CommentShieldingConfig(
        hideHomeFeedItemsWithoutVisibleComments: true,
      );

      for (var i = 0; i < 2; i++) {
        final result = await HomeFeedCommentGate.filter<int>(
          [1],
          config: config,
          ruleSet: ShieldRuleSet(),
          getAid: (_) => 12,
          loader: loader,
        );
        expect(result, [1]);
      }

      expect(calls, 2);
    });
  });
}

ReplyInfo _reply(String message) => ReplyInfo(
  mid: Int64(42),
  member: Member(mid: Int64(42), name: 'user'),
  content: Content(message: message),
);
