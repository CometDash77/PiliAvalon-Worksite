import 'dart:io';

import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/zen_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart' hide Icons, MaterialApp, Scaffold;

RcmdVideoItemModel _vItem() => RcmdVideoItemModel.fromJson({
  'id': 123,
  'bvid': 'BV1zenV',
  'cid': 456,
  'goto': 'av',
  'pic': 'https://example.com/cover_v.jpg',
  'title': '竖版视频标题',
  'duration': 300,
  'pubdate': 1700000000,
  'owner': {'mid': 1, 'name': '竖版UP主', 'face': ''},
  'stat': {'view': 123, 'danmaku': 45},
  'is_followed': 0,
  'rcmd_reason': {'content': '因为你看过测试关键词'},
});

HotVideoItemModel _hItem() => HotVideoItemModel.fromJson({
  'aid': 321,
  'cid': 654,
  'bvid': 'BV1zenH',
  'pic': 'https://example.com/cover_h.jpg',
  'title': '横版视频标题',
  'duration': 240,
  'pubdate': 1700000000,
  'owner': {'mid': 2, 'name': '横版UP主'},
  'stat': {'view': 77, 'danmaku': 8},
  'rights': {'is_cooperation': 1},
});

// VideoPopupMenu 内的 PopupMenuButton 来自 material_ui,它校验的是
// material_ui 自己的 MaterialLocalizations,生产环境由
// GlobalMaterialLocalizations.delegates(main.dart:417)提供,测试需一致。
Future<void> _pumpCard(WidgetTester tester, Widget card) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: Center(child: card)),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      final dir = Directory.systemTemp.createTempSync('zen_s4_');
      Hive.init(dir.path);
      GStorage.setting = await Hive.openBox('setting');
      // NetworkImgLayer -> GlobalData -> Pref.blackMids reads localCache.
      GStorage.localCache = await Hive.openBox('localCache');
    } catch (_) {
      // Already initialized by another test file in the same isolate.
    }
  });

  group('VideoCardV zen rendering (spec #42 R10-R11)', () {
    testWidgets('default and zen:false render the full card', (tester) async {
      await _pumpCard(
        tester,
        SizedBox(
          width: 300,
          height: 300,
          child: VideoCardV(videoItem: _vItem()),
        ),
      );

      expect(find.text('竖版视频标题'), findsOneWidget);
      expect(find.text('竖版UP主'), findsOneWidget);
      expect(find.text('因为你看过测试关键词'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
      expect(find.byIcon(Icons.subtitles_outlined), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_outlined), findsOneWidget);
    });

    testWidgets('zen:true keeps only cover, duration, title and play count', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        SizedBox(
          width: 300,
          height: 300,
          child: VideoCardV(videoItem: _vItem(), zen: true),
        ),
      );

      expect(find.text('竖版视频标题'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outlined), findsOneWidget);
      // 隐藏:弹幕数/UP名/发布日期/pgc/rcmdReason/动态/已关注/⋯菜单。
      expect(find.text('竖版UP主'), findsNothing);
      expect(find.text('因为你看过测试关键词'), findsNothing);
      expect(find.byIcon(Icons.subtitles_outlined), findsNothing);
      expect(find.byIcon(Icons.more_vert_outlined), findsNothing);
    });
  });

  group('VideoCardH zen rendering (spec #42 R10-R11)', () {
    testWidgets('default and zen:false render the full card', (tester) async {
      await _pumpCard(
        tester,
        SizedBox(
          width: 360,
          height: 120,
          child: VideoCardH(videoItem: _hItem()),
        ),
      );

      expect(find.text('横版视频标题'), findsOneWidget);
      expect(find.textContaining('横版UP主'), findsOneWidget);
      expect(find.text('合作'), findsOneWidget);
      expect(find.text('04:00'), findsOneWidget);
      expect(find.byIcon(Icons.subtitles_outlined), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_outlined), findsOneWidget);
    });

    testWidgets('zen:true keeps only cover, duration, title and play count', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        SizedBox(
          width: 360,
          height: 120,
          child: VideoCardH(videoItem: _hItem(), zen: true),
        ),
      );

      expect(find.text('横版视频标题'), findsOneWidget);
      expect(find.text('04:00'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outlined), findsOneWidget);
      expect(find.textContaining('横版UP主'), findsNothing);
      expect(find.text('合作'), findsNothing);
      expect(find.byIcon(Icons.subtitles_outlined), findsNothing);
      expect(find.byIcon(Icons.more_vert_outlined), findsNothing);
    });
  });

  group('zen is an explicit parameter, never global (spec #42 R11)', () {
    testWidgets('cards ignore a globally ON Zen unless zen:true is passed', (
      tester,
    ) async {
      // Synchronous Rx write: no real I/O inside the FakeAsync zone
      // (ZenMode.set would hang on real Hive I/O there).
      ZenMode.enabled.value = true;
      expect(ZenMode.isOn, isTrue);
      addTearDown(() => ZenMode.enabled.value = false);

      await _pumpCard(
        tester,
        Column(
          children: [
            SizedBox(
              width: 300,
              height: 300,
              child: VideoCardV(videoItem: _vItem()),
            ),
            SizedBox(
              width: 360,
              height: 120,
              child: VideoCardH(videoItem: _hItem()),
            ),
          ],
        ),
      );

      // 未传 zen → 默认 false,即使全局已开也渲染完整卡片。
      expect(find.text('竖版UP主'), findsOneWidget);
      expect(find.textContaining('横版UP主'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_outlined), findsNWidgets(2));
    });
  });
}
