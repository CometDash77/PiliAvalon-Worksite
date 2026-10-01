import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data_list_item.dart';
import 'package:PiliPlus/pages/live/live_card_shield_quick_action.dart';
import 'package:PiliPlus/pages/live/widgets/live_item_app.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as testing show testWidgets;
import 'package:get/get.dart';

void main() {
  testWidgets('each standalone live card has a separate shield choice', (
    tester,
  ) async {
    await _pump(tester, LiveCardVApp(item: CardLiveItem(uid: 42, roomid: 7)));
    expect(find.byKey(const Key('live-card-shield-button')), findsNothing);

    await _pump(
      tester,
      LiveCardVApp(
        item: CardLiveItem(uid: 42, roomid: 7),
        enableShield: true,
        shieldStore: ShieldSettingsStore(box: _MemoryBox()),
        onRuleSaved: () async {},
      ),
    );

    expect(find.byKey(const Key('live-card-shield-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('live-card-shield-button')));
    await tester.pumpAndSettle();

    expect(find.text('屏蔽主播'), findsOneWidget);
    expect(find.text('屏蔽房间'), findsOneWidget);
  });

  testWidgets('choosing room saves an exact live room-ID rule', (
    tester,
  ) async {
    final box = _MemoryBox();
    final store = ShieldSettingsStore(box: box);
    var refreshCount = 0;
    await _pump(
      tester,
      _ChoiceLauncher(
        store: store,
        onRuleSaved: () async {
          refreshCount++;
        },
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('live-shield-room')));
    await tester.pumpAndSettle();

    final rules = (await store.load()).rules;
    expect(rules, hasLength(1));
    expect(rules.single.type, ShieldRuleType.roomId);
    expect(rules.single.matchMode, ShieldMatchMode.exact);
    expect(rules.single.scope, ShieldScope.live);
    expect(rules.single.pattern, '7');
    expect(refreshCount, 1);
  });

  testWidgets('choosing host saves an exact live UID rule', (tester) async {
    final store = ShieldSettingsStore(box: _MemoryBox());
    var refreshCount = 0;
    await _pump(
      tester,
      _ChoiceLauncher(
        store: store,
        onRuleSaved: () async {
          refreshCount++;
        },
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('live-shield-host')));
    await tester.pumpAndSettle();

    final rule = (await store.load()).rules.single;
    expect(rule.type, ShieldRuleType.uid);
    expect(rule.matchMode, ShieldMatchMode.exact);
    expect(rule.scope, ShieldScope.live);
    expect(rule.pattern, '42');
    expect(refreshCount, 1);
  });

  testWidgets('host quick action stores an exact live UID rule', (
    tester,
  ) async {
    await _pump(tester, const SizedBox.shrink());
    final store = ShieldSettingsStore(box: _MemoryBox());
    var refreshCount = 0;

    await LiveCardShieldQuickAction.addHostRule(
      store: store,
      uid: 42,
      onRuleSaved: () async {
        refreshCount++;
      },
    );

    final rule = (await store.load()).rules.single;
    expect(rule.type, ShieldRuleType.uid);
    expect(rule.matchMode, ShieldMatchMode.exact);
    expect(rule.scope, ShieldScope.live);
    expect(rule.pattern, '42');
    expect(refreshCount, 1);
  });

  testWidgets('duplicate creation still refreshes the visible live list', (
    tester,
  ) async {
    await _pump(tester, const SizedBox.shrink());
    final store = ShieldSettingsStore(box: _MemoryBox());
    var refreshCount = 0;
    await LiveCardShieldQuickAction.addHostRule(
      store: store,
      uid: 42,
      onRuleSaved: () async {
        refreshCount++;
      },
    );
    await LiveCardShieldQuickAction.addHostRule(
      store: store,
      uid: 42,
      onRuleSaved: () async {
        refreshCount++;
      },
    );

    expect((await store.load()).rules, hasLength(1));
    expect(refreshCount, 2);
  });

  testWidgets('save failure leaves the visible cards unchanged', (
    tester,
  ) async {
    await _pump(tester, const SizedBox.shrink());
    final box = _MemoryBox()..failRuleWrites = true;
    final store = ShieldSettingsStore(box: box);
    final visibleCards = ['42', '99'];
    final before = [...visibleCards];

    final saved = await LiveCardShieldQuickAction.addHostRule(
      store: store,
      uid: 42,
      onRuleSaved: () async {
        visibleCards.removeWhere((uid) => uid == '42');
      },
    );

    expect(saved, isFalse);
    expect(visibleCards, before);
    expect((await store.load()).rules, isEmpty);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  GetMaterialApp(
    builder: FlutterSmartDialog.init(),
    home: Scaffold(body: child),
  ),
);

void testWidgets(String description, WidgetTesterCallback callback) {
  testing.testWidgets(description, (tester) async {
    try {
      await callback(tester);
    } finally {
      final dismissal = SmartDialog.dismiss(status: SmartStatus.allToast);
      await tester.pumpAndSettle();
      await dismissal;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}

class _ChoiceLauncher extends StatelessWidget {
  const _ChoiceLauncher({required this.store, required this.onRuleSaved});

  final ShieldSettingsStore store;
  final Future<void> Function() onRuleSaved;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => LiveCardShieldQuickAction.showChoice(
      context: context,
      uid: 42,
      roomId: 7,
      store: store,
      onRuleSaved: onRuleSaved,
    ),
    child: const Text('打开'),
  );
}

class _MemoryBox implements ShieldSettingsBox {
  final values = <String, Object?>{};
  bool failRuleWrites = false;

  @override
  Object? get(String key, {Object? defaultValue}) =>
      values.containsKey(key) ? values[key] : defaultValue;

  @override
  Future<void> put(String key, Object? value) async {
    if (failRuleWrites && key == ShieldSettingsStore.rulesKey) {
      throw StateError('storage unavailable');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
