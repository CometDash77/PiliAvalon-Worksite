import 'package:PiliPlus/features/shielding/live_shielding.dart';
import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data_list_item.dart';
import 'package:PiliPlus/pages/live/widgets/live_item_app.dart';
import 'package:PiliPlus/pages/live/widgets/live_shield_button.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as testing show testWidgets;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('LiveShieldButton', () {
    testWidgets('saves a room rule straight from the card entry', (
      tester,
    ) async {
      final store = ShieldSettingsStore(box: _MemoryBox());
      var changes = 0;
      await _pumpButton(
        tester,
        item: _card(),
        store: store,
        onRuleChanged: () => changes++,
      );

      await tester.tap(find.byIcon(Icons.block));
      await tester.pumpAndSettle();

      expect(find.text('屏蔽主播'), findsOneWidget);
      expect(find.text('屏蔽直播间'), findsOneWidget);
      expect(find.text('测试主播'), findsOneWidget);
      expect(find.text('测试直播间'), findsOneWidget);

      await tester.tap(find.text('屏蔽直播间'));
      await tester.pumpAndSettle();

      final rule = (await store.load()).rules.single;
      expect(rule.type, ShieldRuleType.roomId);
      expect(rule.scope, ShieldScope.live);
      expect(rule.matchMode, ShieldMatchMode.exact);
      expect(rule.action, ShieldAction.block);
      expect(rule.pattern, '9527');
      expect(changes, 1);
      expect(find.textContaining('已屏蔽直播间'), findsOneWidget);
    });

    testWidgets('saves a live host rule from the same entry', (tester) async {
      final store = ShieldSettingsStore(box: _MemoryBox());
      var changes = 0;
      await _pumpButton(
        tester,
        item: _card(),
        store: store,
        onRuleChanged: () => changes++,
      );

      await tester.tap(find.byIcon(Icons.block));
      await tester.pumpAndSettle();
      await tester.tap(find.text('屏蔽主播'));
      await tester.pumpAndSettle();

      final rule = (await store.load()).rules.single;
      expect(rule.type, ShieldRuleType.uid);
      expect(rule.scope, ShieldScope.live);
      expect(rule.matchMode, ShieldMatchMode.exact);
      expect(rule.pattern, '1001');
      expect(changes, 1);
      expect(find.textContaining('已屏蔽主播'), findsOneWidget);
    });

    testWidgets('keeps the entry idempotent and still re-filters', (
      tester,
    ) async {
      final store = ShieldSettingsStore(box: _MemoryBox());
      var changes = 0;
      await _pumpButton(
        tester,
        item: _card(),
        store: store,
        onRuleChanged: () => changes++,
      );

      for (var round = 0; round < 2; round++) {
        await tester.tap(find.byIcon(Icons.block));
        await tester.pumpAndSettle();
        await tester.tap(find.text('屏蔽直播间'));
        await tester.pumpAndSettle();
      }

      // The duplicate still re-filters the loaded page, which is what the
      // callback stands for; the notice itself is covered by the unit test.
      expect((await store.load()).rules, hasLength(1));
      expect(changes, 2);
    });

    testWidgets('reports a failed save and leaves the page alone', (
      tester,
    ) async {
      final store = ShieldSettingsStore(box: _ThrowingBox());
      var changes = 0;
      await _pumpButton(
        tester,
        item: _card(),
        store: store,
        onRuleChanged: () => changes++,
      );

      await tester.tap(find.byIcon(Icons.block));
      await tester.pumpAndSettle();
      await tester.tap(find.text('屏蔽直播间'));
      await tester.pumpAndSettle();

      expect(changes, 0);
      expect(find.text(LiveShielding.failureMessage), findsOneWidget);
    });

    testWidgets('offers only the identities the card carries', (tester) async {
      await _pumpButton(tester, item: _card(roomid: null));

      await tester.tap(find.byIcon(Icons.block));
      await tester.pumpAndSettle();

      expect(find.text('屏蔽主播'), findsOneWidget);
      expect(find.text('屏蔽直播间'), findsNothing);
    });

    testWidgets('hides itself when the card carries no identity', (
      tester,
    ) async {
      await _pumpButton(tester, item: _card(uid: 0, roomid: null));

      expect(find.byIcon(Icons.block), findsNothing);
    });

    testWidgets('only surfaces the entry where the page supplies one', (
      tester,
    ) async {
      final card = _card();
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Other live surfaces mount the card without an entry slot.
                SizedBox(
                  width: 200,
                  height: 280,
                  child: LiveCardVApp(item: card),
                ),
                SizedBox(
                  width: 200,
                  height: 280,
                  child: LiveCardVApp(
                    item: card,
                    shieldAction: LiveShieldButton(item: card),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.block), findsOneWidget);
    });
  });
}

Future<void> _pumpButton(
  WidgetTester tester, {
  required CardLiveItem item,
  ShieldSettingsStore? store,
  VoidCallback? onRuleChanged,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      builder: FlutterSmartDialog.init(),
      home: Scaffold(
        body: Center(
          child: LiveShieldButton(
            item: item,
            store: store,
            onRuleChanged: onRuleChanged,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

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

CardLiveItem _card({
  int? uid = 1001,
  int? roomid = 9527,
  String? uname = '测试主播',
  String? title = '测试直播间',
}) => CardLiveItem(uid: uid, roomid: roomid, uname: uname, title: title);

class _MemoryBox implements ShieldSettingsBox {
  final values = <String, Object?>{};

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

class _ThrowingBox implements ShieldSettingsBox {
  @override
  Object? get(String key, {Object? defaultValue}) => defaultValue;

  @override
  Future<void> put(String key, Object? value) =>
      Future<void>.error(StateError('persist failed'));

  @override
  Future<void> delete(String key) async {}
}
