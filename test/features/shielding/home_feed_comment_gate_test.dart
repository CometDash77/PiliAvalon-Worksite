import 'package:PiliPlus/features/shielding/home_feed_comment_gate.dart';
import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/grpc/bilibili/pagination.pb.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  });
}

ReplyInfo _reply(String message) => ReplyInfo(
  mid: Int64(42),
  member: Member(mid: Int64(42), name: 'user'),
  content: Content(message: message),
);
