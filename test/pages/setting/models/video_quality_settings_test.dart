import 'dart:io';

import 'package:PiliPlus/models/common/video/video_quality.dart';
import 'package:PiliPlus/pages/setting/models/video_settings.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory directory;
  late BuildContext dialogContext;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp(
      'video_quality_settings_',
    );
    Hive.init(directory.path);
    GStorage.setting = await Hive.openBox('setting');
  });

  setUp(() async {
    await GStorage.setting.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> pumpDialogHost(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) {
            dialogContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  group('half-screen quality preference storage', () {
    test('missing and -1 normalize to follow fullscreen', () async {
      expect(Pref.defaultVideoQaHalfScreen, isNull);

      await GStorage.setting.put(SettingBoxKey.defaultVideoQaHalfScreen, -1);

      expect(Pref.defaultVideoQaHalfScreen, isNull);
    });

    test(
      'explicit half-screen quality is returned without changing old keys',
      () async {
        await GStorage.setting.putAll({
          SettingBoxKey.defaultVideoQa: VideoQuality.high1080.code,
          SettingBoxKey.defaultVideoQaCellular: VideoQuality.high720.code,
          SettingBoxKey.defaultVideoQaHalfScreen: VideoQuality.hdr.code,
        });

        expect(Pref.defaultVideoQaHalfScreen, VideoQuality.hdr.code);
        expect(Pref.defaultVideoQa, VideoQuality.high1080.code);
        expect(Pref.defaultVideoQaCellular, VideoQuality.high720.code);
      },
    );
  });

  group('half-screen quality dialog', () {
    testWidgets('cancel leaves the stored preference untouched', (
      tester,
    ) async {
      await GStorage.setting.put(
        SettingBoxKey.defaultVideoQaHalfScreen,
        VideoQuality.high1080.code,
      );
      await pumpDialogHost(tester);

      final future = showVideoQaHalfScreenDialog(dialogContext, () {});
      await tester.pumpAndSettle();
      await tester.pageBack();
      await future;
      await tester.pumpAndSettle();

      expect(
        GStorage.setting.get(SettingBoxKey.defaultVideoQaHalfScreen),
        VideoQuality.high1080.code,
      );
    });

    testWidgets('follow selection persists -1 and exposes normalized getter', (
      tester,
    ) async {
      await GStorage.setting.put(
        SettingBoxKey.defaultVideoQaHalfScreen,
        VideoQuality.high1080.code,
      );
      await pumpDialogHost(tester);

      final future = showVideoQaHalfScreenDialog(dialogContext, () {});
      await tester.pumpAndSettle();
      expect(find.text('跟随全屏画质'), findsOneWidget);
      await tester.tap(find.text('跟随全屏画质'));
      await future;
      await tester.pumpAndSettle();

      expect(GStorage.setting.get(SettingBoxKey.defaultVideoQaHalfScreen), -1);
      expect(Pref.defaultVideoQaHalfScreen, isNull);
    });

    testWidgets('explicit selection persists the selected quality', (
      tester,
    ) async {
      await pumpDialogHost(tester);

      final future = showVideoQaHalfScreenDialog(dialogContext, () {});
      await tester.pumpAndSettle();
      expect(find.text(VideoQuality.hdr.desc), findsOneWidget);
      await tester.tap(find.text(VideoQuality.hdr.desc));
      await future;
      await tester.pumpAndSettle();

      expect(
        GStorage.setting.get(SettingBoxKey.defaultVideoQaHalfScreen),
        VideoQuality.hdr.code,
      );
      expect(Pref.defaultVideoQaHalfScreen, VideoQuality.hdr.code);
    });
  });
}
