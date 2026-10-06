import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart';

/// Zen Mode 的唯一共享响应源(规格 #42 S3)。
///
/// `Pref` 没有响应式成员,普通 getter 不驱动重绘(先例
/// lib/plugin/pl_player/controller.dart:192)。全 app 只认这里这一个
/// RxBool:写入先落 Hive setting box,再同步翻转 Rx,让每个 Obx
/// 无需重载立即重绘。
abstract final class ZenMode {
  static final RxBool enabled = Pref.zenMode.obs;

  static bool get isOn => enabled.value;

  static Future<void> set(bool value) async {
    await GStorage.setting.put(SettingBoxKey.zenMode, value);
    enabled.value = value;
  }
}
