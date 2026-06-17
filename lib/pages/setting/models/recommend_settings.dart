import 'package:PiliPlus/features/exposure_tracker/exposure_tracker_settings.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/features/shielding/shielding_recommend_tag_enricher.dart';
import 'package:PiliPlus/features/shielding/shielding_store.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

List<SettingsModel> get recommendSettings => [
  const SwitchModel(
    title: '首页使用app端推荐',
    subtitle: '若web端推荐不太符合预期，可尝试切换至app端推荐',
    leading: Icon(Icons.model_training_outlined),
    setKey: SettingBoxKey.appRcmd,
    defaultVal: true,
    needReboot: true,
  ),
  SwitchModel(
    title: '保留首页推荐刷新',
    subtitle: '下拉刷新时保留上次内容',
    leading: const Icon(Icons.refresh),
    setKey: SettingBoxKey.enableSaveLastData,
    defaultVal: true,
    onChanged: (value) {
      try {
        Get.find<RcmdController>()
          ..enableSaveLastData = value
          ..lastRefreshAt = null;
      } catch (e) {
        if (kDebugMode) debugPrint('$e');
      }
    },
  ),
  SwitchModel(
    title: '显示上次看到位置提示',
    subtitle: '保留上次推荐时，在上次刷新位置显示提示',
    leading: const Icon(Icons.tips_and_updates_outlined),
    setKey: SettingBoxKey.savedRcmdTip,
    defaultVal: true,
    onChanged: (value) {
      try {
        Get.find<RcmdController>()
          ..savedRcmdTip = value
          ..lastRefreshAt = null;
      } catch (e) {
        if (kDebugMode) debugPrint('$e');
      }
    },
  ),
  // Upstream recommend-filter entries hidden from UI (storage and business
  // logic preserved). See Task-065.
  // getVideoFilterSelectModel(
  //   title: '点赞率',
  //   suffix: '%',
  //   key: SettingBoxKey.minLikeRatioForRecommend,
  //   values: [0, 1, 2, 3, 4],
  //   onChanged: (value) => RecommendFilter.minLikeRatioForRecommend = value,
  // ),
  // getVideoFilterSelectModel(
  //   title: '视频时长',
  //   suffix: 's',
  //   key: SettingBoxKey.minDurationForRcmd,
  //   values: [0, 30, 60, 90, 120],
  //   onChanged: (value) => RecommendFilter.minDurationForRcmd = value,
  // ),
  // getVideoFilterSelectModel(
  //   title: '播放量',
  //   key: SettingBoxKey.minPlayForRcmd,
  //   values: [0, 50, 100, 500, 1000],
  //   onChanged: (value) => RecommendFilter.minPlayForRcmd = value,
  // ),
  SwitchModel(
    title: '已关注UP豁免推荐过滤',
    subtitle: '推荐中已关注用户发布的内容不会被过滤',
    leading: const Icon(Icons.favorite_border_outlined),
    setKey: SettingBoxKey.exemptFilterForFollowed,
    defaultVal: true,
    onChanged: (value) => RecommendFilter.exemptFilterForFollowed = value,
  ),
  SwitchModel(
    title: '过滤器也应用于相关视频',
    subtitle: '视频详情页的相关视频也进行过滤¹',
    leading: const Icon(Icons.explore_outlined),
    setKey: SettingBoxKey.applyFilterToRelatedVideos,
    defaultVal: true,
    onChanged: (value) => RecommendFilter.applyFilterToRelatedVideos = value,
  ),
  SwitchModel(
    title: '相关视频屏蔽',
    subtitle: '独立控制视频详情页相关视频的屏蔽规则是否生效',
    leading: const Icon(Icons.shield_outlined),
    setKey: ShieldBoxKey.relatedVideoEnabled,
    defaultVal: true,
    onChanged: (value) => ShieldSettingsStore().setRelatedVideoEnabled(value),
  ),
  _buildNumberInputModel(
    title: '标签获取并发数',
    icon: Icons.memory_outlined,
    key: SettingBoxKey.tagEnrichConcurrency,
    defaultVal: 5,
    min: 1,
    max: 10,
  ),
  _buildNumberInputModel(
    title: '标签获取超时',
    icon: Icons.timer_outlined,
    key: SettingBoxKey.tagEnrichTimeout,
    defaultVal: 3,
    min: 1,
    max: 10,
    suffix: 's',
  ),
  _buildNumberInputModel(
    title: '标签缓存上限',
    icon: Icons.storage_outlined,
    key: SettingBoxKey.tagEnrichCacheMaxMb,
    defaultVal: 10,
    min: 1,
    max: 50,
    suffix: 'MB',
  ),
  NormalModel(
    title: '标签缓存状态',
    leading: const Icon(Icons.cached_outlined),
    getSubtitle: () {
      final count = RecommendationTagEnricher.cacheEntryCount;
      final bytes = RecommendationTagEnricher.cacheEstimatedBytes;
      final usedMb = bytes / (1024 * 1024);
      final maxMb = tagEnrichCacheMaxMb;
      return '${usedMb.toStringAsFixed(2)} / $maxMb MB，$count 条（点击可清空缓存）';
    },
    onTap: (context, setState) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('清空标签缓存'),
          content: const Text('缓存清空后，下一轮推荐会重新获取视频标签。'),
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
                RecommendationTagEnricher.resetCache();
                Get.back();
                setState();
                SmartDialog.showToast('标签缓存已清空');
              },
              child: const Text('清空'),
            ),
          ],
        ),
      );
    },
  ),
  _buildRangeShieldingModel(
    title: '时长过滤',
    icon: Icons.hourglass_empty_outlined,
    type: ShieldRuleType.duration,
  ),
  _buildRangeShieldingModel(
    title: '播放量过滤',
    icon: Icons.play_circle_outline,
    type: ShieldRuleType.playbackCount,
  ),
  _buildRangeShieldingModel(
    title: '弹幕量过滤',
    icon: Icons.chat_bubble_outline,
    type: ShieldRuleType.danmakuCount,
  ),
  ...exposureTrackerSettings(buildNumberInputModel: _buildNumberInputModel),
];

SettingsModel _buildNumberInputModel({
  required String title,
  required IconData icon,
  required String key,
  required int defaultVal,
  required int min,
  required int max,
  String? suffix,
}) {
  int value = GStorage.setting.get(key, defaultValue: defaultVal);
  return NormalModel(
    title: title,
    leading: Icon(icon),
    getSubtitle: () {
      final suffixStr = suffix ?? '';
      return '当前: $value$suffixStr（默认$defaultVal$suffixStr，范围$min–$max）';
    },
    onTap: (context, setState) async {
      String valueStr = '';
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: TextField(
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '$defaultVal',
              suffixText: suffix,
            ),
            onChanged: (v) => valueStr = v,
          ),
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
                final parsed = int.tryParse(
                  valueStr.isEmpty ? '$defaultVal' : valueStr,
                );
                if (parsed == null) {
                  SmartDialog.showToast('请输入有效数字');
                  return;
                }
                value = parsed.clamp(min, max).toInt();
                GStorage.setting.put(key, value);
                Get.back();
                setState();
                SmartDialog.showToast('已保存: $value');
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    },
  );
}

/// Builds a singleton range-shielding settings model for a numeric dimension
/// (duration, playbackCount, danmakuCount). Each dimension has exactly one
/// rule: the user sets min/max bounds via an inline dialog.
SettingsModel _buildRangeShieldingModel({
  required String title,
  required IconData icon,
  required ShieldRuleType type,
}) {
  final store = ShieldSettingsStore();

  ({String? lower, String? upper}) _findRangeThresholds() {
    final snapshot = store.snapshot();
    String? lower;
    String? upper;
    for (final rule in snapshot.rules) {
      if (rule.type == type &&
          rule.scope == ShieldScope.recommendation &&
          rule.matchMode == ShieldMatchMode.range) {
        final parsed = _parseRangeFields(rule.pattern);
        if (parsed.min.isEmpty && parsed.max.isNotEmpty) {
          // "..X" pattern -> lower-side threshold (block values <= X).
          lower = parsed.max;
        } else if (parsed.min.isNotEmpty && parsed.max.isEmpty) {
          // "Y.." pattern -> upper-side threshold (block values >= Y).
          upper = parsed.min;
        } else if (parsed.min.isNotEmpty && parsed.max.isNotEmpty) {
          // Legacy bounded "A..B" — derive defensively:
          // treat A as lower threshold, B as upper threshold.
          lower ??= parsed.min;
          upper ??= parsed.max;
        }
      }
    }
    return (lower: lower, upper: upper);
  }

  String _formatSubtitle(String? lower, String? upper) {
    if ((lower == null || lower.isEmpty) &&
        (upper == null || upper.isEmpty)) {
      return '未设置';
    }
    if (lower != null && lower.isNotEmpty &&
        upper != null && upper.isNotEmpty) {
      return '屏蔽 ≤ $lower 及 ≥ $upper';
    }
    if (lower != null && lower.isNotEmpty) return '屏蔽 ≤ $lower';
    return '屏蔽 ≥ ${upper ?? ''}';
  }

  return NormalModel(
    title: title,
    leading: Icon(icon),
    getSubtitle: () {
      final t = _findRangeThresholds();
      return _formatSubtitle(t.lower, t.upper);
    },
    onTap: (context, setState) async {
      final t = _findRangeThresholds();
      await _openRangeShieldingDialog(context, type, store,
          lowerInit: t.lower, upperInit: t.upper);
      setState();
    },
  );
}

/// Opens a dialog to edit the singleton range-shielding rule for [type].
Future<void> _openRangeShieldingDialog(
  BuildContext context,
  ShieldRuleType type,
  ShieldSettingsStore store, {
  String? lowerInit,
  String? upperInit,
}) async {
  String minStr = lowerInit ?? '';
  String maxStr = upperInit ?? '';

  final typeLabel = _rangeTypeLabel(type);

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('$typeLabel过滤'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('range-min-$minStr'),
                  autofocus: true,
                  initialValue: minStr,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '屏蔽 ≤',
                    hintText: '留空不限',
                  ),
                  onChanged: (v) => minStr = v,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 16, left: 8, right: 8),
                child: Text('—', style: TextStyle(fontSize: 20)),
              ),
              Expanded(
                child: TextFormField(
                  key: ValueKey('range-max-$maxStr'),
                  initialValue: maxStr,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '屏蔽 ≥',
                    hintText: '留空不限',
                  ),
                  onChanged: (v) => maxStr = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              final hint = _rangeHint(minStr, maxStr);
              return SizedBox(
                width: double.infinity,
                child: Text(
                  hint.text,
                  style: TextStyle(
                    fontSize: 12,
                    color: hint.isError
                        ? ColorScheme.of(context).error
                        : ColorScheme.of(context).outline,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(color: ColorScheme.of(ctx).outline),
          ),
        ),
        TextButton(
          onPressed: () async {
            final min = minStr.trim();
            final max = maxStr.trim();
            if (min.isEmpty && max.isEmpty) {
              SmartDialog.showToast('至少填写一个阈值');
              return;
            }
            final minNum = min.isNotEmpty ? int.tryParse(min) : null;
            final maxNum = max.isNotEmpty ? int.tryParse(max) : null;
            if (min.isNotEmpty && minNum == null) {
              SmartDialog.showToast('下限格式无效');
              return;
            }
            if (max.isNotEmpty && maxNum == null) {
              SmartDialog.showToast('上限格式无效');
              return;
            }
            if (minNum != null && maxNum != null && minNum > maxNum) {
              SmartDialog.showToast('下限不能大于上限');
              return;
            }

            final ruleSet = await store.load();
            // Remove ALL existing range rules for this type+scope.
            final newRules = ruleSet.rules
                .where(
                  (rule) =>
                      !(rule.type == type &&
                          rule.scope == ShieldScope.recommendation &&
                          rule.matchMode == ShieldMatchMode.range),
                )
                .toList();

            final now = DateTime.now();
            final baseId = 'range-${now.microsecondsSinceEpoch}';

            // Persist the lower-side threshold as "..X"; range matching is
            // inclusive, so this blocks values <= X.
            if (min.isNotEmpty) {
              newRules.add(ShieldRule(
                id: max.isEmpty ? baseId : '$baseId-lo',
                type: type,
                matchMode: ShieldMatchMode.range,
                scope: ShieldScope.recommendation,
                action: ShieldAction.block,
                pattern: '..$min',
                enabled: true,
                updatedAt: now,
              ));
            }

            // Persist the upper-side threshold as "Y.."; range matching is
            // inclusive, so this blocks values >= Y.
            if (max.isNotEmpty) {
              newRules.add(ShieldRule(
                id: min.isEmpty ? baseId : '$baseId-hi',
                type: type,
                matchMode: ShieldMatchMode.range,
                scope: ShieldScope.recommendation,
                action: ShieldAction.block,
                pattern: '$max..',
                enabled: true,
                updatedAt: now,
              ));
            }

            try {
              await store.save(ruleSet.copyWith(rules: newRules));
              Get.back();
              SmartDialog.showToast('已保存');
            } catch (e) {
              SmartDialog.showToast(e.toString());
            }
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

String _rangeTypeLabel(ShieldRuleType type) => switch (type) {
  ShieldRuleType.duration => '时长',
  ShieldRuleType.playbackCount => '播放量',
  ShieldRuleType.danmakuCount => '弹幕量',
  _ => '',
};

/// Parses a range pattern string into separate min/max field values.
///
/// Handles "min..max", "min..", "..max", and exact "N" patterns.
({String min, String max}) _parseRangeFields(String? pattern) {
  if (pattern == null || pattern.trim().isEmpty) {
    return (min: '', max: '');
  }
  final trimmed = pattern.trim();
  final match = RegExp(
    r'^\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+)?)\s*\.\.\s*'
    r'([+-]?(?:\d+(?:\.\d+)?|\.\d+)?)\s*$',
  ).firstMatch(trimmed);
  if (match != null) {
    final m = match.group(1)?.trim();
    final x = match.group(2)?.trim();
    return (
      min: (m != null && m.isNotEmpty) ? m : '',
      max: (x != null && x.isNotEmpty) ? x : '',
    );
  }
  // Treat bare number as exact match (min == max).
  final exact = num.tryParse(trimmed);
  if (exact != null) {
    return (min: trimmed, max: trimmed);
  }
  return (min: '', max: '');
}

/// Returns a hint about the current range values, or an error if invalid.
({String text, bool isError}) _rangeHint(String minStr, String maxStr) {
  final min = minStr.trim();
  final max = maxStr.trim();
  if (min.isEmpty && max.isEmpty) {
    return (text: '至少填写一个值', isError: true);
  }
  final minNum = min.isNotEmpty ? int.tryParse(min) : null;
  final maxNum = max.isNotEmpty ? int.tryParse(max) : null;
  if (min.isNotEmpty && minNum == null) {
    return (text: '下限格式无效', isError: true);
  }
  if (max.isNotEmpty && maxNum == null) {
    return (text: '上限格式无效', isError: true);
  }
  if (minNum != null && maxNum != null && minNum > maxNum) {
    return (text: '下限不能大于上限', isError: true);
  }
  // Boundary-shield hint: range matching is inclusive.
  if (minNum != null && maxNum != null) {
    return (text: '屏蔽 ≤ $minNum 及 ≥ $maxNum', isError: false);
  }
  if (minNum != null) {
    return (text: '屏蔽 ≤ $minNum', isError: false);
  }
  return (text: '屏蔽 ≥ $maxNum', isError: false);
}
