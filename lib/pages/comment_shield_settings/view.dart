import 'package:PiliPlus/common/widgets/flutter/list_tile.dart' as custom;
import 'package:PiliPlus/features/shielding/comment_shielding_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class CommentShieldSettingsPage extends StatefulWidget {
  const CommentShieldSettingsPage({
    super.key,
    this.showAppBar = true,
    this.store,
  });

  final bool showAppBar;
  final CommentShieldingStore? store;

  @override
  State<CommentShieldSettingsPage> createState() =>
      _CommentShieldSettingsPageState();
}

class _CommentShieldSettingsPageState extends State<CommentShieldSettingsPage> {
  late final CommentShieldingStore _store =
      widget.store ?? CommentShieldingStore();
  late CommentShieldingConfig _config = _store.snapshot();

  Future<void> _save(CommentShieldingConfig config) async {
    try {
      await _store.save(config);
      if (!mounted) return;
      setState(() => _config = config);
      SmartDialog.showToast('已保存');
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  void _updateConfig(CommentShieldingConfig config) {
    setState(() => _config = config);
    _save(config);
  }

  bool _canSaveBounds({
    int? minCharCount,
    int? maxCharCount,
  }) {
    if (minCharCount != null &&
        maxCharCount != null &&
        minCharCount > maxCharCount) {
      SmartDialog.showToast('最少字数不能大于最多字数');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    final showAppBar = widget.showAppBar;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: showAppBar ? AppBar(title: const Text('评论区屏蔽设置')) : null,
      body: ListView(
        padding: EdgeInsets.only(
          left: showAppBar ? padding.left : 0,
          right: showAppBar ? padding.right : 0,
          bottom: padding.bottom + 100,
        ),
        children: [
          // levelThreshold
          custom.ListTile(
            leading: const Icon(Icons.stars_outlined),
            title: const Text('用户等级阈值'),
            subtitle: Text(
              _config.levelThreshold == null || _config.levelThreshold == 0
                  ? '不过滤'
                  : '只看 Lv.${_config.levelThreshold} 及以上',
            ),
            onTap: () => _editNumber(
              label: '用户等级阈值 (0-6)',
              currentValue: _config.levelThreshold,
              max: 6,
              onSaved: (value) => _updateConfig(
                _config.copyWith(levelThreshold: value),
              ),
            ),
          ),
          // genderFilter
          custom.ListTile(
            leading: const Icon(Icons.people_outlined),
            title: const Text('屏蔽性别'),
            subtitle: Text(
              _config.genderFilter.isEmpty
                  ? '不过滤'
                  : '已选 ${_config.genderFilter.length} 项',
            ),
            onTap: () => _editMultiSelect(
              label: '屏蔽性别',
              options: const ['男', '女', '保密', ''],
              optionLabels: const {
                '': '未知/空',
              },
              selected: _config.genderFilter,
              onSaved: (values) => _updateConfig(
                _config.copyWith(genderFilter: values),
              ),
            ),
          ),
          // memberFilter
          custom.ListTile(
            leading: const Icon(Icons.card_membership_outlined),
            title: const Text('屏蔽会员类型'),
            subtitle: Text(
              _config.memberFilter.isEmpty
                  ? '不过滤'
                  : '已选 ${_config.memberFilter.length} 项',
            ),
            onTap: () => _editMultiSelect(
              label: '屏蔽会员类型',
              options: const ['vip:0:0', 'vip:1:1', 'vip:2:1', 'vip:2:0'],
              optionLabels: const {
                'vip:0:0': '非会员 / 未开通 (0,0)',
                'vip:1:1': '大会员有效 (1,1)',
                'vip:2:1': '年度大会员有效 (2,1)',
                'vip:2:0': '年度大会员过期或未生效 (2,0)',
              },
              selected: _config.memberFilter,
              onSaved: (values) => _updateConfig(
                _config.copyWith(memberFilter: values),
              ),
            ),
          ),
          // ipLocationFilter
          custom.ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('屏蔽IP属地'),
            subtitle: Text(
              _config.ipLocationFilter.isEmpty
                  ? '不过滤'
                  : '已选 ${_config.ipLocationFilter.length} 项',
            ),
            onTap: () => _editMultiSelect(
              label: '屏蔽IP属地',
              options: const [
                '广东',
                '北京',
                '上海',
                '浙江',
                '江苏',
                '山东',
                '河南',
                '四川',
                '湖北',
                '湖南',
                '福建',
                '安徽',
                '河北',
                '陕西',
                '辽宁',
                '江西',
                '重庆',
                '广西',
                '天津',
                '云南',
                '贵州',
                '山西',
                '吉林',
                '黑龙江',
                '甘肃',
                '内蒙古',
                '新疆',
                '海南',
                '宁夏',
                '青海',
                '西藏',
                '海外',
              ],
              selected: _config.ipLocationFilter,
              onSaved: (values) => _updateConfig(
                _config.copyWith(ipLocationFilter: values),
              ),
            ),
          ),
          // minCharCount
          custom.ListTile(
            leading: const Icon(Icons.short_text_outlined),
            title: const Text('最少字数'),
            subtitle: Text(
              _config.minCharCount == null
                  ? '不过滤'
                  : '少于 ${_config.minCharCount} 字隐藏',
            ),
            onTap: () => _editNumber(
              label: '最少字数',
              currentValue: _config.minCharCount,
              onSaved: (value) {
                if (!_canSaveBounds(
                  minCharCount: value,
                  maxCharCount: _config.maxCharCount,
                )) {
                  return;
                }
                _updateConfig(_config.copyWith(minCharCount: value));
              },
            ),
          ),
          // maxCharCount
          custom.ListTile(
            leading: const Icon(Icons.format_align_left_outlined),
            title: const Text('最多字数'),
            subtitle: Text(
              _config.maxCharCount == null
                  ? '不过滤'
                  : '多于 ${_config.maxCharCount} 字隐藏',
            ),
            onTap: () => _editNumber(
              label: '最多字数',
              currentValue: _config.maxCharCount,
              onSaved: (value) {
                if (!_canSaveBounds(
                  minCharCount: _config.minCharCount,
                  maxCharCount: value,
                )) {
                  return;
                }
                _updateConfig(_config.copyWith(maxCharCount: value));
              },
            ),
          ),
          // likeThreshold
          custom.ListTile(
            leading: const Icon(Icons.thumb_up_outlined),
            title: const Text('最低点赞数'),
            subtitle: Text(
              _config.likeThreshold == null || _config.likeThreshold == 0
                  ? '不过滤'
                  : '少于 ${_config.likeThreshold} 赞隐藏',
            ),
            onTap: () => _editNumber(
              label: '最低点赞数',
              currentValue: _config.likeThreshold,
              onSaved: (value) => _updateConfig(
                _config.copyWith(likeThreshold: value),
              ),
            ),
          ),
          // blockWithPicture
          SwitchListTile(
            secondary: const Icon(Icons.image_outlined),
            title: const Text('屏蔽含图片评论'),
            subtitle: const Text('开启后隐藏包含图片的评论'),
            value: _config.blockWithPicture,
            onChanged: (value) => _updateConfig(
              _config.copyWith(blockWithPicture: value),
            ),
          ),
          // blockWithEmote
          SwitchListTile(
            secondary: const Icon(Icons.emoji_emotions_outlined),
            title: const Text('屏蔽含表情评论'),
            subtitle: const Text('开启后隐藏包含表情的评论'),
            value: _config.blockWithEmote,
            onChanged: (value) => _updateConfig(
              _config.copyWith(blockWithEmote: value),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.forum_outlined),
            title: const Text('隐藏无可见评论的首页推荐'),
            subtitle: const Text('开启后，评论全部被屏蔽的推荐不会显示'),
            value: _config.hideHomeFeedItemsWithoutVisibleComments,
            onChanged: (value) => _updateConfig(
              _config.copyWith(
                hideHomeFeedItemsWithoutVisibleComments: value,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNumber({
    required String label,
    required int? currentValue,
    int? max,
    required void Function(int?) onSaved,
  }) async {
    String text = currentValue?.toString() ?? '';
    final saved = await showDialog<_NumberEditResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(label),
          content: TextFormField(
            autofocus: true,
            initialValue: text,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '留空不过滤',
              suffixText: max != null ? '0-$max' : null,
            ),
            onChanged: (value) => text = value,
          ),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('取消')),
            TextButton(
              onPressed: () {
                final trimmed = text.trim();
                if (trimmed.isEmpty) {
                  Get.back(result: const _NumberEditResult(null));
                  return;
                }
                final parsed = int.tryParse(trimmed);
                if (parsed == null || parsed < 0) {
                  SmartDialog.showToast('请输入有效数字');
                  return;
                }
                if (max != null && parsed > max) {
                  SmartDialog.showToast('最大值为 $max');
                  return;
                }
                Get.back(result: _NumberEditResult(parsed));
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved != null) {
      onSaved(saved.value);
    }
  }

  Future<void> _editMultiSelect({
    required String label,
    required List<String> options,
    Map<String, String> optionLabels = const {},
    required List<String> selected,
    required void Function(List<String>) onSaved,
  }) async {
    final selectedSet = selected.toSet();
    final saved = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(label),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: options.map((option) {
                final displayLabel =
                    optionLabels[option] ?? (option.isEmpty ? '未知/空' : option);
                return CheckboxListTile(
                  title: Text(displayLabel),
                  value: selectedSet.contains(option),
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        selectedSet.add(option);
                      } else {
                        selectedSet.remove(option);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('取消')),
            TextButton(
              onPressed: () => Get.back(result: selectedSet.toList()),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved != null) {
      onSaved(saved);
    }
  }
}

class _NumberEditResult {
  const _NumberEditResult(this.value);

  final int? value;
}
