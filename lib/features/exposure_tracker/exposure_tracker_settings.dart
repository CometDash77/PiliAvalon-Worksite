import 'package:PiliPlus/features/exposure_tracker/exposure_tracker.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

typedef ExposureNumberInputModelBuilder =
    SettingsModel Function({
      required String title,
      required IconData icon,
      required String key,
      required int defaultVal,
      required int min,
      required int max,
      String? suffix,
    });

List<SettingsModel> exposureTrackerSettings({
  required ExposureNumberInputModelBuilder buildNumberInputModel,
}) => [
  const SwitchModel(
    title: '启用重复曝光过滤',
    subtitle: '首页推荐中反复曝光但未点击的视频会进入冷却过滤',
    leading: Icon(Icons.visibility_off_outlined),
    setKey: SettingBoxKey.repeatExposureFilterEnabled,
    defaultVal: false,
  ),
  buildNumberInputModel(
    title: '重复曝光统计窗口',
    icon: Icons.date_range_outlined,
    key: SettingBoxKey.repeatExposureWindowDays,
    defaultVal: 7,
    min: 1,
    max: 30,
    suffix: '天',
  ),
  buildNumberInputModel(
    title: '重复曝光阈值',
    icon: Icons.exposure_outlined,
    key: SettingBoxKey.repeatExposureThreshold,
    defaultVal: 10,
    min: 2,
    max: 50,
    suffix: '次',
  ),
  buildNumberInputModel(
    title: '重复曝光冷却期',
    icon: Icons.ac_unit_outlined,
    key: SettingBoxKey.repeatExposureCoolingDays,
    defaultVal: 30,
    min: 1,
    max: 90,
    suffix: '天',
  ),
  NormalModel(
    title: '重复曝光缓存状态',
    leading: const Icon(Icons.inventory_2_outlined),
    getSubtitle: () {
      final tracker = ExposureTracker.instance;
      return '${tracker.cacheCount} 条记录，${tracker.activeCoolingCount} 条冷却中（点击可清空缓存）';
    },
    onTap: (context, setState) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('清空重复曝光缓存'),
          content: const Text('清空后，首页推荐的重复曝光计数会从零开始。'),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text(
                '取消',
                style: TextStyle(color: ColorScheme.of(ctx).outline),
              ),
            ),
            TextButton(
              onPressed: () {
                ExposureTracker.instance.clearAll();
                Get.back();
                setState();
                SmartDialog.showToast('重复曝光缓存已清空');
              },
              child: const Text('清空'),
            ),
          ],
        ),
      );
    },
  ),
];
