import 'dart:convert';

import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/pages/setting/recommend_range_shielding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  group('RecommendRangeShieldingPage', () {
    testWidgets('shows empty state when no range rules exist', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: RecommendRangeShieldingPage(
            store: ShieldSettingsStore(box: _MemoryBox()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('推荐流范围屏蔽'), findsOneWidget);
      expect(find.text('暂无规则'), findsOneWidget);
      expect(find.textContaining('时长、播放数、弹幕数的范围屏蔽规则'), findsOneWidget);
    });

    testWidgets('shows existing recommendation range rules', (tester) async {
      final seed = ShieldRuleSet(
        rules: [
          _rangeRule(
            id: 'dur-short',
            type: ShieldRuleType.duration,
            pattern: '0..30',
            action: ShieldAction.block,
          ),
          _rangeRule(
            id: 'dur-long',
            type: ShieldRuleType.duration,
            pattern: '1200..',
            action: ShieldAction.block,
          ),
        ],
      );
      final store = ShieldSettingsStore(
        box: _MemoryBox({
          ShieldSettingsStore.rulesKey: jsonEncode(seed.toJson()),
        }),
      );

      await tester.pumpWidget(
        GetMaterialApp(home: RecommendRangeShieldingPage(store: store)),
      );
      await tester.pumpAndSettle();

      // Both rules should appear.
      expect(find.textContaining('屏蔽 时长'), findsNWidgets(2));
      expect(find.textContaining('0..30'), findsOneWidget);
      expect(find.textContaining('1200..'), findsOneWidget);

      // Each shows recommendation scope and range mode.
      expect(find.textContaining('推荐'), findsWidgets);
      expect(find.textContaining('数值范围'), findsWidgets);
    });

    testWidgets('filters out non-recommendation and non-range rules',
        (tester) async {
      final seed = ShieldRuleSet(
        rules: [
          _rangeRule(
            id: 'rec-range',
            type: ShieldRuleType.duration,
            pattern: '60..600',
            action: ShieldAction.block,
          ),
          // Non-recommendation scope — should NOT appear.
          _rangeRule(
            id: 'comment-range',
            type: ShieldRuleType.duration,
            pattern: '0..10',
            action: ShieldAction.block,
            scope: ShieldScope.comment,
          ),
          // Non-range mode — should NOT appear.
          ShieldRule(
            id: 'rec-exact',
            type: ShieldRuleType.duration,
            matchMode: ShieldMatchMode.exact,
            scope: ShieldScope.recommendation,
            action: ShieldAction.block,
            pattern: '42',
            enabled: true,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
            source: ShieldRuleSource.manual,
          ),
          // Non-numeric type — should NOT appear.
          _rangeRule(
            id: 'rec-keyword-range',
            type: ShieldRuleType.keyword,
            pattern: '0..10',
            action: ShieldAction.block,
          ),
        ],
      );
      final store = ShieldSettingsStore(
        box: _MemoryBox({
          ShieldSettingsStore.rulesKey: jsonEncode(seed.toJson()),
        }),
      );

      await tester.pumpWidget(
        GetMaterialApp(home: RecommendRangeShieldingPage(store: store)),
      );
      await tester.pumpAndSettle();

      // Only the one recommendation-scope, range-mode, numeric-type rule.
      expect(find.textContaining('60..600'), findsOneWidget);
      expect(find.textContaining('0..10'), findsNothing);
      expect(find.text('42'), findsNothing);
    });

    testWidgets('editor opens pre-configured for recommendation range',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: RecommendRangeShieldingPage(
            store: ShieldSettingsStore(box: _MemoryBox()),
          ),
        ),
      );
      await tester.pump();

      // Tap "add" via FAB tooltip.
      await tester.tap(find.byTooltip('新增').first);
      await tester.pumpAndSettle();

      // Editor should show type dropdown and action dropdown.
      // Should NOT show scope or match mode since they are pre-configured.
      expect(find.text('类型'), findsOneWidget);
      expect(find.text('动作'), findsOneWidget);
      expect(find.text('启用'), findsOneWidget);

      // Should default to duration type.
      expect(find.text('时长'), findsWidgets);

      // Should NOT show scope or match mode dropdowns.
      expect(find.text('作用范围'), findsNothing);
      expect(find.text('匹配方式'), findsNothing);
    });
  });
}

ShieldRule _rangeRule({
  required String id,
  required ShieldRuleType type,
  required String pattern,
  ShieldAction action = ShieldAction.block,
  ShieldScope scope = ShieldScope.recommendation,
}) => ShieldRule(
  id: id,
  type: type,
  matchMode: ShieldMatchMode.range,
  scope: scope,
  action: action,
  pattern: pattern,
  enabled: true,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
  source: ShieldRuleSource.manual,
);

class _MemoryBox implements ShieldSettingsBox {
  _MemoryBox([Map<String, Object?>? values]) : values = values ?? {};

  final Map<String, Object?> values;

  @override
  Object? get(String key, {Object? defaultValue}) =>
      values.containsKey(key) ? values[key] : defaultValue;

  @override
  Future<void> put(String key, Object? value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
