import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/features/shielding/comment_shielding_config.dart';
import 'package:PiliPlus/features/shielding/shielding_adapters.dart';
import 'package:PiliPlus/features/shielding/shielding_matcher.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/utils/recommendation_metrics.dart';
import 'package:fixnum/fixnum.dart';

typedef HomeFeedCommentLoader = Future<LoadingState<MainListReply>> Function({
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
  static const Duration _decisionCacheTtl = Duration(seconds: 30);
  static const int _maxCachedDecisions = 256;

  static final Map<(int, String), _CommentGateCacheEntry> _decisionCache = {};
  static final Map<(int, String), Future<bool?>> _inFlight = {};

  /// Clears shared comment decisions. Intended for tests.
  static void resetCache() {
    _decisionCache.clear();
    _inFlight.clear();
  }

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

    final measurement = RecommendationMetrics.startPhase(
      RecommendationPhase.commentGate,
      inputCount: items.length,
    );
    _evictExpiredDecisions();
    final fingerprint = _policyFingerprint(config, ruleSet);
    final decisions = List<bool>.filled(items.length, true);
    var nextIndex = 0;
    final workerCount = maxConcurrent.clamp(1, items.length).toInt();

    Future<void> worker() async {
      while (true) {
        if (nextIndex >= items.length) return;
        final index = nextIndex++;
        decisions[index] = await _shouldKeep(
          items[index],
          config: config,
          ruleSet: ruleSet,
          getAid: getAid,
          loader: loader,
          timeout: timeout,
          policyFingerprint: fingerprint,
        );
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));
    final visible = <T>[];
    for (var i = 0; i < items.length; i++) {
      if (decisions[i]) visible.add(items[i]);
    }
    RecommendationMetrics.finishPhase(measurement, outputCount: visible.length);
    return visible;
  }

  static String _policyFingerprint(
    CommentShieldingConfig config,
    ShieldRuleSet ruleSet,
  ) {
    Object replyPolicy;
    try {
      replyPolicy = [
        ReplyGrpc.antiGoodsReply,
        ReplyGrpc.enableFilter,
        ReplyGrpc.useLegacyTextFilter,
        ReplyGrpc.replyRegExp.pattern,
      ];
    } catch (_) {
      // Storage-backed legacy settings may not be initialized in tests or
      // during an early startup path; use a stable sentinel until available.
      replyPolicy = const ['uninitialized'];
    }
    return jsonEncode([config.toJson(), ruleSet.toJson(), replyPolicy]);
  }

  static Future<bool> _cachedDecision(
    (int, String) key, {
    required CommentShieldingConfig config,
    required ShieldRuleSet ruleSet,
    required HomeFeedCommentLoader loader,
    required Duration timeout,
  }) async {
    final now = DateTime.now();
    final cached = _decisionCache.remove(key);
    if (cached != null &&
        now.difference(cached.checkedAt) < _decisionCacheTtl) {
      // Reinsert to make the insertion-ordered map an LRU for capacity trims.
      _decisionCache[key] = cached;
      return cached.shouldKeep;
    }

    final active = _inFlight[key];
    if (active != null) return (await active) ?? true;

    late final Future<bool?> request;
    request = _loadDecision(
      key.$1,
      config: config,
      ruleSet: ruleSet,
      policyFingerprint: key.$2,
      loader: loader,
      timeout: timeout,
    );
    _inFlight[key] = request;
    try {
      return (await request) ?? true;
    } finally {
      if (identical(_inFlight[key], request)) _inFlight.remove(key);
    }
  }

  static Future<bool?> _loadDecision(
    int aid, {
    required CommentShieldingConfig config,
    required ShieldRuleSet ruleSet,
    required String policyFingerprint,
    required HomeFeedCommentLoader loader,
    required Duration timeout,
  }) async {
    try {
      RecommendationMetrics.recordGrpcRequest('ReplyGrpc.mainList');
      final state = await loader(
        oid: aid,
        type: videoReplyType,
        mode: Mode.MAIN_LIST_HOT,
        offset: null,
        cursorNext: null,
      ).timeout(timeout);

      if (state case Success(:final response)) {
        final shouldKeep =
            _hasVisibleCheckedComment(
              response.replies,
              config: config,
              ruleSet: ruleSet,
            ) ||
            !_checkedCommentsExhausted(response);
        // Only successful server responses are cached. Errors and timeouts
        // remain fail-open and can be retried by the next page load.
        _decisionCache[(aid, policyFingerprint)] = _CommentGateCacheEntry(
          shouldKeep: shouldKeep,
          checkedAt: DateTime.now(),
        );
        _trimDecisionCache();
        return shouldKeep;
      }
      return null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static void _evictExpiredDecisions() {
    final cutoff = DateTime.now().subtract(_decisionCacheTtl);
    _decisionCache.removeWhere((_, entry) => entry.checkedAt.isBefore(cutoff));
  }

  static void _trimDecisionCache() {
    while (_decisionCache.length > _maxCachedDecisions) {
      _decisionCache.remove(_decisionCache.keys.first);
    }
  }

  static Future<bool> _shouldKeep<T>(
    T item, {
    required CommentShieldingConfig config,
    required ShieldRuleSet ruleSet,
    required int? Function(T item) getAid,
    required HomeFeedCommentLoader loader,
    required Duration timeout,
    required String policyFingerprint,
  }) async {
    final aid = getAid(item);
    if (aid == null || aid <= 0) return true;
    return _cachedDecision(
      (aid, policyFingerprint),
      config: config,
      ruleSet: ruleSet,
      loader: loader,
      timeout: timeout,
    );
  }

  static bool _hasVisibleCheckedComment(
    List<ReplyInfo> replies, {
    required CommentShieldingConfig config,
    required ShieldRuleSet ruleSet,
  }) {
    if (replies.isEmpty) return false;
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

class _CommentGateCacheEntry {
  const _CommentGateCacheEntry({
    required this.shouldKeep,
    required this.checkedAt,
  });

  final bool shouldKeep;
  final DateTime checkedAt;
}
