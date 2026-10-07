import 'dart:async';

import 'package:PiliPlus/http/dynamics.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/dynamics/up.dart';
import 'package:PiliPlus/pages/common/common_data_controller.dart';
import 'package:PiliPlus/pages/dynamics_tab/controller.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/zen_mode.dart';
import 'package:flutter/scheduler.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' show TabController;

class DynamicsController
    extends CommonDataController<FollowUpModel, FollowUpModel>
    with GetTickerProviderStateMixin, AccountMixin {
  late TabController tabController;
  bool _tabControllerBuilt = false;

  final Set<int> tempBannedList = <int>{};

  String? _offset;
  late int _page = 1;
  late bool _isEnd = false;
  Set<UpItem>? _cacheUpList;
  late int hostMid = -1, currentMid = -1;
  late bool showLiveUp = Pref.expandDynLivePanel;
  late final _showAllUp = Pref.dynamicsShowAllFollowedUp;

  final upPanelPosition = Pref.upPanelPosition;

  @override
  final AccountService accountService = Get.find<AccountService>();

  /// Visible dynamics tabs for a Zen state (spec #42 R14): only the video
  /// (投稿) tab survives, Zen off restores the full five-tab list (R18).
  static List<DynamicsTabType> visibleTabs({required bool zen}) => zen
      ? const <DynamicsTabType>[DynamicsTabType.video]
      : DynamicsTabType.values;

  /// Preferred start tab clamped into the visible range (R17).
  static int initialIndexFor(int preferred, {required bool zen}) =>
      preferred.clamp(0, visibleTabs(zen: zen).length - 1);

  /// UP-panel jump target remapped into the visible list (R17): the UP tab
  /// only exists outside Zen, so a Zen jump falls back to the first tab.
  static int jumpTargetFor(int mid, {required bool zen}) {
    if (mid == -1) {
      return 0;
    }
    final upIndex = visibleTabs(zen: zen).indexOf(DynamicsTabType.up);
    return upIndex == -1 ? 0 : upIndex;
  }

  /// GetX tag for the visible tab at [index] (R17 tag-lookup remap).
  static String tagForIndex(int index, {required bool zen}) =>
      visibleTabs(zen: zen)[index].name;

  DynamicsTabController? get controller {
    try {
      return Get.find<DynamicsTabController>(
        tag: tagForIndex(tabController.index, zen: ZenMode.isOn),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _rebuildTabController();
    ever(ZenMode.enabled, (_) => _rebuildTabController());
    queryData();
  }

  void _rebuildTabController() {
    final TabController? previous = _tabControllerBuilt ? tabController : null;
    tabController = TabController(
      vsync: this,
      length: visibleTabs(zen: ZenMode.isOn).length,
      initialIndex: initialIndexFor(
        Pref.defaultDynamicTypeIndex,
        zen: ZenMode.isOn,
      ),
    );
    _tabControllerBuilt = true;
    if (previous != null) {
      // Dispose after the frame so in-flight listeners detach first.
      SchedulerBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  void _jumpToTab(int mid) {
    tabController.index = jumpTargetFor(mid, zen: ZenMode.isOn);
  }

  void onSelectUp(int mid) {
    if (currentMid == mid) {
      _jumpToTab(mid);
      if (mid == -1) {
        singleRefresh();
      }
      controller?.onReload();
      return;
    }

    if (mid != -1) {
      hostMid = mid;
      try {
        Get.find<DynamicsTabController>(
          tag: DynamicsTabType.up.name,
        ).onReload();
      } catch (_) {}
    }

    currentMid = mid;
    _jumpToTab(mid);
  }

  Future<void> singleRefresh() {
    if (_showAllUp) {
      _page = 1;
      _cacheUpList = null;
    }
    _offset = null;
    _isEnd = false;
    return super.onRefresh();
  }

  @override
  Future<void> onRefresh() {
    final controller = this.controller;
    if (controller != null) {
      singleRefresh();
      return controller.onRefresh();
    }
    return singleRefresh();
  }

  @override
  void animateToTop() {
    controller?.animateToTop();
    scrollController.animToTop();
  }

  @override
  void toTopOrRefresh() {
    final ctr = controller;
    if (ctr?.scrollController.hasClients == true) {
      if (ctr!.scrollController.position.pixels == 0) {
        if (scrollController.hasClients &&
            scrollController.position.pixels != 0) {
          scrollController.animToTop();
        }
        EasyThrottle.throttle(
          'topOrRefresh',
          const Duration(milliseconds: 500),
          onRefresh,
        );
      } else {
        animateToTop();
      }
    } else {
      super.toTopOrRefresh();
    }
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  @override
  void onChangeAccount(bool isLogin) => onReload();

  @override
  Future<LoadingState<FollowUpModel>> customGetData() {
    if (_offset == null) {
      return DynamicsHttp.followUp();
    }
    if (_showAllUp) {
      return DynamicsHttp.followings(
        vmid: Accounts.main.mid,
        pn: _page,
        orderType: 'attention',
        ps: 50,
      );
    } else {
      return DynamicsHttp.dynUpList(_offset);
    }
  }

  @override
  Future<void> queryData([bool isRefresh = true]) {
    if (!isRefresh && _isEnd) return Future.value();
    return super.queryData(isRefresh);
  }

  @override
  bool customHandleResponse(bool isRefresh, Success<FollowUpModel> response) {
    final res = response.response;

    if (_showAllUp) {
      if (res.upList?.isNotEmpty != true) {
        _isEnd = true;
      }
    } else {
      _offset = res.offset;
      if (res.hasMore != true || _offset.isNullOrEmpty) {
        _isEnd = true;
      }
    }

    if (isRefresh) {
      if (_showAllUp) {
        _offset = '';
        _cacheUpList = res.upList?.toSet();
      }
      loadingState.value = response;
    } else {
      if (_showAllUp) {
        _page++;
      }

      if (res.upList case final upList? when upList.isNotEmpty) {
        if (_showAllUp && _cacheUpList != null) {
          upList.removeWhere(_cacheUpList!.contains);
        }
        loadingState
          ..value.data.addAllUpList(upList)
          ..refresh();
      }
    }

    return true;
  }
}
