// Symptom regression for issue #96 / spec #42 R14-R18.
//
// Every case pumps the *real* DynamicsPage against registered test
// controllers whose HTTP layer returns fixed fixtures, so the tab strip, the
// tab bookkeeping, the five UP-panel layouts and the dynamics cards are all
// production widgets. Network and media stay at the fixture boundary only.

import 'dart:io';

import 'package:PiliPlus/common/widgets/svg/play_icon.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/common/dynamic/up_panel_position.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/models/dynamics/up.dart';
import 'package:PiliPlus/models/user/info.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/dynamics/view.dart';
import 'package:PiliPlus/pages/dynamics/widgets/dynamic_panel.dart';
import 'package:PiliPlus/pages/dynamics/widgets/up_panel.dart';
import 'package:PiliPlus/pages/dynamics_tab/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/zen_mode.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  (TestWidgetsFlutterBinding.ensureInitialized()
          as AutomatedTestWidgetsFlutterBinding)
      .defaultTestTimeout = const Timeout(
    Duration(seconds: 30),
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      final dir = Directory.systemTemp.createTempSync('zen_dyn_');
      Hive.init(dir.path);
      // `Pref` binds these boxes with `static final` on first access, so they
      // must all exist before anything in the page reads a preference.
      GStorage.setting = await Hive.openBox('setting');
      GStorage.localCache = await Hive.openBox('localCache');
      GStorage.video = await Hive.openBox('video');
      GStorage.historyWord = await Hive.openBox('historyWord');
      GStorage.watchProgress = await Hive.openBox<int>('watchProgress');
    } catch (_) {
      // Already initialized by another test file in the same isolate.
    }
    try {
      // AccountService.onInit reads the typed `userInfo` box.
      GStorage.regAdapter();
      GStorage.userInfo = await Hive.openBox<UserInfoData>('userInfo');
    } catch (_) {
      // Same isolation guard as above.
    }
  });

  setUp(() {
    ZenMode.enabled.value = false;
  });

  group('R14-R18 tab strip on the real DynamicsPage', () {
    testWidgets('zen OFF keeps all five tabs and shows the all feed', (
      tester,
    ) async {
      await pumpDynamicsPage(tester);

      final tabBarFinder = find.byType(TabBar);
      expect(tabBarFinder, findsOneWidget);
      final tabBar = tester.widget<TabBar>(tabBarFinder);
      expect(
        tabBar.tabs.map((tab) => (tab as Tab).text),
        ['全部', '投稿', '番剧', '专栏', 'UP'],
      );
      expect(find.text('视频甲'), findsOneWidget);
      expect(find.byType(DynamicPanel), findsNWidgets(2));
    });

    testWidgets('zen ON collapses to the 投稿 tab only (R14/R15)', (
      tester,
    ) async {
      await pumpDynamicsPage(tester);

      await setZen(tester, true);

      expect(find.byType(TabBar), findsNothing, reason: 'R15 hides the strip');
      for (final label in ['全部', '投稿', '番剧', '专栏', 'UP']) {
        expect(find.text(label), findsNothing, reason: 'R14 hides $label');
      }
      // Only the 投稿 page survives, and it must be the *video* page, not the
      // state-reused 全部 page that occupies the same slot in the TabBarView.
      expect(find.text('视频丙'), findsOneWidget, reason: 'video feed shown');
      expect(find.text('视频甲'), findsNothing, reason: 'all feed gone');
      expect(
        find.byType(DynamicPanel),
        findsNothing,
        reason: 'cards simplified',
      );
    });

    testWidgets('zen OFF again restores the five tabs and the prior feed', (
      tester,
    ) async {
      await pumpDynamicsPage(tester);

      await setZen(tester, true);
      await setZen(tester, false);

      expect(find.byType(TabBar), findsOneWidget);
      for (final label in ['全部', '投稿', '番剧', '专栏', 'UP']) {
        expect(find.text(label), findsOneWidget, reason: 'tab $label');
      }
      expect(find.text('视频甲'), findsOneWidget);
      expect(find.byType(DynamicPanel), findsNWidgets(2));
    });

    testWidgets('the selected 专栏 tab survives a zen round trip (R17)', (
      tester,
    ) async {
      await pumpDynamicsPage(tester);

      await tester.tap(find.text('专栏'));
      await settle(tester);
      final dynamicsController = Get.find<DynamicsController>();
      expect(dynamicsController.tabController.length, 5);
      expect(
        dynamicsController.tabController.index,
        DynamicsTabType.article.index,
        reason: 'the article tab is selected before Zen collapses it',
      );

      await setZen(tester, true);
      expect(find.byType(TabBar), findsNothing);

      await setZen(tester, false);
      expect(find.byType(TabBar), findsOneWidget);
      expect(
        dynamicsController.tabController.index,
        DynamicsTabType.article.index,
        reason: 'the article selection is restored',
      );
      expect(find.text('视频甲'), findsNothing, reason: 'not back on 全部');

      expect(
        GStorage.setting.get(SettingBoxKey.defaultDynamicType),
        isNull,
        reason: 'zen must never persist a new default index',
      );
    });

    testWidgets('a page born under zen falls back to the clamped default', (
      tester,
    ) async {
      ZenMode.enabled.value = true;
      await pumpDynamicsPage(tester);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('视频丙'), findsOneWidget);

      await setZen(tester, false);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('视频甲'), findsOneWidget);
    });

    for (final (label, stored) in [
      ('negative', -1),
      ('zero', 0),
      ('last', 4),
      ('out of range', 99),
    ]) {
      test('stored default index $label ($stored) is clamped', () {
        final index = DynamicsController.initialIndexFor(stored, zen: false);
        expect(index, inInclusiveRange(0, 4));
      });
    }

    testWidgets('repeated zen toggles rebuild cleanly every time', (
      tester,
    ) async {
      await pumpDynamicsPage(tester);

      for (var i = 0; i < 4; i++) {
        await setZen(tester, true);
        expect(find.byType(TabBar), findsNothing, reason: 'toggle $i ON');
        expect(find.text('视频丙'), findsOneWidget);
        await setZen(tester, false);
        expect(find.byType(TabBar), findsOneWidget, reason: 'toggle $i OFF');
        expect(find.text('视频甲'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a same-frame unmount during a zen toggle stays clean', (
      tester,
    ) async {
      await pumpDynamicsPage(tester);
      final controller = Get.find<DynamicsController>();

      await setZen(tester, true);
      ZenMode.enabled.value = false;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Closing must cancel the zen worker: after the controller is gone a
      // zen flip must not rebuild a tab controller on a dead instance.
      Get.delete<DynamicsController>(force: true);
      final before = controller.tabController;
      ZenMode.enabled.value = true;
      await tester.pump();
      await tester.pump();
      expect(controller.tabController, same(before));
      expect(tester.takeException(), isNull);
    });
  });

  group('R16 dynamics video card simplification', () {
    testWidgets('zen OFF renders the full DynamicPanel card', (tester) async {
      await pumpDynamicsPage(tester);
      await tester.tap(find.text('投稿'));
      await settle(tester);

      expect(find.byType(DynamicPanel), findsWidgets);
      expect(find.text('测试UP主'), findsWidgets);
      expect(find.textContaining('01:23'), findsWidgets);
      expect(find.text('123播放'), findsWidgets);
      expect(find.text('45弹幕'), findsWidgets);
      expect(find.text('充电专属'), findsWidgets);
      expect(find.byType(PlayIcon), findsWidgets);
    });

    testWidgets('zen ON strips the card to cover, duration, title, plays', (
      tester,
    ) async {
      await pumpDynamicsPage(tester);
      await tester.tap(find.text('投稿'));
      await settle(tester);

      await setZen(tester, true);

      expect(find.byType(DynamicPanel), findsNothing);
      expect(
        find.byWidgetPredicate((widget) {
          if (widget is! Container) return false;
          final decoration = widget.decoration;
          return decoration is BoxDecoration &&
              decoration.gradient is LinearGradient;
        }),
        findsNothing,
        reason: 'R16 removes the cover gradient overlay',
      );
      expect(find.text('测试UP主'), findsNothing, reason: 'no author');
      expect(find.text('动态正文内容'), findsNothing, reason: 'no body');
      expect(
        find.textContaining('01:23'),
        findsWidgets,
        reason: 'duration kept',
      );
      expect(find.text('123播放'), findsWidgets, reason: 'play count kept');
      expect(find.text('视频丙'), findsWidgets, reason: 'title kept');
      expect(find.text('45弹幕'), findsNothing, reason: 'R16 hides danmaku');
      expect(find.text('充电专属'), findsNothing, reason: 'R16 hides badge');
      expect(find.byType(PlayIcon), findsNothing, reason: 'R16 hides overlay');
      expect(find.text('11'), findsNothing, reason: 'no interaction row');
      expect(find.text('7'), findsNothing, reason: 'no comment count');
    });

    testWidgets('zen OFF restores the original dynamic card layout', (
      tester,
    ) async {
      await pumpDynamicsPage(tester);
      await tester.tap(find.text('投稿'));
      await settle(tester);
      await setZen(tester, true);
      await setZen(tester, false);

      expect(find.byType(DynamicPanel), findsWidgets);
      expect(find.text('测试UP主'), findsWidgets);
      expect(find.text('45弹幕'), findsWidgets);
      expect(find.byType(PlayIcon), findsWidgets);
    });
  });

  group('R14 UP panel across all five upPanelPosition values', () {
    for (final position in UpPanelPosition.values) {
      testWidgets('${position.name}: zen hides the panel and its buttons', (
        tester,
      ) async {
        await pumpDynamicsPage(tester, upPanelPosition: position);

        final panelHost = switch (position) {
          UpPanelPosition.leftDrawer => find.byType(DrawerButton),
          UpPanelPosition.rightDrawer => find.byType(EndDrawerButton),
          _ => find.byType(UpPanel, skipOffstage: false),
        };
        expect(
          panelHost,
          findsOneWidget,
          reason: '${position.name} exposes its UP panel host while OFF',
        );

        await setZen(tester, true);

        expect(
          find.byType(UpPanel, skipOffstage: false),
          findsNothing,
          reason: '${position.name} hides the UP panel while ON',
        );
        expect(find.byType(DrawerButton), findsNothing);
        expect(find.byType(EndDrawerButton), findsNothing);
        expect(
          find.byIcon(Icons.add),
          findsOneWidget,
          reason: 'the publish-dynamics button keeps its behaviour',
        );

        await setZen(tester, false);

        expect(
          panelHost,
          findsOneWidget,
          reason: '${position.name} restores its UP panel host while OFF',
        );
        expect(find.byIcon(Icons.add), findsOneWidget);
      });
    }
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Bounded pump loop instead of `pumpAndSettle`: this page tree hosts
/// tickers that can run indefinitely, and an unbounded settle turns into a
/// multi-minute hang. A fixed budget of 100ms frames is plenty for the
/// tab-swap animations and the fixture futures (resolved as microtasks).
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> setZen(WidgetTester tester, bool value) async {
  ZenMode.enabled.value = value;
  await settle(tester);
}

Future<void> pumpDynamicsPage(
  WidgetTester tester, {
  UpPanelPosition? upPanelPosition,
}) async {
  tester.view.physicalSize = const Size(900, 1000);
  tester.view.devicePixelRatio = 1.0;
  // Keep the fixture viewport stable across the test process.

  // Unmount anything a previous case left behind before touching Hive.
  // Production widgets can leave a short-lived preference write in flight.
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  deleteControllers();

  // The fixture injects the panel position directly, so this path has no
  // storage writes and remains deterministic across widget tests.
  registerControllers(upPanelPosition: upPanelPosition);

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    deleteControllers();
  });

  await tester.pumpWidget(
    GetMaterialApp(
      theme: ThemeData(useMaterial3: true),
      builder: FlutterSmartDialog.init(),
      home: const DynamicsPage(),
    ),
  );
  await settle(tester);
}

void registerControllers({UpPanelPosition? upPanelPosition}) {
  deleteControllers();
  Get
    ..put<AccountService>(AccountService())
    ..put<MainController>(StubMainController())
    ..put<DynamicsController>(
      StubDynamicsController(upPanelPosition: upPanelPosition),
    );
  for (final entry in fixtures.entries) {
    Get.put<DynamicsTabController>(
      StubDynamicsTabController(dynamicsType: entry.key, items: entry.value),
      tag: entry.key.name,
    );
  }
}

void deleteControllers() {
  for (final type in DynamicsTabType.values) {
    Get.delete<DynamicsTabController>(tag: type.name, force: true);
  }
  Get
    ..delete<DynamicsController>(force: true)
    ..delete<MainController>(force: true)
    ..delete<AccountService>(force: true);
}

// --- fixtures --------------------------------------------------------------

DynamicItemModel videoItem({required String title}) {
  final item = DynamicItemModel.fromJson({
    'id_str': '900001',
    'type': 'DYNAMIC_TYPE_AV',
    'modules': <String, dynamic>{},
  });
  item.modules
    ..moduleAuthor = ModuleAuthorModel.fromJson({
      'mid': 1001,
      'name': '测试UP主',
      'face': '',
    })
    ..moduleStat = ModuleStatModel(
      forward: DynamicStat(count: 3, status: false),
      comment: DynamicStat(count: 7, status: false),
      like: DynamicStat(count: 11, status: false),
    )
    ..moduleDynamic = ModuleDynamicModel(
      desc: DynamicDescModel(text: '动态正文内容'),
      major: DynamicMajorModel(
        type: 'MAJOR_TYPE_ARCHIVE',
        archive: DynamicArchiveModel.fromJson({
          'aid': 1,
          'title': title,
          'cover': '',
          'duration_text': '01:23',
          'badge': {'text': '充电专属'},
          'stat': {'play': '123', 'danmaku': '45'},
          'jump_url': 'bilibili://video/1',
        }),
      ),
    );
  return item;
}

DynamicItemModel articleItem({required String title}) {
  final item = DynamicItemModel.fromJson({
    'id_str': '900002',
    'type': 'DYNAMIC_TYPE_ARTICLE',
    'modules': <String, dynamic>{},
  });
  item.modules
    ..moduleAuthor = ModuleAuthorModel.fromJson({
      'mid': 1001,
      'name': '测试UP主',
      'face': '',
    })
    ..moduleStat = ModuleStatModel(
      forward: DynamicStat(count: 1, status: false),
      comment: DynamicStat(count: 5, status: false),
      like: DynamicStat(count: 9, status: false),
    )
    ..moduleDynamic = ModuleDynamicModel(desc: DynamicDescModel(text: title));
  return item;
}

Map<DynamicsTabType, List<DynamicItemModel>> get fixtures => {
  DynamicsTabType.all: [
    videoItem(title: '视频甲'),
    articleItem(title: '专栏乙'),
  ],
  DynamicsTabType.video: [videoItem(title: '视频丙')],
  DynamicsTabType.pgc: <DynamicItemModel>[],
  DynamicsTabType.article: [articleItem(title: '专栏乙')],
  DynamicsTabType.up: <DynamicItemModel>[],
};

// --- stub controllers (HTTP replaced by fixtures) --------------------------

class StubDynamicsController extends DynamicsController {
  StubDynamicsController({super.upPanelPosition});

  @override
  Future<LoadingState<FollowUpModel>> customGetData() async => Success(
    FollowUpModel.fromUpList(null)
      ..upList = [
        UpItem(face: '', uname: '示例UP', mid: 4242),
        UpItem(face: '', uname: '另一UP', mid: 4343),
      ]
      ..hasMore = false,
  );
}

class StubDynamicsTabController extends DynamicsTabController {
  StubDynamicsTabController({required super.dynamicsType, required this.items});

  final List<DynamicItemModel> items;

  @override
  Future<void> onLoadMore() => Future.value();

  @override
  Future<LoadingState<DynamicsDataModel>> customGetData() async => Success(
    // Return a fresh page list so the common paginator never self-appends
    // the same fixture list during the last-item load-more callback.
    DynamicsDataModel.fromJson(const {'has_more': false})
      ..items = items.toList(),
  );
}

class StubMainController extends MainController {
  @override
  // Deliberately skipped: the real onInit fires update-check and unread-badge
  // HTTP, which have no place behind these fixtures.
  // ignore: must_call_super
  void onInit() {
    navigationBars = [NavigationBarType.dynamics, NavigationBarType.home];
    selectedIndex.value = 0;
    useBottomNav = false;
    controller = PageController(initialPage: 0);
  }
}
