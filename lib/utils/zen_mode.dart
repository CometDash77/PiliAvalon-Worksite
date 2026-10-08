import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart';

/// Zen Mode 的唯一共享响应源。
///
/// 持久化先写入 Hive，再同步 RxBool，使所有页面通过同一状态源重绘。
abstract final class ZenMode {
  static final RxBool enabled = Pref.zenMode.obs;

  static bool get isOn => enabled.value;

  static Future<void> set(bool value) async {
    await GStorage.setting.put(SettingBoxKey.zenMode, value);
    enabled.value = value;
  }
}
