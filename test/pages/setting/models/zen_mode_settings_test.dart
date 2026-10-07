import 'dart:io';

import 'package:PiliPlus/pages/setting/models/extra_settings.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/models/play_settings.dart';
import 'package:PiliPlus/pages/setting/models/privacy_settings.dart';
import 'package:PiliPlus/pages/setting/models/recommend_settings.dart';
import 'package:PiliPlus/pages/setting/models/style_settings.dart';
import 'package:PiliPlus/pages/setting/models/video_settings.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/zen_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // 组合六个设置列表会读到这些 bootstrap 期才初始化的全局量（缓存路径行的
    // getSubtitle 直读 downloadPath，见 extra_settings.dart:70-75）。
    downloadPath = Directory.systemTemp.createTempSync('zen_s2_download_').path;
    // Linux 上构造 styleSettings 会执行 _useSSDModel()，直读 bootstrap 期才
    // 初始化的 appSupportDirPath（style_settings.dart:63 的 Linux-only 分支）；
    // Windows 本地不走该分支，CI ubuntu 必崩（run 37565641514）。late final
    // 仅可赋值一次，同 isolate 已被其他测试赋过则吞掉 LateError。
    try {
      appSupportDirPath =
          Directory.systemTemp.createTempSync('zen_s2_appsupport_').path;
    } catch (_) {
      // Already assigned by another test file in the same isolate.
    }
    try {
      final dir = Directory.systemTemp.createTempSync('hive_test_');
      Hive.init(dir.path);
      GStorage.setting = await Hive.openBox('setting');
    } catch (_) {
      // Already initialized by another test file in the same isolate.
    }
  });

  setUp(() {
    GStorage.setting.delete(SettingBoxKey.zenMode);
    ZenMode.enabled.value = false;
  });

  group('zenMode settings row', () {
    test('extraSettings contains the Zen Mode switch', () {
      final list = extraSettings;

      final row = list
          .whereType<SwitchModel>()
          .firstWhere((e) => e.effectiveTitle == '极简模式');

      expect(row.setKey, SettingBoxKey.zenMode);
      expect(row.defaultVal, isFalse);
      expect(row.needReboot, isFalse);
      expect(row.onChanged, equals(ZenMode.set));
    });

    test('toggling persists the pref and flips the shared Rx', () async {
      expect(ZenMode.isOn, isFalse);
      expect(Pref.zenMode, isFalse);

      await ZenMode.set(true);
      expect(ZenMode.isOn, isTrue);
      expect(Pref.zenMode, isTrue);

      await ZenMode.set(false);
      expect(ZenMode.isOn, isFalse);
      expect(Pref.zenMode, isFalse);
    });

    test('is indexed by settings search for 极简 and zen queries', () {
      // Mirrors settings_search/view.dart composing the searchable lists.
      final settings = [
        ...extraSettings,
        ...privacySettings,
        ...recommendSettings,
        ...videoSettings,
        ...playSettings,
        ...styleSettings,
      ];

      // 个别行的 subtitle/title 闭包依赖 bootstrap 环境（Get.context、
      // 路径全局量等），headless 测试读不到；搜索页对它们也会逐行求值，
      // 这里按「不可求值 → 不参与匹配」处理，Zen 行本身是纯字符串。
      String safeTitle(SettingsModel e) {
        try {
          return e.effectiveTitle;
        } catch (_) {
          return '';
        }
      }

      String? safeSubtitle(SettingsModel e) {
        try {
          return e.effectiveSubtitle;
        } catch (_) {
          return null;
        }
      }

      bool matches(SettingsModel e, String query) {
        return safeTitle(e).toLowerCase().contains(query) ||
            (safeSubtitle(e) ?? '').toLowerCase().contains(query);
      }

      final byCn = settings.where((e) => matches(e, '极简')).toList();
      expect(byCn.map(safeTitle), contains('极简模式'));

      final byEn = settings.where((e) => matches(e, 'zen')).toList();
      expect(byEn.map(safeTitle), contains('极简模式'));
    });
  });
}
