// Visual smoke for issue #96 / spec #42 R14-R23 (plan section 5, step 5).
//
// It renders the *real* production subtrees with Zen OFF and ON and writes a
// PNG for each state so the two can be inspected side by side for cropping,
// blank areas and retained controls. Fixtures stop at the network/media
// boundary, exactly as the behavioural suites do.
//
// Temporary harness: run only with `--update-goldens` (ci.yml on the smoke
// branch points `flutter test` at this file). The PNGs it writes are evidence
// and are never committed.

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/video/source_type.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/models/user/info.dart';
import 'package:PiliPlus/pages/dynamics/view.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/view.dart';
import 'package:PiliPlus/pages/video/related/controller.dart';
import 'package:PiliPlus/pages/video/related/view.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/zen_mode.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

import 'dynamics_zen_tabs_test.dart' as dyn;

import 'dart:io';

/// One literal tag for the whole fixture cluster: in production `heroTag` is
/// randomised per navigation, but here it is the GetX instance tag that ties
/// VideoDetailController, UgcIntroController and RelatedController together.
const String _heroTag = 'zen-smoke-hero';

/// The RepaintBoundary each golden is captured from, so every PNG is the same
/// subtree rather than whatever element a byType lookup happens to land on.
const Key _boundary = Key('zen-smoke-boundary');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  (TestWidgetsFlutterBinding.instance as AutomatedTestWidgetsFlutterBinding)
      .defaultTestTimeout = const Timeout(
    Duration(seconds: 120),
  );

  setUpAll(() async {
    try {
      final dir = Directory.systemTemp.createTempSync('zen_smoke_');
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
    await GStorage.setting.delete(SettingBoxKey.defaultDynamicType);
    await GStorage.setting.put(
      SettingBoxKey.upPanelPosition,
      1, // UpPanelPosition.leftFixed
    );
  });

  setUp(dyn.resetPrefs);
  tearDown(dyn.resetPrefs);

  // --- surface 1: dynamics, portrait 400x900 ------------------------------

  testWidgets('dynamics portrait Zen OFF', (tester) async {
    await setSurface(tester, const Size(400, 900));
    await pumpDynamics(tester);
    await capture(tester, 'dynamics_off');
  });

  testWidgets('dynamics portrait Zen ON', (tester) async {
    await setSurface(tester, const Size(400, 900));
    await pumpDynamics(tester);
    ZenMode.enabled.value = true;
    await dyn.settle(tester);
    await capture(tester, 'dynamics_on');
  });

  // --- surface 2: UGC intro, portrait 400x900 -----------------------------

  testWidgets('ugc intro portrait Zen OFF', (tester) async {
    await setSurface(tester, const Size(400, 900));
    await pumpUgcIntro(tester);
    await capture(tester, 'ugc_off');
  });

  testWidgets('ugc intro portrait Zen ON', (tester) async {
    await setSurface(tester, const Size(400, 900));
    await pumpUgcIntro(tester);
    ZenMode.enabled.value = true;
    await dyn.settle(tester);
    await capture(tester, 'ugc_on');
  });

  // --- surface 3: related list detail, landscape 1200x700 -----------------

  testWidgets('related list landscape Zen OFF', (tester) async {
    await setSurface(tester, const Size(1200, 700));
    await pumpRelated(tester);
    await capture(tester, 'related_off');
  });

  testWidgets('related list landscape Zen ON', (tester) async {
    await setSurface(tester, const Size(1200, 700));
    await pumpRelated(tester);
    ZenMode.enabled.value = true;
    await dyn.settle(tester);
    await capture(tester, 'related_on');
  });
}

Future<void> setSurface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> capture(WidgetTester tester, String name) async {
  await expectLater(
    find.byKey(_boundary),
    matchesGoldenFile('goldens/$name.png'),
  );
}

Widget _root(Widget home) => RepaintBoundary(
  key: _boundary,
  child: MaterialApp(
    theme: ThemeData(useMaterial3: true),
    builder: FlutterSmartDialog.init(),
    home: home,
  ),
);

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

/// DynamicsPage needs the stubbed HTTP controllers registered first; the
/// fixtures and stubs live in the behavioural suite so both stay in step.
Future<void> pumpDynamics(WidgetTester tester) async {
  await _unmount(tester);
  dyn.registerControllers();
  addTearDown(() async {
    await _unmount(tester);
    dyn.deleteControllers();
  });

  await tester.pumpWidget(_root(const DynamicsPage()));
  await dyn.settle(tester);
}

Future<void> pumpUgcIntro(WidgetTester tester) async {
  await _unmount(tester);
  Get.put(AccountService());

  // VideoDetailController.onInit reads these out of `Get.arguments`
  // (lib/pages/video/controller.dart:556-576); `videoType`, `bvid`, `aid`,
  // `cid` and `heroTag` are `late` and must be present.
  Get.routing.args = <String, dynamic>{
    'videoType': VideoType.ugc,
    'sourceType': SourceType.normal,
    'bvid': 'BV1smoke0001',
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
    'bvid': 'BV1smoke0001',
    'aid': 1,
    'cid': 100,
    'videos': 1,
    'title': '竖屏测试标题',
    'desc': '这是简介正文，用于确认 Zen 关闭后正文仍在。',
    'pic': '',
    'pubdate': 1704067200,
    'ctime': 1704067200,
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
  });

  addTearDown(() async {
    await _unmount(tester);
    Get
      ..delete<VideoDetailController>(tag: _heroTag, force: true)
      ..delete<UgcIntroController>(tag: _heroTag, force: true)
      ..delete<AccountService>(force: true)
      ..deleteAll(force: true);
  });

  await tester.pumpWidget(
    _root(
      Scaffold(
        body: CustomScrollView(
          slivers: [
            UgcIntroPanel(
              heroTag: _heroTag,
              showAiBottomSheet: () {},
              showEpisodes: () {},
              onShowMemberPage: (_) {},
              isPortrait: true,
              isHorizontal: false,
            ),
          ],
        ),
      ),
    ),
  );
  await dyn.settle(tester);
}

Future<void> pumpRelated(WidgetTester tester) async {
  await _unmount(tester);
  Get.put(AccountService());

  // `RelatedController.bvid` is a field initializer that reads
  // `Get.arguments['bvid']` (related/controller.dart:10), so the args have to
  // exist before the controller is constructed — `autoQuery: false` only
  // skips the network call, not the read.
  Get.routing.args = <String, dynamic>{'bvid': 'BV1rel00001'};

  final related = RelatedController(autoQuery: false);
  Get.put(related, tag: _heroTag);
  related.loadingState.value = Success([
    _relatedItem('BV1rel00001', 101, '相关视频一', 95),
    _relatedItem('BV1rel00002', 102, '相关视频二', 143),
    _relatedItem('BV1rel00003', 103, '相关视频三', 61),
  ]);

  addTearDown(() async {
    await _unmount(tester);
    Get
      ..delete<RelatedController>(tag: _heroTag, force: true)
      ..delete<AccountService>(force: true)
      ..deleteAll(force: true);
  });

  await tester.pumpWidget(
    _root(
      const Scaffold(
        body: CustomScrollView(
          slivers: [RelatedVideoPanel(heroTag: _heroTag)],
        ),
      ),
    ),
  );
  await dyn.settle(tester);
}

HotVideoItemModel _relatedItem(
  String bvid,
  int cid,
  String title,
  int duration,
) => HotVideoItemModel.fromJson({
  'aid': cid,
  'cid': cid,
  'bvid': bvid,
  'videos': 1,
  'title': title,
  'pic': '',
  'duration': duration,
  'pubdate': 1704067200,
  'owner': {'mid': 1001, 'name': '测试UP主', 'face': ''},
  'stat': {
    'view': 1234,
    'danmaku': 5,
    'reply': 6,
    'favorite': 7,
    'coin': 2,
    'share': 1,
    'like': 9,
  },
});
