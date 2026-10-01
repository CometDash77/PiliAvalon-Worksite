import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data_list_item.dart';
import 'package:PiliPlus/pages/setting/models/shielding_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('live-card shielding', () {
    test('maps live-card fields to a live candidate', () {
      final candidate = ShieldingAdapters.fromLiveCard(
        CardLiveItem(
          title: '正在播游戏实况',
          uname: '主播甲',
          uid: 42,
          roomid: 987654321,
          areaName: '单机游戏',
        ),
      );

      expect(candidate.scope, ShieldScope.live);
      expect(candidate.title, '正在播游戏实况');
      expect(candidate.authorName, '主播甲');
      expect(candidate.uid, '42');
      expect(candidate.roomId, '987654321');
      expect(candidate.category, '单机游戏');
    });

    test('room ID exact matching is independent from host UID', () {
      final roomRule = _rule(
        type: ShieldRuleType.roomId,
        pattern: '987654321',
      );

      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.live,
            uid: '42',
            roomId: '987654321',
          ),
          ShieldRuleSet(rules: [roomRule]),
        ).visible,
        isFalse,
      );
      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.live,
            uid: '987654321',
            roomId: '42',
          ),
          ShieldRuleSet(rules: [roomRule]),
        ).visible,
        isTrue,
      );
    });

    test('live rules match host name, title, and area only in live scope', () {
      final fieldRules = [
        (
          candidate: const ShieldCandidate(scope: ShieldScope.live, uid: '42'),
          rule: _rule(type: ShieldRuleType.uid, pattern: '42'),
        ),
        (
          candidate: const ShieldCandidate(
            scope: ShieldScope.live,
            authorName: '主播甲',
          ),
          rule: _rule(type: ShieldRuleType.userKeyword, pattern: '主播甲'),
        ),
        (
          candidate: const ShieldCandidate(
            scope: ShieldScope.live,
            title: '正在播游戏实况',
          ),
          rule: _rule(
            type: ShieldRuleType.keyword,
            mode: ShieldMatchMode.contains,
            pattern: '游戏实况',
          ),
        ),
        (
          candidate: const ShieldCandidate(
            scope: ShieldScope.live,
            category: '单机游戏',
          ),
          rule: _rule(type: ShieldRuleType.category, pattern: '单机游戏'),
        ),
      ];
      for (final item in fieldRules) {
        expect(
          ShieldMatcher.match(
            item.candidate,
            ShieldRuleSet(rules: [item.rule]),
          ).visible,
          isFalse,
        );
      }

      final allFieldsRules = ShieldRuleSet(
        rules: fieldRules.map((item) => item.rule).toList(),
      );
      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            uid: '42',
            authorName: '主播甲',
            title: '正在播游戏实况',
            category: '单机游戏',
          ),
          allFieldsRules,
        ).visible,
        isTrue,
      );
      expect(
        ShieldMatcher.match(
          const ShieldCandidate(scope: ShieldScope.live, uid: '42'),
          ShieldRuleSet(
            rules: [
              _rule(type: ShieldRuleType.uid, pattern: '42').copyWith(
                scope: ShieldScope.recommendation,
              ),
            ],
          ),
        ).visible,
        isTrue,
      );

      expect(
        ShieldMatcher.match(
          const ShieldCandidate(scope: ShieldScope.live, roomId: '987654321'),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.roomId,
                pattern: '987',
                mode: ShieldMatchMode.contains,
              ),
            ],
          ),
        ).visible,
        isTrue,
      );
    });

    test('room ID type survives persistence with exact/live semantics', () {
      final rule = _rule(type: ShieldRuleType.roomId, pattern: '987654321');
      final decoded = ShieldRule.fromJson(rule.toJson());

      expect(decoded.type, ShieldRuleType.roomId);
      expect(decoded.matchMode, ShieldMatchMode.exact);
      expect(decoded.scope, ShieldScope.live);
      expect(shieldRuleTypeLabel(decoded.type), '直播间 ID');
      expect(shieldingRuleCategoryFor(decoded), '直播');
    });

    test('duplicate live room quick rules are idempotent', () async {
      final store = ShieldSettingsStore(box: _MemoryBox());
      final first = await store.addQuickActionRule(
        type: ShieldRuleType.roomId,
        scope: ShieldScope.live,
        pattern: '987654321',
      );
      final second = await store.addQuickActionRule(
        type: ShieldRuleType.roomId,
        scope: ShieldScope.live,
        pattern: '987654321',
      );

      expect(first, isNotNull);
      expect(first!.matchMode, ShieldMatchMode.exact);
      expect(first.action, ShieldAction.block);
      expect(first.source, ShieldRuleSource.quickAction);
      expect(second, isNull);
      expect(store.snapshot().rules, hasLength(1));
    });

    test('quick shielding re-enables a matching disabled block rule', () async {
      final store = ShieldSettingsStore(box: _MemoryBox());
      await store.save(
        ShieldRuleSet(
          rules: [
            _rule(
              type: ShieldRuleType.roomId,
              pattern: '987654321',
            ).copyWith(enabled: false),
          ],
        ),
      );

      final enabledRule = await store.addQuickActionRule(
        type: ShieldRuleType.roomId,
        scope: ShieldScope.live,
        pattern: '987654321',
      );

      expect(enabledRule, isNotNull);
      expect(enabledRule!.enabled, isTrue);
      expect(store.snapshot().rules, hasLength(1));
      expect(store.snapshot().rules.single.enabled, isTrue);
    });
  });
}

ShieldRule _rule({
  required ShieldRuleType type,
  required String pattern,
  ShieldMatchMode mode = ShieldMatchMode.exact,
}) => ShieldRule(
  id: '$type-$pattern',
  type: type,
  matchMode: mode,
  scope: ShieldScope.live,
  action: ShieldAction.block,
  pattern: pattern,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
);

class _MemoryBox implements ShieldSettingsBox {
  final Map<String, Object?> values = {};

  @override
  Object? get(String key, {Object? defaultValue}) => values[key] ?? defaultValue;

  @override
  Future<void> put(String key, Object? value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
