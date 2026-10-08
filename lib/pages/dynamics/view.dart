import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/common/dynamic/up_panel_position.dart';
import 'package:PiliPlus/models/dynamics/up.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/dynamics/widgets/up_panel.dart';
import 'package:PiliPlus/pages/dynamics_create/view.dart';
import 'package:PiliPlus/pages/dynamics_tab/view.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/zen_mode.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide DraggableScrollableSheet;

class DynamicsPage extends StatefulWidget {
  const DynamicsPage({super.key});

  @override
  State<DynamicsPage> createState() => _DynamicsPageState();
}

class _DynamicsPageState extends CommonPageState<DynamicsPage>
    with AutomaticKeepAliveClientMixin {
  final _dynamicsController = Get.putOrFind(DynamicsController.new);
  UpPanelPosition get upPanelPosition => _dynamicsController.upPanelPosition;
  late final MainController _mainController = Get.find<MainController>();

  @override
  bool get wantKeepAlive => true;

  Widget _createDynamicBtn(ColorScheme colorScheme, {bool isRight = true}) =>
      Container(
        width: 34,
        height: 34,
        margin: isRight ? const .only(right: 16) : const .only(left: 16),
        child: IconButton(
          tooltip: '发布动态',
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            backgroundColor: WidgetStatePropertyAll(
              colorScheme.secondaryContainer,
            ),
          ),
          onPressed: () => CreateDynPanel.onCreateDyn(context),
          icon: Icon(
            Icons.add,
            size: 18,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
      );

  Widget upPanelPart(ColorScheme colorScheme) {
    final isTop = upPanelPosition == .top;
    final needBg = upPanelPosition.index > 2;
    return Material(
      type: needBg ? .canvas : .transparency,
      color: needBg ? colorScheme.surface : null,
      child: SizedBox(
        width: isTop ? null : 64,
        height: isTop ? 76 : null,
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (notification) {
            final metrics = notification.metrics;
            if (metrics.pixels >= metrics.maxScrollExtent - 300) {
              _dynamicsController.onLoadMore();
            }
            return false;
          },
          child: Obx(
            () => _buildUpPanel(_dynamicsController.loadingState.value),
          ),
        ),
      ),
    );
  }

  Widget _buildUpPanel(LoadingState<FollowUpModel> upState) {
    return switch (upState) {
      Loading() => const SizedBox.shrink(),
      Success(:final response) => UpPanel(
        upData: response,
        dynamicsController: _dynamicsController,
      ),
      Error() => Center(
        child: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _dynamicsController.onReload,
        ),
      ),
    };
  }

  bool get checkPage =>
      _mainController.navigationBars[0] != .dynamics &&
      _mainController.selectedIndex.value == 0;

  @override
  bool onNotificationType1(UserScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType1(notification);
  }

  @override
  bool onNotificationType2(ScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType2(notification);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = ColorScheme.of(context);

    // One reactive build for zen + the visible tab list + the controller, so
    // the strip, the pages and the controller swap in the same frame.
    return Obx(() {
      final bool zen = ZenMode.isOn;
      final List<DynamicsTabType> tabs = DynamicsController.visibleTabs(
        zen: zen,
      );
      final TabController tabController = _dynamicsController.tabController;

      Widget child = tabBarView(
        controller: tabController,
        children: [
          // Explicit type keys: without them the TabBarView would reuse the
          // 全部 page's State for the single 投稿 slot and keep showing the
          // wrong feed (R14/R17).
          for (final type in tabs)
            DynamicsTabPage(key: ValueKey(type), dynamicsType: type),
        ],
      );

      Widget? drawer;
      Widget? endDrawer;

      Widget? leading;
      late Widget actions;

      if (zen) {
        // R14: the UP panel, its drawer and the drawer buttons are noise
        // while Zen is on. The publish-dynamics button keeps its original
        // behaviour — and, for the right drawer, its original side.
        if (upPanelPosition == .rightDrawer) {
          leading = _createDynamicBtn(colorScheme, isRight: false);
          actions = const SizedBox.shrink();
        } else {
          actions = _createDynamicBtn(colorScheme);
        }
      } else {
        switch (upPanelPosition) {
          case .top:
            child = Column(
              children: [
                upPanelPart(colorScheme),
                Expanded(child: child),
              ],
            );
            actions = _createDynamicBtn(colorScheme);
          case .leftFixed:
            child = Row(
              children: [
                upPanelPart(colorScheme),
                Expanded(child: child),
              ],
            );
            actions = _createDynamicBtn(colorScheme);
          case .rightFixed:
            child = Row(
              children: [
                Expanded(child: child),
                upPanelPart(colorScheme),
              ],
            );
            actions = _createDynamicBtn(colorScheme);
          case .leftDrawer:
            drawer = upPanelPart(colorScheme);
            actions = _createDynamicBtn(colorScheme);
            leading = const DrawerButton();
          case .rightDrawer:
            endDrawer = upPanelPart(colorScheme);
            leading = _createDynamicBtn(colorScheme, isRight: false);
            actions = const EndDrawerButton();
        }
      }

      return Scaffold(
        primary: false,
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const .fromHeight(50),
          child: Row(
            children: [
              ?leading,
              Expanded(
                // R15: no strip while zen is on — a lone tab is noise.
                child: zen
                    ? const SizedBox.shrink()
                    : TabBar(
                        dividerHeight: 0,
                        isScrollable: true,
                        tabAlignment: .start,
                        dividerColor: Colors.transparent,
                        labelColor: colorScheme.primary,
                        indicatorColor: colorScheme.primary,
                        controller: tabController,
                        unselectedLabelColor: colorScheme.onSurface,
                        labelStyle:
                            TabBarTheme.of(context).labelStyle
                                ?.copyWith(fontSize: 13) ??
                            const TextStyle(fontSize: 13),
                        tabs: [
                          for (final type in tabs) Tab(text: type.label),
                        ],
                        onTap: (index) {
                          if (!tabController.indexIsChanging) {
                            _dynamicsController.animateToTop();
                          }
                        },
                      ),
              ),
              actions,
            ],
          ),
        ),
        drawer: drawer,
        endDrawer: endDrawer,
        body: onBuild(child),
      );
    });
  }
}
