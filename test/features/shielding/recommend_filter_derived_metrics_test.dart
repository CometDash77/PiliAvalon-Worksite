import 'package:PiliPlus/features/shielding/recommendation_filter.dart';
import 'package:PiliPlus/features/shielding/recommendation_filter_config.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ruleSet = ShieldRuleSet();

  RecommendationFilterConfig config({
    bool filterInteractionRateForRecommend = false,
    bool filterTripleRateForRecommend = false,
    bool filterContentValueForRecommend = false,
    bool exemptFilterForFollowed = false,
  }) => RecommendationFilterConfig(
    filterInteractionRateForRecommend: filterInteractionRateForRecommend,
    filterTripleRateForRecommend: filterTripleRateForRecommend,
    filterContentValueForRecommend: filterContentValueForRecommend,
    exemptFilterForFollowed: exemptFilterForFollowed,
  );

  _TestVideo video({required _TestStat stat, bool isFollowed = false}) =>
      _TestVideo(stat: stat, isFollowed: isFollowed);

  test('default config keeps derived metrics off', () {
    final item = video(
      stat: _TestStat(view: 1000, like: 100, danmu: 5, reply: 5, coin: 10, favorite: 10),
    );

    expect(
      RecommendationFilter.filterDerivedMetrics(ruleSet, config(), item),
      isFalse,
    );
    expect(RecommendationFilter.filter(ruleSet, config(), item), isFalse);
  });

  test('interaction rate threshold filters weak interactions', () {
    final metricConfig = config(filterInteractionRateForRecommend: true);

    final weak = video(
      stat: _TestStat(view: 1000, like: 100, danmu: 5, reply: 4),
    );
    final ok = video(stat: _TestStat(view: 1000, like: 100, danmu: 5, reply: 5));

    expect(
      RecommendationFilter.filterDerivedMetrics(ruleSet, metricConfig, weak),
      isTrue,
    );
    expect(
      RecommendationFilter.filterDerivedMetrics(ruleSet, metricConfig, ok),
      isFalse,
    );
  });

  test('triple rate threshold filters weak triple actions', () {
    final metricConfig = config(filterTripleRateForRecommend: true);

    final weak = video(
      stat: _TestStat(view: 1000, like: 10, coin: 10, favorite: 9),
    );
    final ok = video(
      stat: _TestStat(view: 1000, like: 10, coin: 10, favorite: 10),
    );

    expect(
      RecommendationFilter.filterDerivedMetrics(ruleSet, metricConfig, weak),
      isTrue,
    );
    expect(
      RecommendationFilter.filterDerivedMetrics(ruleSet, metricConfig, ok),
      isFalse,
    );
  });

  test('content value threshold filters low coin-to-like ratios', () {
    final metricConfig = config(filterContentValueForRecommend: true);

    final weak = video(stat: _TestStat(like: 100, coin: 9));
    final ok = video(stat: _TestStat(like: 100, coin: 10));

    expect(
      RecommendationFilter.filterDerivedMetrics(ruleSet, metricConfig, weak),
      isTrue,
    );
    expect(
      RecommendationFilter.filterDerivedMetrics(ruleSet, metricConfig, ok),
      isFalse,
    );
  });

  test('zero or null denominators never filter', () {
    final metricConfig = config(
      filterInteractionRateForRecommend: true,
      filterTripleRateForRecommend: true,
      filterContentValueForRecommend: true,
    );

    final zeroed = video(stat: _TestStat(view: 0, like: 0));
    final noView = video(stat: _TestStat(like: 100, coin: 100));

    expect(
      RecommendationFilter.filterDerivedMetrics(ruleSet, metricConfig, zeroed),
      isFalse,
    );
    expect(RecommendationFilter.filter(ruleSet, metricConfig, zeroed), isFalse);
    expect(
      RecommendationFilter.filterDerivedMetrics(ruleSet, metricConfig, noView),
      isFalse,
    );
  });

  test('null numerators count as zero', () {
    final metricConfig = config(
      filterInteractionRateForRecommend: true,
      filterTripleRateForRecommend: true,
      filterContentValueForRecommend: true,
    );

    final item = video(stat: _TestStat(view: 1000, like: 100));

    expect(
      RecommendationFilter.filterDerivedMetrics(ruleSet, metricConfig, item),
      isTrue,
    );
  });

  test('followed items are exempt when the setting is on', () {
    final exemptConfig = config(
      filterInteractionRateForRecommend: true,
      exemptFilterForFollowed: true,
    );

    final item = video(
      stat: _TestStat(view: 1000, like: 100, danmu: 5, reply: 4),
      isFollowed: true,
    );

    expect(
      RecommendationFilter.filterDerivedMetrics(ruleSet, exemptConfig, item),
      isFalse,
    );
    expect(RecommendationFilter.filter(ruleSet, exemptConfig, item), isFalse);
  });

  test('followed items are filtered when the setting is off', () {
    final metricConfig = config(filterInteractionRateForRecommend: true);

    final item = video(
      stat: _TestStat(view: 1000, like: 100, danmu: 5, reply: 4),
      isFollowed: true,
    );

    expect(
      RecommendationFilter.filterDerivedMetrics(ruleSet, metricConfig, item),
      isTrue,
    );
    expect(RecommendationFilter.filter(ruleSet, metricConfig, item), isTrue);
  });

  test('recommendation scope switch disables derived metrics', () {
    final offRuleSet = ShieldRuleSet(recommendationEnabled: false);
    final metricConfig = config(
      filterInteractionRateForRecommend: true,
      filterTripleRateForRecommend: true,
      filterContentValueForRecommend: true,
    );

    final item = video(stat: _TestStat(view: 1000, like: 100, danmu: 5, reply: 4));

    expect(
      RecommendationFilter.filterDerivedMetrics(offRuleSet, metricConfig, item),
      isFalse,
    );
    expect(
      RecommendationFilter.filter(offRuleSet, metricConfig, item),
      isFalse,
    );
  });

  test('stat json mapping stays intact', () {
    final stat = Stat.fromJson({
      'view': 1000,
      'like': 20,
      'danmaku': 5,
      'reply': 7,
      'coin': 8,
      'favorite': 9,
    });

    expect(stat.view, 1000);
    expect(stat.like, 20);
    expect(stat.danmu, 5);
    expect(stat.reply, 7);
    expect(stat.coin, 8);
    expect(stat.favorite, 9);
  });
}

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
  _TestVideo({required _TestStat stat, bool isFollowed = false}) {
    title = '视频标题';
    owner = _TestOwner();
    this.stat = stat;
    this.isFollowed = isFollowed;
  }
}
