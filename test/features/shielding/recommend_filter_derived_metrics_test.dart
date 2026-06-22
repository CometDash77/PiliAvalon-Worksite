import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecommendFilter derived metrics', () {
    setUp(() {
      _resetRecommendFilter();
      RecommendFilter.shieldRuleSetProvider = ShieldRuleSet.new;
    });

    tearDown(_resetRecommendFilter);

    test('default disabled switches do not filter low derived metrics', () {
      final item = _video(
        view: 1000,
        like: 1,
        danmu: 0,
        reply: 0,
        coin: 0,
        favorite: 0,
      );

      expect(RecommendFilter.filterDerivedMetrics(item), isFalse);
      expect(RecommendFilter.filter(item), isFalse);
    });

    test('interaction rate blocks below threshold and allows boundary', () {
      RecommendFilter.filterInteractionRateForRecommend = true;
      RecommendFilter.minInteractionRateForRecommend = 1.0;

      expect(
        RecommendFilter.filterDerivedMetrics(
          _video(view: 1000, danmu: 5, reply: 4),
        ),
        isTrue,
      );
      expect(
        RecommendFilter.filterDerivedMetrics(
          _video(view: 1000, danmu: 5, reply: 5),
        ),
        isFalse,
      );
    });

    test('triple rate blocks below threshold and allows boundary', () {
      RecommendFilter.filterTripleRateForRecommend = true;
      RecommendFilter.minTripleRateForRecommend = 3.0;

      expect(
        RecommendFilter.filterDerivedMetrics(
          _video(view: 1000, like: 10, coin: 10, favorite: 9),
        ),
        isTrue,
      );
      expect(
        RecommendFilter.filterDerivedMetrics(
          _video(view: 1000, like: 10, coin: 10, favorite: 10),
        ),
        isFalse,
      );
    });

    test('content value blocks below threshold and allows boundary', () {
      RecommendFilter.filterContentValueForRecommend = true;
      RecommendFilter.minContentValueForRecommend = 10.0;

      expect(
        RecommendFilter.filterDerivedMetrics(_video(like: 100, coin: 9)),
        isTrue,
      );
      expect(
        RecommendFilter.filterDerivedMetrics(_video(like: 100, coin: 10)),
        isFalse,
      );
    });

    test('zero and null denominators pass through', () {
      RecommendFilter.filterInteractionRateForRecommend = true;
      RecommendFilter.filterTripleRateForRecommend = true;
      RecommendFilter.filterContentValueForRecommend = true;

      expect(
        RecommendFilter.filterDerivedMetrics(
          _video(view: 0, like: 0, danmu: 0, reply: 0, coin: 0, favorite: 0),
        ),
        isFalse,
      );
      expect(
        RecommendFilter.filterDerivedMetrics(
          _video(
            view: null,
            like: null,
            danmu: 0,
            reply: 0,
            coin: 0,
            favorite: 0,
          ),
        ),
        isFalse,
      );
    });

    test('null numerators are treated as zero', () {
      RecommendFilter.filterInteractionRateForRecommend = true;
      RecommendFilter.filterTripleRateForRecommend = true;
      RecommendFilter.filterContentValueForRecommend = true;

      expect(
        RecommendFilter.filterDerivedMetrics(_video(view: 1000, like: 100)),
        isTrue,
      );
    });

    test('followed items are exempt when followed exemption is enabled', () {
      RecommendFilter.filterInteractionRateForRecommend = true;
      RecommendFilter.exemptFilterForFollowed = true;

      final item = _video(view: 1000, danmu: 0, reply: 0, isFollowed: true);

      expect(RecommendFilter.filter(item), isFalse);
      expect(RecommendFilter.filterDerivedMetrics(item), isFalse);
    });

    test('followed items are filtered when followed exemption is disabled', () {
      RecommendFilter.filterInteractionRateForRecommend = true;
      RecommendFilter.exemptFilterForFollowed = false;

      final item = _video(view: 1000, danmu: 0, reply: 0, isFollowed: true);

      expect(RecommendFilter.filter(item), isTrue);
      expect(RecommendFilter.filterDerivedMetrics(item), isTrue);
    });

    test('recommendation scene switch disables derived metrics', () {
      RecommendFilter.filterInteractionRateForRecommend = true;
      RecommendFilter.shieldRuleSetProvider = () => ShieldRuleSet(
        recommendationEnabled: false,
      );

      expect(
        RecommendFilter.filterDerivedMetrics(
          _video(view: 1000, danmu: 0, reply: 0),
        ),
        isFalse,
      );
    });

    test('web stat maps reply coin and favorite fields', () {
      final stat = Stat.fromJson({
        'view': 1000,
        'like': 20,
        'danmaku': 5,
        'reply': 7,
        'coin': 8,
        'favorite': 9,
      });

      expect(stat.reply, 7);
      expect(stat.coin, 8);
      expect(stat.favorite, 9);
    });
  });
}

void _resetRecommendFilter() {
  RecommendFilter.minDurationForRcmd = 0;
  RecommendFilter.minPlayForRcmd = 0;
  RecommendFilter.minLikeRatioForRecommend = 0;
  RecommendFilter.filterInteractionRateForRecommend = false;
  RecommendFilter.minInteractionRateForRecommend = 1.0;
  RecommendFilter.filterTripleRateForRecommend = false;
  RecommendFilter.minTripleRateForRecommend = 3.0;
  RecommendFilter.filterContentValueForRecommend = false;
  RecommendFilter.minContentValueForRecommend = 10.0;
  RecommendFilter.exemptFilterForFollowed = false;
  RecommendFilter.applyFilterToRelatedVideos = false;
  RecommendFilter.rcmdRegExp = RegExp('', caseSensitive: false);
  RecommendFilter.enableFilter = false;
  RecommendFilter.useLegacyTextFilter = false;
  RecommendFilter.shieldRuleSetProvider = null;
}

_TestVideo _video({
  int? view = 1000,
  int? like,
  int? danmu,
  int? reply,
  num? coin,
  int? favorite,
  bool isFollowed = false,
}) => _TestVideo(
  view: view,
  like: like,
  danmu: danmu,
  reply: reply,
  coin: coin,
  favorite: favorite,
  isFollowed: isFollowed,
);

class _TestVideo extends BaseVideoItemModel {
  _TestVideo({
    required int? view,
    required int? like,
    required int? danmu,
    required int? reply,
    required num? coin,
    required int? favorite,
    required bool isFollowed,
  }) {
    title = 'test video';
    owner = _TestOwner();
    stat = _TestStat(
      view: view,
      like: like,
      danmu: danmu,
      reply: reply,
      coin: coin,
      favorite: favorite,
    );
    this.isFollowed = isFollowed;
  }
}

class _TestOwner extends BaseOwner {}

class _TestStat extends BaseStat {
  _TestStat({
    required int? view,
    required int? like,
    required int? danmu,
    required int? reply,
    required num? coin,
    required int? favorite,
  }) {
    this.view = view;
    this.like = like;
    this.danmu = danmu;
    this.reply = reply;
    this.coin = coin;
    this.favorite = favorite;
  }
}
