import 'dart:math';

import 'package:PiliPlus/features/shielding/recommendation_filter.dart';
import 'package:PiliPlus/features/shielding/recommendation_filter_config.dart';
import 'package:PiliPlus/features/shielding/shielding_adapters.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:flutter_test/flutter_test.dart';

/// 差分对拍：合并前旧「两遍判定」表达式与合并后 [RecommendationFilter.visible]
/// 的逐位等价性。
///
/// 旧表达式（改造前 homeFeed judge）：
/// `!RecommendationFilter.filter(rs, cfg, item) &&
/// ShieldingAdapters.isVisible(candidate, rs)`。
void main() {
  group('merged homeFeed judge vs legacy two-pass expression', () {
    test('differential sweep: no mismatch across rules x configs x items', () {
      final ruleSets = _ruleSets();
      final configs = _configs();
      final rng = Random(51); // 固定种子：可复跑
      var comparisons = 0;
      String? mismatch;

      outer:
      for (var i = 0; i < 8000; i++) {
        final (candidate, item) = _sample(rng);
        for (final ruleSet in ruleSets) {
          for (final config in configs) {
            final legacy = _legacyJudge(ruleSet, config, item, candidate);
            final merged = RecommendationFilter.visible(
              ruleSet,
              config,
              item: item,
              candidate: candidate,
            );
            comparisons++;
            if (legacy != merged) {
              mismatch =
                  'item=${_describeItem(item)} '
                  'candidate=${_describeCandidate(candidate)} '
                  'ruleSet=${_describeRuleSet(ruleSet)} '
                  'config=${_describeConfig(config)} '
                  'legacy=$legacy merged=$merged';
              break outer;
            }
          }
        }
      }

      expect(mismatch, isNull);
      expect(comparisons, greaterThan(500000));
    });

    test('scope off leaves candidates visible under both judges', () {
      final ruleSet = ShieldRuleSet(recommendationEnabled: false);
      final config = RecommendationFilterConfig(
        minDurationForRcmd: 120,
        minPlayForRcmd: 1000,
        minLikeRatioForRecommend: 10,
        rcmdRegExp: RegExp('剧透', caseSensitive: false),
        useLegacyTextFilter: true,
      );
      final (candidate, item) = _fixed(
        duration: 60,
        view: 10,
        like: 0,
        title: '剧透短视频',
      );

      expect(_legacyJudge(ruleSet, config, item, candidate), isTrue);
      expect(
        RecommendationFilter.visible(
          ruleSet,
          config,
          item: item,
          candidate: candidate,
        ),
        isTrue,
      );
    });

    test('threshold hit hides candidate even when an allow rule matches', () {
      final ruleSet = ShieldRuleSet(
        rules: [
          _rule('kw-allow', ShieldRuleType.keyword, ShieldMatchMode.contains, ShieldAction.allow, '剧透'),
        ],
      );
      final config = RecommendationFilterConfig(minDurationForRcmd: 120);
      final (candidate, item) = _fixed(duration: 60, view: 5000, like: 5, title: '剧透短视频');

      // 规则本身会放行，但时长阈值先行命中 → 两代判定都不可见。
      expect(ShieldingAdapters.isVisible(candidate, ruleSet), isTrue);
      expect(_legacyJudge(ruleSet, config, item, candidate), isFalse);
      expect(
        RecommendationFilter.visible(
          ruleSet,
          config,
          item: item,
          candidate: candidate,
        ),
        isFalse,
      );
    });

    test('followed items skip thresholds but still face rules', () {
      final ruleSet = ShieldRuleSet(
        rules: [
          _rule('kw-block', ShieldRuleType.keyword, ShieldMatchMode.contains, ShieldAction.block, '剧透'),
        ],
      );
      final config = RecommendationFilterConfig(
        minDurationForRcmd: 120,
        exemptFilterForFollowed: true,
      );
      final (candidate, item) = _fixed(
        duration: 60,
        view: 10,
        like: 0,
        title: '剧透短视频',
        isFollowed: true,
      );

      expect(_legacyJudge(ruleSet, config, item, candidate), isFalse);
      expect(
        RecommendationFilter.visible(
          ruleSet,
          config,
          item: item,
          candidate: candidate,
        ),
        isFalse,
      );
    });

    test('allow rule overrides block when thresholds pass', () {
      final ruleSet = ShieldRuleSet(
        rules: [
          _rule('kw-allow', ShieldRuleType.keyword, ShieldMatchMode.contains, ShieldAction.allow, '剧透'),
          _rule('ad-block', ShieldRuleType.keyword, ShieldMatchMode.contains, ShieldAction.block, '广告'),
        ],
      );
      final config = RecommendationFilterConfig();
      final (candidate, item) = _fixed(duration: 600, view: 5000, like: 500, title: '剧透短视频');

      expect(_legacyJudge(ruleSet, config, item, candidate), isTrue);
      expect(
        RecommendationFilter.visible(
          ruleSet,
          config,
          item: item,
          candidate: candidate,
        ),
        isTrue,
      );
    });
  });
}

bool _legacyJudge(
  ShieldRuleSet ruleSet,
  RecommendationFilterConfig config,
  BaseVideoItemModel item,
  ShieldCandidate candidate,
) =>
    !RecommendationFilter.filter(ruleSet, config, item) &&
    ShieldingAdapters.isVisible(candidate, ruleSet);

ShieldRule _rule(
  String id,
  ShieldRuleType type,
  ShieldMatchMode matchMode,
  ShieldAction action,
  String pattern,
) => ShieldRule(
  id: id,
  type: type,
  matchMode: matchMode,
  scope: ShieldScope.recommendation,
  action: action,
  pattern: pattern,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
);

List<ShieldRuleSet> _ruleSets() {
  ShieldRuleSet one(ShieldRule rule) => ShieldRuleSet(rules: [rule]);
  return [
    ShieldRuleSet(),
    one(_rule('kw-block', ShieldRuleType.keyword, ShieldMatchMode.contains, ShieldAction.block, '剧透')),
    ShieldRuleSet(rules: [
      _rule('kw-allow', ShieldRuleType.keyword, ShieldMatchMode.contains, ShieldAction.allow, '剧透'),
      _rule('ad-block', ShieldRuleType.keyword, ShieldMatchMode.contains, ShieldAction.block, '广告'),
    ]),
    one(_rule('uid-block', ShieldRuleType.uid, ShieldMatchMode.exact, ShieldAction.block, '42')),
    one(_rule('cat-block', ShieldRuleType.category, ShieldMatchMode.exact, ShieldAction.block, '游戏')),
    one(_rule('tag-block', ShieldRuleType.tag, ShieldMatchMode.token, ShieldAction.block, '萌宠')),
    one(_rule('regex-block', ShieldRuleType.keyword, ShieldMatchMode.regex, ShieldAction.block, '剧.*透')),
    one(_rule('dur-block', ShieldRuleType.duration, ShieldMatchMode.range, ShieldAction.block, '0..60')),
    one(_rule('view-block', ShieldRuleType.playbackCount, ShieldMatchMode.range, ShieldAction.block, '1000..')),
    ShieldRuleSet(globalEnabled: false, rules: [
      _rule('kw-block', ShieldRuleType.keyword, ShieldMatchMode.contains, ShieldAction.block, '剧透'),
    ]),
    ShieldRuleSet(recommendationEnabled: false, rules: [
      _rule('kw-block', ShieldRuleType.keyword, ShieldMatchMode.contains, ShieldAction.block, '剧透'),
    ]),
    ShieldRuleSet(rules: [
      _rule('tag-allow', ShieldRuleType.tag, ShieldMatchMode.token, ShieldAction.allow, '萌宠'),
      _rule('ukw-block', ShieldRuleType.userKeyword, ShieldMatchMode.contains, ShieldAction.block, 'UP'),
      _rule('regex-block2', ShieldRuleType.keyword, ShieldMatchMode.regex, ShieldAction.block, '短视频'),
    ]),
  ];
}

List<RecommendationFilterConfig> _configs() => [
  RecommendationFilterConfig(),
  RecommendationFilterConfig(
    minDurationForRcmd: 120,
    minPlayForRcmd: 1000,
    minLikeRatioForRecommend: 10,
    exemptFilterForFollowed: false,
  ),
  RecommendationFilterConfig(
    minDurationForRcmd: 120,
    minPlayForRcmd: 1000,
    minLikeRatioForRecommend: 10,
    exemptFilterForFollowed: true,
  ),
  RecommendationFilterConfig(
    minDurationForRcmd: 120,
    minPlayForRcmd: 1000,
    minLikeRatioForRecommend: 10,
    filterInteractionRateForRecommend: true,
    filterTripleRateForRecommend: true,
    filterContentValueForRecommend: true,
    exemptFilterForFollowed: false,
  ),
  RecommendationFilterConfig(
    filterInteractionRateForRecommend: true,
    filterTripleRateForRecommend: true,
    filterContentValueForRecommend: true,
    exemptFilterForFollowed: false,
  ),
  RecommendationFilterConfig(
    rcmdRegExp: RegExp('剧透', caseSensitive: false),
    useLegacyTextFilter: true,
  ),
  RecommendationFilterConfig(
    minDurationForRcmd: 120,
    minPlayForRcmd: 1000,
    minLikeRatioForRecommend: 10,
    rcmdRegExp: RegExp('剧透', caseSensitive: false),
    useLegacyTextFilter: true,
    exemptFilterForFollowed: true,
  ),
  RecommendationFilterConfig(
    minLikeRatioForRecommend: 5,
    exemptFilterForFollowed: false,
  ),
];

const _durations = [0, 1, 59, 60, 61, 120, 121, 600];
const _views = <int?>[null, 0, 1, 10, 999, 1000, 5000];
const _likes = <int?>[null, 0, 1, 9, 10, 99, 100];
const _danmus = <int?>[null, 0, 5];
const _replies = <int?>[null, 0, 4, 5];
const _coins = <num?>[null, 0, 9, 10];
const _favorites = <int?>[null, 0, 3];
const _titles = ['正常视频', '剧透短视频', '广告视频', '猫咪睡觉'];
const _uids = <String?>[null, '42', '7'];
const _categories = <String?>[null, '游戏', '动物'];
const _tagPool = [
  <String>[],
  ['萌宠'],
  ['广告'],
];

(ShieldCandidate, BaseVideoItemModel) _sample(Random rng) {
  final title = _titles[rng.nextInt(_titles.length)];
  final uid = _uids[rng.nextInt(_uids.length)];
  final category = _categories[rng.nextInt(_categories.length)];
  final tags = _tagPool[rng.nextInt(_tagPool.length)];
  final duration = _durations[rng.nextInt(_durations.length)];
  final view = _views[rng.nextInt(_views.length)];
  final like = _likes[rng.nextInt(_likes.length)];
  final danmu = _danmus[rng.nextInt(_danmus.length)];
  final reply = _replies[rng.nextInt(_replies.length)];
  final coin = _coins[rng.nextInt(_coins.length)];
  final favorite = _favorites[rng.nextInt(_favorites.length)];
  final isFollowed = rng.nextBool();

  final item = _TestVideo(
    title: title,
    stat: _TestStat(
      view: view,
      like: like,
      danmu: danmu,
      reply: reply,
      coin: coin,
      favorite: favorite,
    ),
    isFollowed: isFollowed,
  );
  final candidate = _candidate(
    title: title,
    uid: uid,
    category: category,
    tags: tags,
    duration: duration,
    view: view,
    danmu: danmu,
  );
  return (candidate, item);
}

(ShieldCandidate, BaseVideoItemModel) _fixed({
  required int duration,
  required int view,
  required int like,
  required String title,
  bool isFollowed = false,
}) {
  final item = _TestVideo(
    title: title,
    stat: _TestStat(view: view, like: like, danmu: 1, reply: 1, coin: 1, favorite: 1),
    isFollowed: isFollowed,
    duration: duration,
  );
  final candidate = _candidate(
    title: title,
    uid: '42',
    category: '游戏',
    tags: const ['萌宠'],
    duration: duration,
    view: view,
    danmu: 1,
  );
  return (candidate, item);
}

ShieldCandidate _candidate({
  required String title,
  required String? uid,
  required String? category,
  required List<String> tags,
  required int duration,
  required int? view,
  required int? danmu,
}) => ShieldCandidate(
  scope: ShieldScope.recommendation,
  title: title,
  uid: uid,
  authorName: 'UP主',
  category: category,
  tags: tags,
  durationSeconds: duration > 0 ? duration : null,
  playbackCount: view,
  danmakuCount: danmu,
);

String _describeRule(ShieldRule rule) =>
    '${rule.type.name}/${rule.matchMode.name}/${rule.action.name}'
    '/${rule.pattern}/${rule.scope.name}${rule.enabled ? '' : '/disabled'}';

String _describeRuleSet(ShieldRuleSet ruleSet) =>
    'global=${ruleSet.globalEnabled} rec=${ruleSet.recommendationEnabled} '
    'rules=[${ruleSet.rules.map(_describeRule).join(' | ')}]';

String _describeConfig(RecommendationFilterConfig config) =>
    'dur=${config.minDurationForRcmd} play=${config.minPlayForRcmd} '
    'likeRatio=${config.minLikeRatioForRecommend} '
    'metrics=${config.filterInteractionRateForRecommend}'
    '${config.filterTripleRateForRecommend}'
    '${config.filterContentValueForRecommend} '
    'exempt=${config.exemptFilterForFollowed} '
    'legacyText=${config.useLegacyTextFilter}';

String _describeItem(BaseVideoItemModel item) =>
    'title=${item.title} duration=${item.duration} '
    'followed=${item.isFollowed} stat=${_describeStat(item.stat)}';

String _describeStat(BaseStat stat) =>
    'view=${stat.view} like=${stat.like} danmu=${stat.danmu} '
    'reply=${stat.reply} coin=${stat.coin} favorite=${stat.favorite}';

String _describeCandidate(ShieldCandidate candidate) =>
    'title=${candidate.title} uid=${candidate.uid} '
    'category=${candidate.category} tags=${candidate.tags} '
    'duration=${candidate.durationSeconds} play=${candidate.playbackCount} '
    'danmaku=${candidate.danmakuCount}';

class _TestOwner extends BaseOwner {}

class _TestStat extends BaseStat {
  _TestStat({int? view, int? like, int? danmu, int? reply, num? coin, int? favorite}) {
    this.view = view;
    this.like = like;
    this.danmu = danmu;
    this.reply = reply;
    this.coin = coin;
    this.favorite = favorite;
  }
}

class _TestVideo extends BaseVideoItemModel {
  _TestVideo({required String title, required _TestStat stat, bool isFollowed = false, int duration = -1}) {
    this.title = title;
    owner = _TestOwner();
    this.stat = stat;
    this.isFollowed = isFollowed;
    this.duration = duration;
  }
}
