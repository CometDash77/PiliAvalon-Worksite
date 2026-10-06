import 'dart:async';
import 'dart:convert';

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

/// 首页评论门：没有可见评论的候选不上首页。
///
/// 每页的调度与去重只在这里做：
/// * 调度：[defaultMaxConcurrent] 个**持续补位**的 worker 依次从队首取候选，谁空
///   谁补 —— 没有「整批做完才开下一批」的屏障，所以一个慢请求只占一个槽位，队列
///   里剩下的候选照常按剩余槽位起跑；
/// * 同 aid 合并：同一批里重复的 aid、以及还在飞的那个 aid，都共享同一次请求；
/// * 成功判定缓存：[decisionCacheTtl] 内、策略键（评论配置 + 屏蔽规则 + ReplyGrpc
///   过滤开关）不变时直接复用判定，上限 [decisionCacheMaxEntries] 条。
///
/// 失败、超时与 `Error` 状态都**不**写缓存，下次仍会重试；这些情况下候选保留
/// （fail-open）。调用顺序仍是「标签富集 → 评论门」，也不做显示后的惰性判定。
abstract final class HomeFeedCommentGate {
  static const int videoReplyType = 1;
  static const int defaultMaxConcurrent = 3;
  static const Duration defaultTimeout = Duration(seconds: 3);

  /// 成功判定的存活期；满 30 秒即失效。
  static const Duration decisionCacheTtl = Duration(seconds: 30);

  /// 判定缓存上限（条）；超出后先丢最早写入的那些。
  static const int decisionCacheMaxEntries = 256;

  /// 判定缓存的时钟。生产路径不碰，测试替换它以验证 30 秒存活期。
  static DateTime Function() decisionCacheClock = DateTime.now;

  /// 当前策略键对应的那一代缓存。
  static _DecisionCache? _cache;

  /// 当前缓存条目数（顺手清掉过期条目）。测试用。
  static int get decisionCacheEntryCount {
    final cache = _cache;
    if (cache == null) return 0;
    cache.evictExpired();
    return cache.entryCount;
  }

  /// 丢掉当前这一代判定缓存（含在飞登记）。测试用。
  ///
  /// 已经在飞的请求照跑：它跑完只写回自己那一代（已脱离的）缓存，既不会被之后的
  /// 调用复用，也不会把谁卡住 —— 等在它上面的调用方各自持有那个 future。
  static void resetDecisionCache() {
    _cache = null;
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

    final decisionCache = _cacheFor(
      _strategyKey(config: config, ruleSet: ruleSet),
    );

    // 判定按原下标回填，worker 谁先完成都不影响输出顺序。
    final kept = List<bool>.filled(items.length, true);
    var next = 0;

    Future<void> worker() async {
      while (next < items.length) {
        // 取下标的读取与自增之间没有 await，两个 worker 不会拿到同一条。
        final index = next++;
        final aid = getAid(items[index]);
        if (aid == null || aid <= 0) continue;
        final decision = await _decisionFor(
          aid,
          cache: decisionCache,
          config: config,
          ruleSet: ruleSet,
          loader: loader,
          timeout: timeout,
        );
        // 没有判定（失败 / 超时）→ 保留条目（fail-open）。
        kept[index] = decision ?? true;
      }
    }

    final workerCount = maxConcurrent.clamp(1, items.length);
    await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);

    return [
      for (var i = 0; i < items.length; i++)
        if (kept[i]) items[i],
    ];
  }

  /// 一个 aid 的 keep/hide 判定；拿不到判定时返回 null（调用方 fail-open）。
  static Future<bool?> _decisionFor(
    int aid, {
    required _DecisionCache cache,
    required CommentShieldingConfig config,
    required ShieldRuleSet ruleSet,
    required HomeFeedCommentLoader loader,
    required Duration timeout,
  }) {
    final cached = cache.lookup(aid);
    if (cached != null) return Future.value(cached);

    final pending = cache.inFlight[aid];
    if (pending != null) return pending;

    // 在飞登记必须早于请求开始：loader 可能同步抛错，那种情况下 [_load] 的函数体
    // 在返回前就跑完了（异常被它自己接住），先调用后登记会留下一个永远没人清理的
    // 死键 —— 之后这个 aid 再也发不出请求，也走不到缓存那一步。
    final completer = Completer<bool?>();
    cache.inFlight[aid] = completer.future;
    _load(
      aid,
      config: config,
      ruleSet: ruleSet,
      loader: loader,
      timeout: timeout,
    ).then(
      (decision) {
        // 释放与完成之间没有 await：合并进来的调用方被唤醒时缓存已经写完。
        cache.inFlight.remove(aid);
        if (decision != null) cache.put(aid, decision);
        completer.complete(decision);
      },
      onError: (Object error, StackTrace stackTrace) {
        // 兜底：任何漏出 [_load] 的异常也只是「没有判定」，条目照样保留。
        cache.inFlight.remove(aid);
        completer.complete(null);
      },
    );
    return completer.future;
  }

  /// 发一次真实请求并算出判定；失败、超时与 `Error` 状态一律返回 null（不缓存）。
  ///
  /// 超时以**发起这次请求的那一方**传入的 [timeout] 为准：合并进来的调用方共享这
  /// 同一个截止时间，所以一次超时既不会写缓存（下次会重试），也不会把「没有判定」
  /// 当成隐藏。
  static Future<bool?> _load(
    int aid, {
    required CommentShieldingConfig config,
    required ShieldRuleSet ruleSet,
    required HomeFeedCommentLoader loader,
    required Duration timeout,
  }) async {
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
      return null;
    } on TimeoutException {
      // 超时不缓存：下一次仍会重试。
      return null;
    } catch (_) {
      // 任何其它失败同样不缓存。
      return null;
    }
  }

  /// 拿到 [key] 这一代缓存；键变了就换新的一代。
  ///
  /// 旧代的判定与在飞登记都留在旧代里，新键一条也拿不到 —— 所以新增屏蔽规则、改
  /// 评论配置或翻 ReplyGrpc 过滤开关之后，不会复用变化前的判定。
  static _DecisionCache _cacheFor(String key) {
    final active = _cache;
    if (active != null && active.key == key) return active;
    return _cache = _DecisionCache(key, decisionCacheClock);
  }

  /// 策略键：这三样里任何一样变了，判定结果都可能变，所以哪一样都不能让旧判定复用。
  ///
  /// 每页只算一次（不是每条候选一次）：规则数在几百量级时这次编码仍是微秒级，而它
  /// 挡掉的是整整一页的评论请求。`lastLoadedAt` / 规则写入时间不进键 —— 规则内容
  /// 相同就是同一代，规则内容一变键就变。
  static String _strategyKey({
    required CommentShieldingConfig config,
    required ShieldRuleSet ruleSet,
  }) => jsonEncode({
    'config': config.toJson(),
    'ruleSet': [
      ruleSet.version,
      ruleSet.globalEnabled,
      ruleSet.recommendationEnabled,
      ruleSet.commentEnabled,
      ruleSet.relatedVideoEnabled,
      [
        for (final rule in ruleSet.rules)
          [
            rule.id,
            rule.type.name,
            rule.matchMode.name,
            rule.scope.name,
            rule.action.name,
            rule.pattern,
            rule.enabled,
          ],
      ],
    ],
    'replyGrpcFilter': [
      ReplyGrpc.antiGoodsReply,
      ReplyGrpc.enableFilter,
      ReplyGrpc.useLegacyTextFilter,
      ReplyGrpc.replyRegExp.pattern,
    ],
  });

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

/// 一代判定缓存：对应一个策略键。
///
/// 存的是判定本身（keep/hide）而不是原始载荷，所以只有策略键完全相同的调用方之间
/// 才可能复用；键一变就整代作废（见 [HomeFeedCommentGate._cacheFor]）。
class _DecisionCache {
  _DecisionCache(this.key, this._clock);

  final String key;
  final DateTime Function() _clock;

  /// 默认的 `LinkedHashMap` 保持写入顺序，所以溢出时丢的是最早写入的那些。
  final Map<int, _CachedDecision> _entries = {};

  /// 在飞请求：aid → 共享的那一个 future。
  final Map<int, Future<bool?>> inFlight = {};

  int get entryCount => _entries.length;

  /// 命中的判定；没有或已满 [HomeFeedCommentGate.decisionCacheTtl] 时为 null。
  bool? lookup(int aid) {
    final entry = _entries[aid];
    if (entry == null) return null;
    if (entry.isExpiredAt(_clock())) {
      _entries.remove(aid);
      return null;
    }
    return entry.decision;
  }

  void put(int aid, bool decision) {
    _entries[aid] = _CachedDecision(decision: decision, storedAt: _clock());
    evictExpired();
    // 溢出只可能由这一次写入造成，丢一条就够。
    while (_entries.length > HomeFeedCommentGate.decisionCacheMaxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void evictExpired() {
    if (_entries.isEmpty) return;
    final now = _clock();
    final expired = <int>[];
    for (final entry in _entries.entries) {
      if (entry.value.isExpiredAt(now)) expired.add(entry.key);
    }
    for (final aid in expired) {
      _entries.remove(aid);
    }
  }
}

class _CachedDecision {
  const _CachedDecision({required this.decision, required this.storedAt});

  final bool decision;
  final DateTime storedAt;

  /// 满存活期即失效（存活就是「小于存活期」）。
  bool isExpiredAt(DateTime now) =>
      !now.isBefore(storedAt.add(HomeFeedCommentGate.decisionCacheTtl));
}
