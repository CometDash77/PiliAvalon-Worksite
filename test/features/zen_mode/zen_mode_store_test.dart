import 'dart:io';

import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/zen_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  setUpAll(() async {
    try {
      final dir = Directory.systemTemp.createTempSync('hive_test_');
      Hive.init(dir.path);
      GStorage.setting = await Hive.openBox('setting');
    } catch (_) {
      // Already initialized by another test file in the same isolate.
    }
  });

  group('ZenMode store', () {
    test('clean install default is false', () {
      expect(GStorage.setting.get(SettingBoxKey.zenMode), isNull);
      expect(Pref.zenMode, isFalse);
    });

    test('set(true) persists and flips the shared Rx', () async {
      await ZenMode.set(true);

      expect(GStorage.setting.get(SettingBoxKey.zenMode), isTrue);
      expect(Pref.zenMode, isTrue);
      expect(ZenMode.enabled.value, isTrue);
      expect(ZenMode.isOn, isTrue);
    });

    test('set(false) restores', () async {
      await ZenMode.set(false);

      expect(GStorage.setting.get(SettingBoxKey.zenMode), isFalse);
      expect(Pref.zenMode, isFalse);
      expect(ZenMode.enabled.value, isFalse);
    });

    test('enabled is the single shared reactive source', () {
      expect(ZenMode.enabled, same(ZenMode.enabled));
      expect(ZenMode.enabled, isA<RxBool>());
    });
  });
}
