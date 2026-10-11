import 'package:PiliPlus/features/shielding/recommendation_filter.dart';
import 'package:PiliPlus/features/shielding/recommendation_pipeline.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'one snapshot per batch; ordered stages see survivors and same rules',
    () async {
      final events = <String>[];
      var ruleReads = 0;
      var configReads = 0;
      var rules = _rules(ShieldScope.recommendation);
      final original = rules;
      final pipeline = RecommendationPipeline(
        ruleSetProvider: () {
          ruleReads++;
          return rules;
        },
        filterConfigProvider: () {
          configReads++;
          return const RecommendationFilterConfig();
        },
      );
      final blocked = _Video('blocked');
      final commentBlocked = _Video('comment');
      final exposed = _Video('exposed');
      final jevBlocked = _Video('jev');
      final visible = _Video('visible');
      final result = await pipeline.run<_Video>(
        [blocked, commentBlocked, exposed, jevBlocked, visible],
        legacyPolicy: RecommendationLegacyPolicy.home,
        toCandidate: (item) {
          events.add('filter:${item.title}');
          return _candidate(item);
        },
        enrichTags: (items, snapshot) async {
          expect(snapshot, same(original));
          expect(items, [commentBlocked, exposed, jevBlocked, visible]);
          events.add('tags');
          rules = ShieldRuleSet(globalEnabled: false);
          await Future<void>.value();
          return items;
        },
        gateComments: (items, snapshot) async {
          expect(snapshot, same(original));
          events.add('comments');
          return items.where((item) => item != commentBlocked).toList();
        },
        filterExisting: (items) {
          events.add('exposure');
          return items.where((item) => item != exposed).toList();
        },
        screen: (items, snapshot) async {
          expect(snapshot, same(original));
          expect(items, [jevBlocked, visible]);
          events.add('jev');
          return [visible];
        },
        recordVisible: (items) {
          expect(items, [visible]);
          events.add('record');
        },
      );
      expect(result, [visible]);
      expect(ruleReads, 1);
      expect(configReads, 1);
      expect(events, [
        'filter:blocked',
        'filter:comment',
        'filter:exposed',
        'filter:jev',
        'filter:visible',
        'tags',
        'comments',
        'exposure',
        'jev',
        'record',
      ]);
    },
  );

  for (final surface in ['homeWeb', 'homeApp', 'hot', 'ranking', 'related']) {
    test(
      '$surface retains its legacy policy and optional stage selection',
      () async {
        const config = RecommendationFilterConfig(
          minDurationForRcmd: 60,
          filterInteractionRateForRecommend: true,
          minInteractionRateForRecommend: 1,
          exemptFilterForFollowed: true,
          applyFilterToRelatedVideos: true,
        );
        final home = surface.startsWith('home');
        final related = surface == 'related';
        final pipeline = RecommendationPipeline(
          ruleSetProvider: ShieldRuleSet.new,
          filterConfigProvider: () => config,
        );
        final short = _Video('short', duration: 30);
        final lowInteraction = _Video('lowInteraction', duration: 90);
        final followed = _Video('followed', duration: 30, followed: true);
        final events = <String>[];
        final result = await pipeline.run<_Video>(
          [short, lowInteraction, followed],
          legacyPolicy: home
              ? RecommendationLegacyPolicy.home
              : related
              ? RecommendationLegacyPolicy.related
              : RecommendationLegacyPolicy.popular,
          toCandidate: (item) => _candidate(
            item,
            related ? ShieldScope.videoDetail : ShieldScope.recommendation,
          ),
          enrichTags: home
              ? (items, _) async {
                  events.add('tags');
                  return items;
                }
              : null,
          gateComments: home
              ? (items, _) async {
                  events.add('comments');
                  return items;
                }
              : null,
          recordVisible: home
              ? (_) {
                  events.add('record');
                }
              : null,
        );
        expect(
          result,
          home
              ? [followed]
              : related
              ? [lowInteraction]
              : [short, lowInteraction, followed],
        );
        expect(events, home ? ['tags', 'comments', 'record'] : isEmpty);
      },
    );
  }

  test('related rule scope and old filter switch are independent', () async {
    final pipeline = RecommendationPipeline(
      ruleSetProvider: () =>
          _rules(ShieldScope.videoDetail)
              .copyWith(recommendationEnabled: false),
      filterConfigProvider: () => const RecommendationFilterConfig(
        applyFilterToRelatedVideos: false,
        minDurationForRcmd: 60,
      ),
    );
    final short = _Video('short', duration: 30);
    final result = await pipeline.run<_Video>(
      [_Video('blocked'), short],
      legacyPolicy: RecommendationLegacyPolicy.related,
      toCandidate: (item) => _candidate(item, ShieldScope.videoDetail),
    );
    expect(result, [short]);
  });

  test(
    'related legacy duration remains active with recommendation disabled',
    () async {
      final pipeline = RecommendationPipeline(
        ruleSetProvider: () => ShieldRuleSet(recommendationEnabled: false),
        filterConfigProvider: () => const RecommendationFilterConfig(
          applyFilterToRelatedVideos: true,
          minDurationForRcmd: 60,
        ),
      );
      final result = await pipeline.run<_Video>(
        [_Video('short', duration: 30)],
        legacyPolicy: RecommendationLegacyPolicy.related,
        toCandidate: (item) => _candidate(item, ShieldScope.videoDetail),
      );
      expect(result, isEmpty);
    },
  );

  test(
    'allow rule overrides shielding but does not override old metrics',
    () async {
      final block = _rules(ShieldScope.recommendation).rules.single;
      final pipeline = RecommendationPipeline(
        ruleSetProvider: () => ShieldRuleSet(
          rules: [
            block,
            block.copyWith(id: 'allow', action: ShieldAction.allow),
          ],
        ),
        filterConfigProvider: () =>
            const RecommendationFilterConfig(minPlayForRcmd: 500),
      );
      expect(
        await pipeline.run<_Video>(
          [_Video('blocked')],
          legacyPolicy: RecommendationLegacyPolicy.home,
          toCandidate: _candidate,
        ),
        isEmpty,
      );
    },
  );

  test('empty batch still runs injected stages as before', () async {
    final events = <String>[];
    final pipeline = RecommendationPipeline(
      ruleSetProvider: ShieldRuleSet.new,
      filterConfigProvider: () => const RecommendationFilterConfig(),
    );
    expect(
      await pipeline.run<_Video>(
        [],
        legacyPolicy: RecommendationLegacyPolicy.home,
        toCandidate: _candidate,
        enrichTags: (items, _) async {
          events.add('tags');
          return items;
        },
        screen: (items, _) async {
          events.add('screen');
          return items;
        },
        recordVisible: (_) {
          events.add('record');
        },
      ),
      isEmpty,
    );
    expect(events, ['tags', 'screen', 'record']);
  });
}

ShieldCandidate _candidate(
  _Video item, [
  ShieldScope scope = ShieldScope.recommendation,
]) => ShieldCandidate(scope: scope, title: item.title);

ShieldRuleSet _rules(ShieldScope scope) => ShieldRuleSet(
  rules: [
    ShieldRule(
      id: 'block',
      type: ShieldRuleType.keyword,
      matchMode: ShieldMatchMode.contains,
      scope: scope,
      action: ShieldAction.block,
      pattern: 'blocked',
      updatedAt: DateTime(2026),
    ),
  ],
);

class _Video extends BaseVideoItemModel {
  _Video(String text, {int duration = 90, bool followed = false}) {
    title = text;
    this.duration = duration;
    isFollowed = followed;
    stat = Stat.fromJson({'view': 100, 'like': 10});
  }
}
