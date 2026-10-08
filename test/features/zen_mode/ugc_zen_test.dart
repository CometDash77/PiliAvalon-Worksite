// R19/R20/R21 coverage for the real UGC intro subtree (plan section 4,
// step 3). The panel is pumped directly rather than through VideoDetailPage,
// which would drag in media-kit decoding; the widget under test is the real
// production `UgcIntroPanel`, and every fixture stops at the network/media
// boundary exactly as the behavioural suites do.
//
// Every surface R20 names is forced ON in the baseline (`enableAi`,
// `enableOnlineTotal`, `alwaysExpandIntroPanel`, anonymity), otherwise a
// "hidden under Zen" assertion below would be vacuously true.

import 'dart:io';

import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/models/common/stat_type.dart';
import 'package:PiliPlus/models/common/video/source_type.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models/user/info.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/models_new/video/video_tag/data.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/view.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/action_item.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/page.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/zen_mode.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
// Fork of Flutter's material library: `UgcIntroPanel` is built from it, so it
// supplies the `MaterialLocalizations` its subtree resolves.
import 'package:material_ui/material_ui.dart';

import 'dynamics_zen_tabs_test.dart' as dyn;

const String _heroTag = 'zen-ugc-hero';

const int _pubdate = 1704067200;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  (TestWidgetsFlutterBinding.instance as AutomatedTestWidgetsFlutterBinding)
      .defaultTestTimeout = const Timeout(
    Duration(seconds: 120),
  );

  setUpAll(() async {
    try {
      final dir = Directory.systemTemp.createTempSync('zen_ugc_');
      Hive.init(dir.path);
      GStorage.setting = await Hive.openBox('setting');
      GStorage.localCache = await Hive.openBox('localCache');
      GStorage.video = await Hive.openBox('video');
      GStorage.historyWord = await Hive.openBox('historyWord');
      GStorage.watchProgress = await Hive.openBox<int>('watchProgress');
    } catch (_) {
      // Already initialized by another test file in the same isolate.
    }
    try {
      GStorage.regAdapter();
      GStorage.userInfo = await Hive.openBox<UserInfoData>('userInfo');
    } catch (_) {
      // Same isolation guard as above.
    }
    try {
      // `MineController.anonymity` is a `static RxBool` whose initializer reads
      // the `late final Accounts.account` box that app bootstrap normally
      // fills; without it the panel throws LateInitializationError on frame 1.
      await Accounts.init();
    } catch (_) {
      // A `late final` can only be assigned once per isolate.
    }

    // Seed outside the widget test's fake clock: an awaited Hive write there
    // never flushes (see dynamics_zen_tabs_test). These are `late final` on
    // the controller, so they must land before each instance is built.
    await GStorage.setting.put(SettingBoxKey.enableAi, true);
    await GStorage.setting.put(SettingBoxKey.enableOnlineTotal, true);
    await GStorage.setting.put(SettingBoxKey.alwaysExpandIntroPanel, true);
  });

  setUp(() {
    ZenMode.enabled.value = false;
    MineController.anonymity.value = true;
  });
  tearDown(() {
    ZenMode.enabled.value = false;
    MineController.anonymity.value = true;
  });

  group('R19/R20/R21: the UGC intro panel in portrait 400x900', () {
    testWidgets('Zen OFF shows every surface R20 names', (tester) async {
      await setSurface(tester, const Size(400, 900));
      await pumpUgc(tester);

      expect(statCount(tester, StatType.play), 1, reason: 'R19 play count');
      expect(statCount(tester, StatType.danmaku), 1, reason: 'danmaku count');
      expect(find.text(DateFormatUtils.format(_pubdate)), findsOneWidget);
      expect(_bySemanticLabel(tester, '无痕'), findsOneWidget, reason: 'anon');
      expect(find.textContaining('人在看'), findsOneWidget, reason: 'online');
      expect(_bySemanticLabel(tester, 'AI总结'), findsOneWidget);
      expect(find.byType(ActionItem), findsNWidgets(6), reason: 'action row');
      expect(find.text(' 关注 '), findsOneWidget, reason: 'follow button');
      expect(find.text('标签甲'), findsOneWidget, reason: 'tags');
      expect(_title(tester), findsOneWidget);
      expect(_desc(tester), findsOneWidget, reason: 'R21 keeps 简介');
      expect(find.byType(PagesPanel), findsOneWidget, reason: '播放列表');
    });

    testWidgets('Zen ON drops them but keeps title, plays and the panels', (
      tester,
    ) async {
      await setSurface(tester, const Size(400, 900));
      await pumpUgc(tester);

      ZenMode.enabled.value = true;
      await dyn.settle(tester);

      expect(statCount(tester, StatType.play), 1, reason: 'R19 keeps plays');
      expect(statCount(tester, StatType.danmaku), 0, reason: 'R20 danmaku');
      expect(find.text(DateFormatUtils.format(_pubdate)), findsNothing);
      expect(_bySemanticLabel(tester, '无痕'), findsNothing, reason: 'anon');
      expect(find.textContaining('人在看'), findsNothing, reason: 'online');
      expect(_bySemanticLabel(tester, 'AI总结'), findsNothing, reason: 'AI');
      expect(find.byType(ActionItem), findsNothing, reason: 'action row');
      expect(find.text(' 关注 '), findsNothing, reason: 'follow');
      expect(find.text('标签甲'), findsNothing, reason: 'R20 tags');

      expect(_title(tester), findsOneWidget, reason: 'R19 title');
      expect(_desc(tester), findsOneWidget, reason: 'R21 keeps 简介');
      expect(find.byType(PagesPanel), findsOneWidget, reason: 'R21 播放列表');
    });

    testWidgets('OFF -> ON -> OFF restores every surface exactly', (
      tester,
    ) async {
      await setSurface(tester, const Size(400, 900));
      await pumpUgc(tester);

      final before = _snapshot(tester);

      ZenMode.enabled.value = true;
      await dyn.settle(tester);
      ZenMode.enabled.value = false;
      await dyn.settle(tester);

      expect(
        _snapshot(tester),
        before,
        reason: 'turning Zen off must restore the original surface',
      );
    });
  });

  group('R20 in the other required viewports', () {
    testWidgets('landscape 1200x700 hides the owner-row action grid too', (
      tester,
    ) async {
      await setSurface(tester, const Size(1200, 700));
      await pumpUgc(tester, isPortrait: false, isHorizontal: true);

      expect(find.byType(ActionItem), findsNWidgets(6), reason: 'row shown');
      expect(find.text(' 关注 '), findsOneWidget);

      ZenMode.enabled.value = true;
      await dyn.settle(tester);

      expect(find.byType(ActionItem), findsNothing, reason: 'R20 row gone');
      expect(find.text(' 关注 '), findsNothing, reason: 'R20 follow gone');
      expect(statCount(tester, StatType.play), 1, reason: 'R19 plays kept');
      expect(_title(tester), findsOneWidget, reason: 'R19 title kept');
    });

    testWidgets('near-square 800x800 keeps the same gates', (tester) async {
      await setSurface(tester, const Size(800, 800));
      await pumpUgc(tester);

      expect(_bySemanticLabel(tester, 'AI总结'), findsOneWidget);
      expect(find.byType(ActionItem), findsNWidgets(6));

      ZenMode.enabled.value = true;
      await dyn.settle(tester);

      expect(_bySemanticLabel(tester, 'AI总结'), findsNothing);
      expect(find.byType(ActionItem), findsNothing);
      expect(statCount(tester, StatType.play), 1);
      expect(_desc(tester), findsOneWidget, reason: 'R21 keeps 简介');
    });
  });
}

/// Counters that must be identical after an OFF->ON->OFF round trip. Kept as
/// a value list so a drift names itself instead of only "not equal".
List<Object?> _snapshot(WidgetTester tester) => [
  statCount(tester, StatType.play),
  statCount(tester, StatType.danmaku),
  find.byType(ActionItem).evaluate().length,
  find.byType(PagesPanel).evaluate().length,
  find.text(DateFormatUtils.format(_pubdate)).evaluate().length,
  find.text('标签甲').evaluate().length,
  find.text(' 关注 ').evaluate().length,
  _desc(tester).evaluate().length,
  _title(tester).evaluate().length,
];

/// The AI glyph and the incognito icon are only addressable by their
/// semantic label, which lives on the widget rather than in the semantics
/// tree (flutter_test does not attach a SemanticsOwner here).
Finder _bySemanticLabel(WidgetTester tester, String label) =>
    find.byWidgetPredicate(
      (w) =>
          (w is Image && w.semanticLabel == label) ||
          (w is Icon && w.semanticLabel == label),
      skipOffstage: false,
    );

/// The title and 简介 render as rich text, so a plain `find.text` never sees
/// them (see dynamics_zen_tabs_test, R17).
Finder _title(WidgetTester tester) =>
    find.textContaining('竖屏测试标题', findRichText: true);

Finder _desc(WidgetTester tester) =>
    find.textContaining('简介正文甲', findRichText: true);

int statCount(WidgetTester tester, StatType type) => find
    .byWidgetPredicate(
      (widget) => widget is StatWidget && widget.type == type,
      skipOffstage: false,
    )
    .evaluate()
    .length;

Future<void> setSurface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> pumpUgc(
  WidgetTester tester, {
  bool isPortrait = true,
  bool isHorizontal = false,
}) async {
  await _unmount(tester);
  Get.put(AccountService());

  // VideoDetailController.onInit reads these out of `Get.arguments`
  // (lib/pages/video/controller.dart:556-576); `videoType`, `bvid`, `aid`,
  // `cid` and `heroTag` are `late` and must be present.
  Get.routing.args = <String, dynamic>{
    'videoType': VideoType.ugc,
    'sourceType': SourceType.normal,
    'bvid': 'BV1zenugc01',
    'aid': 1,
    'cid': 100,
    'cover': '',
    'heroTag': _heroTag,
    'title': '竖屏测试标题',
    'viewLater': false,
  };

  Get.put(VideoDetailController(), tag: _heroTag);

  final intro = UgcIntroController();
  Get.put(intro, tag: _heroTag);
  // The dio future behind queryVideoIntro never settles on the fake clock, so
  // seeding the value is what moves the panel off its loading skeleton.
  intro.videoDetail.value = VideoDetailData.fromJson(const {
    'bvid': 'BV1zenugc01',
    'aid': 1,
    'cid': 100,
    'videos': 2,
    'title': '竖屏测试标题',
    'pic': '',
    'pubdate': _pubdate,
    'ctime': _pubdate,
    'duration': 75,
    'stat': {
      'view': 12345,
      'danmaku': 67,
      'reply': 8,
      'favorite': 9,
      'coin': 3,
      'share': 2,
      'like': 101,
    },
    'owner': {'mid': 1001, 'name': '测试UP主', 'face': ''},
    // R21 keeps 简介; rendered from descV2, not the plain `desc` field.
    'desc_v2': [
      {'raw_text': '简介正文甲', 'type': 1, 'biz_id': 0},
      {'raw_text': '简介正文乙', 'type': 1, 'biz_id': 0},
    ],
    // R21 keeps the 播放列表 section; it only renders above one page.
    'pages': [
      {'cid': 100, 'page': 1, 'part': '分集一', 'duration': 40},
      {'cid': 101, 'page': 2, 'part': '分集二', 'duration': 35},
    ],
  });
  intro.videoTags.value = [
    VideoTagItem(tagId: 1, tagName: '标签甲', tagType: 'dag'),
  ];

  addTearDown(() async {
    await _unmount(tester);
    Get
      ..delete<VideoDetailController>(tag: _heroTag, force: true)
      ..delete<UgcIntroController>(tag: _heroTag, force: true)
      ..delete<AccountService>(force: true)
      ..deleteAll(force: true);
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      builder: FlutterSmartDialog.init(),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            UgcIntroPanel(
              heroTag: _heroTag,
              showAiBottomSheet: () {},
              showEpisodes: () {},
              onShowMemberPage: (_) {},
              isPortrait: isPortrait,
              isHorizontal: isHorizontal,
            ),
          ],
        ),
      ),
    ),
  );
  await dyn.settle(tester);
}
