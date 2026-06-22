import 'dart:async';

import 'package:PiliPlus/features/shielding/comment_shielding_config.dart';
import 'package:PiliPlus/features/shielding/shielding_adapters.dart';
import 'package:PiliPlus/features/shielding/shielding_matcher.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:fixnum/fixnum.dart';

typedef HomeFeedCommentLoader =
    Future<LoadingState<MainListReply>> Function({
      required int oid,
      required int type,
      required Mode mode,
      required String? offset,
      required Int64? cursorNext,
    });

abstract final class HomeFeedCommentGate {
  static const int videoReplyType = 1;
  static const int defaultMaxConcurrent = 3;
  static const Duration defaultTimeout = Duration(seconds: 3);

  static Future<List<T>> filter<T>(
    List<T> items, {
    required CommentShieldingConfig config,
    required ShieldRuleSet ruleSet,
    required int? Function(T item) getAid,
    HomeFeedCommentLoader loader = _defaultLoader,
    int maxConcurrent = defaultMaxConcurrent,
    Duration timeout = defaultTimeout,
  }) async {
    if (!config.hideHomeFeedItemsWithoutVisibleComments || items.isEmpty) {
      return items;
    }

    final visible = <T>[];
    for (var start = 0; start < items.length; start += maxConcurrent) {
      final end = (start + maxConcurrent).clamp(0, items.length);
      final batch = items.sublist(start, end);
      final decisions = await Future.wait(
        batch.map(
          (item) => _shouldKeep(
            item,
            config: config,
            ruleSet: ruleSet,
            getAid: getAid,
            loader: loader,
            timeout: timeout,
          ),
        ),
      );
      for (var i = 0; i < batch.length; i++) {
        if (decisions[i]) visible.add(batch[i]);
      }
    }
    return visible;
  }

  static Future<bool> _shouldKeep<T>(
    T item, {
    required CommentShieldingConfig config,
    required ShieldRuleSet ruleSet,
    required int? Function(T item) getAid,
    required HomeFeedCommentLoader loader,
    required Duration timeout,
  }) async {
    final aid = getAid(item);
    if (aid == null || aid <= 0) return true;

    try {
      final state = await loader(
        oid: aid,
        type: videoReplyType,
        mode: Mode.MAIN_LIST_HOT,
        offset: null,
        cursorNext: null,
      ).timeout(timeout);

      if (state case Success(:final response)) {
        if (_hasVisibleCheckedComment(
          response.replies,
          config: config,
          ruleSet: ruleSet,
        )) {
          return true;
        }
        return !_checkedCommentsExhausted(response);
      }
      return true;
    } on TimeoutException {
      return true;
    } catch (_) {
      return true;
    }
  }

  static bool _hasVisibleCheckedComment(
    List<ReplyInfo> replies, {
    required CommentShieldingConfig config,
    required ShieldRuleSet ruleSet,
  }) {
    if (replies.isEmpty) return true;
    for (final reply in replies) {
      if (_isVisible(reply, config: config, ruleSet: ruleSet)) return true;
    }
    return false;
  }

  static bool _checkedCommentsExhausted(MainListReply response) {
    if (response.hasPaginationReply() &&
        response.paginationReply.nextOffset.isNotEmpty) {
      return false;
    }
    if (response.hasCursor() && response.cursor.hasIsEnd()) {
      return response.cursor.isEnd;
    }
    return true;
  }

  static bool _isVisible(
    ReplyInfo reply, {
    required CommentShieldingConfig config,
    required ShieldRuleSet ruleSet,
  }) {
    if (!CommentShieldMatcher.match(reply, config).visible) return false;
    if (ruleSet.isScopeEnabled(ShieldScope.comment) &&
        !ShieldMatcher.match(
          ShieldingAdapters.fromReplyInfo(reply),
          ruleSet,
        ).visible) {
      return false;
    }
    return true;
  }

  static Future<LoadingState<MainListReply>> _defaultLoader({
    required int oid,
    required int type,
    required Mode mode,
    required String? offset,
    required Int64? cursorNext,
  }) => ReplyGrpc.mainList(
    oid: oid,
    type: type,
    mode: mode,
    offset: offset,
    cursorNext: cursorNext,
  );
}
