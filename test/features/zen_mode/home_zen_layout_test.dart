import 'dart:io';

import 'package:PiliPlus/pages/home/widgets/zen_mode_toggle.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/zen_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      final dir = Directory.systemTemp.createTempSync('zen_s3_');
      Hive.init(dir.path);
      GStorage.setting = await Hive.openBox('setting');
    } catch (_) {
      // Already initialized by another test file in the same isolate.
    }
  });

  group('homeZenLayout truth table (spec R1-R4, R8; #97 normal-state toggle)', () {
    setUp(() async {
      // Plain test() body: real async zone, Hive write completes.
      await ZenMode.set(false);
    });

    test('zen on: only toggle survives, strip/body blank at any tab count', () {
      for (final tabCount in [1, 3]) {
        final layout = HomeZenLayout.resolve(zen: true, tabCount: tabCount);
        expect(layout.showZenToggle, isTrue, reason: 'tabCount=$tabCount');
        expect(layout.showMessageBadge, isFalse, reason: 'tabCount=$tabCount');
        expect(layout.showUserAvatar, isFalse, reason: 'tabCount=$tabCount');
        expect(layout.showTabStrip, isFalse, reason: 'tabCount=$tabCount');
        expect(layout.showBody, isFalse, reason: 'tabCount=$tabCount');
      }
    });

    test('zen off: toggle stays visible as second entry (#97), chrome restores', () {
      final one = HomeZenLayout.resolve(zen: false, tabCount: 1);
      // 单 tab 时首页本来就用 6px 占位替代 tab 条。
      expect(one.showTabStrip, isFalse);
      // 普通态开关常显:设置之外的第二入口,OFF 时由此进入(#97 决议)。
      expect(one.showZenToggle, isTrue);
      expect(one.showMessageBadge, isTrue);
      expect(one.showUserAvatar, isTrue);
      expect(one.showBody, isTrue);

      final multi = HomeZenLayout.resolve(zen: false, tabCount: 3);
      expect(multi.showTabStrip, isTrue);
      expect(multi.showZenToggle, isTrue);
      expect(multi.showMessageBadge, isTrue);
      expect(multi.showUserAvatar, isTrue);
      expect(multi.showBody, isTrue);
    });
  });

  group('zen home top bar widgets', () {
    testWidgets('toggle always visible; normal-state tap enters and exits zen (#97)', (
      tester,
    ) async {
      // testWidgets body runs in a FakeAsync zone: real Hive I/O only
      // completes inside tester.runAsync (else the await never returns).
      await tester.runAsync(() => ZenMode.set(false));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Obx(() {
              final layout = HomeZenLayout.resolve(
                zen: ZenMode.isOn,
                tabCount: 3,
              );
              return Row(
                children: [
                  if (layout.showZenToggle) const ZenModeToggle(),
                  if (layout.showMessageBadge) const Text('MSG_BADGE'),
                  if (layout.showUserAvatar) const Text('USER_AVATAR'),
                ],
              );
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 普通态:开关常显(#97),角标/头像保持原位。
      expect(find.byIcon(Icons.self_improvement), findsOneWidget);
      expect(find.text('MSG_BADGE'), findsOneWidget);
      expect(find.text('USER_AVATAR'), findsOneWidget);

      // 普通态点开关 → 立即进入 Zen:角标/头像让位,开关仍在(出口)。
      await tester.tap(find.byIcon(Icons.self_improvement));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.self_improvement), findsOneWidget);
      expect(find.text('MSG_BADGE'), findsNothing);
      expect(find.text('USER_AVATAR'), findsNothing);

      // 再点 → 立即退出并还原完整顶栏部件(R8)。
      await tester.tap(find.byIcon(Icons.self_improvement));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.self_improvement), findsOneWidget);
      expect(find.text('MSG_BADGE'), findsOneWidget);
      expect(find.text('USER_AVATAR'), findsOneWidget);

      // 收尾:在真实 zone 完整等待写链落盘,排空 tap 驱动 set 留在 FakeAsync
      // 里的 whenComplete 监听,否则下一个用例的首个 Hive put 会被跨用例卡死
      // (与本组其他用例结尾的 runAsync set 模式保持一致)。
      await tester.runAsync(() => ZenMode.set(false));
    });

    testWidgets('tapping the toggle flips and persists the mode (R8)', (
      tester,
    ) async {
      await tester.runAsync(() => ZenMode.set(false));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: ZenModeToggle())),
        ),
      );
      await tester.pumpAndSettle();
      expect(ZenMode.isOn, isFalse);
      expect(Pref.zenMode, isFalse);

      // onPressed fires ZenMode.set unawaited; let the real Hive write
      // land and the Rx flip inside a runAsync window.
      await tester.tap(find.byIcon(Icons.self_improvement));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(ZenMode.isOn, isTrue);
      expect(Pref.zenMode, isTrue);

      await tester.tap(find.byIcon(Icons.self_improvement));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(ZenMode.isOn, isFalse);
      expect(Pref.zenMode, isFalse);
    });
  });
}
