// Symptom regression for issue #96 / spec #42 R19-R23.
//
// The player's detail surfaces are pumped directly rather than through the
// whole VideoDetailPage, which would drag in media-kit decoding. Network and
// media stay behind the fixtures below; the widgets under test are the real
// ones from production (`PlayerFocus`, `PgcIntroPanel`).

import 'dart:io';

import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/models/common/stat_type.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/new_ep.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/publish.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/result.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/stat.dart';
import 'package:PiliPlus/models_new/video/video_tag/data.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/widgets/intro_detail.dart';
import 'package:PiliPlus/pages/video/widgets/player_focus.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/zen_mode.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  // See dynamics_zen_tabs_test: cap the per-test budget so a wedged pump
  // fails in seconds instead of eating the whole CI job.
  (TestWidgetsFlutterBinding.ensureInitialized()
          as AutomatedTestWidgetsFlutterBinding)
      .defaultTestTimeout = const Timeout(
    Duration(seconds: 120),
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      final dir = Directory.systemTemp.createTempSync('zen_vd_');
      Hive.init(dir.path);
      // `Pref` binds these boxes with `static final` on first access, so they
      // must all exist before anything under test reads a preference.
      GStorage.setting = await Hive.openBox('setting');
      GStorage.localCache = await Hive.openBox('localCache');
      GStorage.video = await Hive.openBox('video');
      GStorage.historyWord = await Hive.openBox('historyWord');
      GStorage.watchProgress = await Hive.openBox<int>('watchProgress');
    } catch (_) {
      // Already initialized by another test file in the same isolate.
    }
  });

  setUp(() {
    ZenMode.enabled.value = false;
  });
  tearDown(() {
    ZenMode.enabled.value = false;
  });

  group('R19: the danmaku keyboard toggle is the one control Zen removes', () {
    testWidgets('Zen on consumes D without writing the preference (R19/R22)', (
      tester,
    ) async {
      await tester.runAsync(
        () => GStorage.setting.put(SettingBoxKey.tempPlayerConf, false),
      );
      final player = PlPlayerController.getInstance();
      final initial = player.enableShowDanmaku.value;
      await tester.runAsync(
        () => GStorage.setting.put(SettingBoxKey.enableShowDanmaku, initial),
      );
      await pumpPlayerFocus(tester, player);

      ZenMode.enabled.value = true;
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await settle(tester);

      expect(
        player.enableShowDanmaku.value,
        initial,
        reason: 'R19 hides the danmaku toggle, so D must be a no-op',
      );
      expect(
        GStorage.setting.get(SettingBoxKey.enableShowDanmaku),
        initial,
        reason: 'R22: Zen never overwrites a user preference',
      );
    });

    testWidgets('D flips the danmaku preference while Zen is off', (
      tester,
    ) async {
      final player = PlPlayerController.getInstance();
      final initial = player.enableShowDanmaku.value;
      await pumpPlayerFocus(tester, player);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await settle(tester);

      expect(player.enableShowDanmaku.value, !initial);
    });
  });

  group('R19/R20/R21: the PGC detail sheet', () {
    testWidgets('Zen off shows danmaku count, publish date and tags', (
      tester,
    ) async {
      await pumpPgcDetail(tester);

      expect(find.byType(StatWidget), findsNWidgets(2), reason: 'play + dm');
      expect(find.text('2024-01-01'), findsOneWidget, reason: 'publish date');
      expect(find.text('标签甲'), findsOneWidget, reason: 'tags');
      expect(find.text('测试番剧'), findsOneWidget, reason: 'title');
      expect(find.text('详情'), findsOneWidget, reason: 'R21 keeps the strip');
    });

    testWidgets('Zen on drops them but keeps title, play count and the strip', (
      tester,
    ) async {
      await pumpPgcDetail(tester);

      ZenMode.enabled.value = true;
      await settle(tester);

      expect(
        statCount(tester, StatType.play),
        1,
        reason: 'R19 retains the play count',
      );
      expect(
        statCount(tester, StatType.danmaku),
        0,
        reason: 'R20 hides the danmaku count',
      );
      expect(find.text('2024-01-01'), findsNothing, reason: 'publish date');
      expect(find.text('标签甲'), findsNothing, reason: 'R20 hides tags');
      expect(find.text('测试番剧'), findsOneWidget, reason: 'title kept');
      expect(find.text('简介正文'), findsOneWidget, reason: 'R21 keeps 简介');
      expect(find.text('详情'), findsOneWidget, reason: 'R21 keeps the strip');
      expect(find.text('点评'), findsOneWidget, reason: 'R21 keeps the strip');
    });

    testWidgets('Zen off restores every surface exactly as before', (
      tester,
    ) async {
      await pumpPgcDetail(tester);

      ZenMode.enabled.value = true;
      await settle(tester);
      ZenMode.enabled.value = false;
      await settle(tester);

      expect(find.byType(StatWidget), findsNWidgets(2));
      expect(find.text('2024-01-01'), findsOneWidget);
      expect(find.text('标签甲'), findsOneWidget);
      expect(find.text('测试番剧'), findsOneWidget);
      expect(find.text('详情'), findsOneWidget);
    });
  });
}

int statCount(WidgetTester tester, StatType type) => find
    .byWidgetPredicate(
      (widget) => widget is StatWidget && widget.type == type,
      skipOffstage: false,
    )
    .evaluate()
    .length;

Future<void> pumpPlayerFocus(
  WidgetTester tester,
  PlPlayerController player,
) async {
  await tester.pumpWidget(
    GetMaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: PlayerFocus(
          plPlayerController: player,
          onSendDanmaku: () {},
          canToggleDanmaku: () => !ZenMode.isOn,
          child: const SizedBox(width: 200, height: 200),
        ),
      ),
    ),
  );
  // `Focus(autofocus: true)` only claims focus on a later frame.
  await tester.pump();
  await tester.pump();
}

PgcInfoModel get _pgcFixture => PgcInfoModel(
  title: '测试番剧',
  stat: PgcStat.fromJson(const {'views': 1234, 'danmakus': 56}),
  publish: Publish(pubTimeShow: '2024-01-01'),
  newEp: NewEp(desc: '更新至第2话'),
  evaluate: '简介正文',
);

Future<void> pumpPgcDetail(WidgetTester tester) async {
  await tester.pumpWidget(
    GetMaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: PgcIntroPanel(
          item: _pgcFixture,
          enableSlide: false,
          videoTags: [
            VideoTagItem(tagId: 1, tagName: '标签甲', tagType: 'dag'),
          ],
        ),
      ),
    ),
  );
  await settle(tester);
}

/// Bounded pump loop instead of `pumpAndSettle`: these page trees host
/// tickers that can run indefinitely, and an unbounded settle turns into a
/// multi-minute hang.
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
