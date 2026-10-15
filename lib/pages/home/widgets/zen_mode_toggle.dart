import 'package:PiliPlus/utils/zen_mode.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Zen 顶栏开关的固定宽度:右侧用等宽占位镜像,保证搜索框视觉居中(规格 R2)。
const double kZenModeToggleWidth = 40;

/// 首页(含平板/侧栏)Zen 可见性规则 R1–R4/R8 与普通态常显开关(#97)的纯判定,
/// 便于无头真值表测试。
class HomeZenLayout {
  final bool showZenToggle;
  final bool showMessageBadge;
  final bool showUserAvatar;
  final bool showTabStrip;
  final bool showBody;

  const HomeZenLayout({
    required this.showZenToggle,
    required this.showMessageBadge,
    required this.showUserAvatar,
    required this.showTabStrip,
    required this.showBody,
  });

  factory HomeZenLayout.resolve({required bool zen, required int tabCount}) {
    return HomeZenLayout(
      // 普通态开关常显:首页第二入口,OFF 时由此进入(#97 维护者决议)。
      showZenToggle: true,
      showMessageBadge: !zen,
      showUserAvatar: !zen,
      showTabStrip: !zen && tabCount > 1,
      showBody: !zen,
    );
  }
}

/// 首页顶栏的 Zen 开关:单点切换,Obx 让开关状态即时反映。
class ZenModeToggle extends StatelessWidget {
  const ZenModeToggle({super.key, this.width = kZenModeToggleWidth});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Obx(
        () {
          final colorScheme = Theme.of(context).colorScheme;
          return IconButton(
            tooltip: '极简模式',
            onPressed: () => ZenMode.set(!ZenMode.isOn),
            icon: Icon(
              Icons.self_improvement,
              semanticLabel: '极简模式',
              color: ZenMode.isOn ? colorScheme.primary : null,
            ),
          );
        },
      ),
    );
  }
}
