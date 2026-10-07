import 'dart:io';

import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/dynamics/view.dart';
import 'package:PiliPlus/pages/dynamics/widgets/video_panel.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/zen_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart' as mui;

DynamicItemModel _dynItem() => DynamicItemModel.fromJson({
  'id_str': '1',
  'type': 'DYNAMIC_TYPE_AV',
  'modules': {
    'module_dynamic': {
      'major': {
        'archive': {
          'bvid': 'BV1zenDyn',
          'cover': 'https://example.com/dyn_cover.jpg',
          'duration_text': '05:00',
          'title': '动态视频标题',
          'badge': {'text': '置顶'},
          'stat': {'play': '100', 'danmaku': '50'},
        },
      },
    },
  },
});

// material_ui 分叉自带 TabController/TabBar,测试里用 mui 前缀避免与
// flutter/material 冲突;GlobalMaterialLocalizations.delegates 与生产
// (main.dart:417)一致。
class _StripHarness extends StatefulWidget {
  const _StripHarness();

  @override
  State<_StripHarness> createState() => _StripHarnessState();
}

class _StripHarnessState extends State<_StripHarness>
    with SingleTickerProviderStateMixin {
  late final mui.TabController controller = mui.TabController(
    vsync: this,
    length: DynamicsTabType.values.length,
    initialIndex: 0,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // mui.ColorScheme.of(context) 与 view.dart 同源,类型为 mui ColorScheme。
    return DynamicsTabStrip(
      controllerOf: () => controller,
      colorScheme: mui.ColorScheme.of(context),
      labelStyle: const TextStyle(fontSize: 13),
      onTap: (_) {},
    );
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      final dir = Directory.systemTemp.createTempSync('zen_s5_');
      Hive.init(dir.path);
      GStorage.setting = await Hive.openBox('setting');
      // NetworkImgLayer -> GlobalData -> Pref.blackMids reads localCache.
      GStorage.localCache = await Hive.openBox('localCache');
    } catch (_) {
      // Already initialized by another test file in the same isolate.
    }
  });

  group('dynamics zen tab mapping (spec #42 R14/R17/R18)', () {
    test('zen off keeps the full five-tab order', () {
      final visible = DynamicsController.visibleTabs(zen: false);
      expect(visible, DynamicsTabType.values);
      expect(visible.map((e) => e.name).toList(), [
        'all',
        'video',
        'pgc',
        'article',
        'up',
      ]);
    });

    test('zen on leaves only the video tab (R14)', () {
      expect(DynamicsController.visibleTabs(zen: true), const [
        DynamicsTabType.video,
      ]);
    });

    test('initial index clamps into the visible range (R17)', () {
      expect(DynamicsController.initialIndexFor(3, zen: false), 3);
      expect(DynamicsController.initialIndexFor(3, zen: true), 0);
      expect(DynamicsController.initialIndexFor(99, zen: false), 4);
      expect(DynamicsController.initialIndexFor(-1, zen: false), 0);
    });

    test('jump target remaps into the visible list (R17)', () {
      expect(DynamicsController.jumpTargetFor(-1, zen: false), 0);
      expect(DynamicsController.jumpTargetFor(-1, zen: true), 0);
      // UP tab lives at index 4 outside Zen and does not exist in Zen.
      expect(DynamicsController.jumpTargetFor(7, zen: false), 4);
      expect(DynamicsController.jumpTargetFor(7, zen: true), 0);
    });

    test('tag lookup uses the visible list, not a truncation (R17)', () {
      expect(DynamicsController.tagForIndex(0, zen: false), 'all');
      expect(DynamicsController.tagForIndex(4, zen: false), 'up');
      expect(DynamicsController.tagForIndex(0, zen: true), 'video');
    });
  });

  group('dynamics tab strip widget (spec #42 R15/R18)', () {
    testWidgets('strip hides while zen is on and restores after', (
      tester,
    ) async {
      // mui.Theme/MaterialLocalizations 由 mui.MaterialApp 提供,
      // flutter 的 MaterialApp 不注入 mui 的 inherited 主题。
      await tester.pumpWidget(
        const mui.MaterialApp(
          localizationsDelegates: mui.GlobalMaterialLocalizations.delegates,
          home: mui.Scaffold(body: _StripHarness()),
        ),
      );
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('投稿'), findsOneWidget);
      expect(find.text('UP'), findsOneWidget);

      // 同步写 Rx,避免 testWidgets(FakeAsync zone)内触发真实 Hive I/O。
      ZenMode.enabled.value = true;
      await tester.pump();
      expect(find.text('全部'), findsNothing);
      expect(find.text('投稿'), findsNothing);
      expect(find.text('UP'), findsNothing);

      ZenMode.enabled.value = false;
      await tester.pump();
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('投稿'), findsOneWidget);
      expect(find.text('UP'), findsOneWidget);
      addTearDown(() => ZenMode.enabled.value = false);
    });
  });

  group('dynamics video panel zen rendering (spec #42 R16)', () {
    setUp(() {
      ZenMode.enabled.value = false;
    });

    testWidgets('zen keeps play count and hides danmaku + badge overlay', (
      tester,
    ) async {
      await tester.pumpWidget(
        mui.MaterialApp(
          localizationsDelegates: mui.GlobalMaterialLocalizations.delegates,
          home: mui.Scaffold(
            body: Builder(
              builder: (context) => videoSeasonWidget(
                context,
                floor: 1,
                theme: mui.Theme.of(context),
                item: _dynItem(),
                isSave: false,
                isDetail: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('动态视频标题'), findsOneWidget);
      // video_panel.dart:112 渲染 ' $durationText ',时长带前后空格。
      expect(find.textContaining('05:00'), findsOneWidget);
      expect(find.text('100播放'), findsOneWidget);
      expect(find.text('50弹幕'), findsOneWidget);
      expect(find.text('置顶'), findsOneWidget);

      ZenMode.enabled.value = true;
      await tester.pump();
      // 保留:封面+时长+标题+'N播放';隐藏:'N弹幕'+徽标覆盖层。
      expect(find.text('动态视频标题'), findsOneWidget);
      expect(find.textContaining('05:00'), findsOneWidget);
      expect(find.text('100播放'), findsOneWidget);
      expect(find.text('50弹幕'), findsNothing);
      expect(find.text('置顶'), findsNothing);

      ZenMode.enabled.value = false;
      await tester.pump();
      expect(find.text('50弹幕'), findsOneWidget);
      expect(find.text('置顶'), findsOneWidget);
      addTearDown(() => ZenMode.enabled.value = false);
    });
  });
}
