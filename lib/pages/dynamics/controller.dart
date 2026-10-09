import 'dart:async';

import 'package:PiliPlus/http/dynamics.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/common/dynamic/up_panel_position.dart';
import 'package:PiliPlus/models/dynamics/up.dart';
import 'package:PiliPlus/pages/common/common_data_controller.dart';
import 'package:PiliPlus/pages/dynamics_tab/controller.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/zen_mode.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' show TabController;

class DynamicsController
    extends CommonDataController<FollowUpModel, FollowUpModel>
    with GetTickerProviderStateMixin, AccountMixin {
  DynamicsController({UpPanelPosition? upPanelPosition})
    : upPanelPosition = upPanelPosition ?? Pref.upPanelPosition;

  TabController? _tabController;
  bool? _builtWithZen;
  bool _closed = false;
  Worker? _zenWorker;

  /// Controllers displaced by a Zen flip, released after the frame that
  /// stopped using them so no in-flight TabBar/TabBarView detaches early.
  final Set<TabController> _pendingTabDisposals = <TabController>{};

  /// Normal-mode selection remembered while Zen collapses the strip (R17).
  DynamicsTabType? _savedSelection;

  final Set<int> tempBannedList = <int>{};

  String? _offset;
  late int _page = 1;
  late bool _isEnd = false;
  Set<UpItem>? _cacheUpList;
  late int hostMid = -1, currentMid = -1;
  late bool showLiveUp = Pref.expandDynLivePanel;
  late final _showAllUp = Pref.dynamicsShowAllFollowedUp;

  final UpPanelPosition upPanelPosition;

  @override
  final AccountService accountService = Get.find<AccountService>();

  /// Tabs actually on screen for a Zen state: Zen keeps only 投稿 (R14),
  /// normal mode restores the full five-tab list (R18).
  static List<DynamicsTabType> visibleTabs({required bool zen}) => zen
      ? const <DynamicsTabType>[DynamicsTabType.video]
      : DynamicsTabType.values;

  /// `initialIndex` for a freshly created controller. Zen always starts on
  /// 投稿; normal mode keeps the stored default but clamps it into range so a
  /// stale `Pref.defaultDynamicTypeIndex` can never overflow the tab list
  /// (R17).
  static int initialIndexFor(int preferred, {required bool zen}) {
    final tabs = visibleTabs(zen: zen);
    if (tabs.length == 1) {
      return 0;
    }
    return preferred.clamp(0, tabs.length - 1);
  }

  /// Where an UP selection lands: normal mode jumps to 全部/UP as before, Zen
  /// collapses every selection onto 投稿 (R14).
  static int jumpTargetFor(int mid, {required bool zen}) {
    if (zen) {
      return 0;
    }
    final tabs = visibleTabs(zen: false);
    return tabs.indexOf(
      mid == -1 ? DynamicsTabType.all : DynamicsTabType.up,
    );
  }

  /// Resolves a strip index against the *visible* list — never
  /// `DynamicsTabType.values` — and returns null while the index is only
  /// momentarily out of range during a Zen flip (R17).
  static DynamicsTabType? tagForIndex(int index, {required bool zen}) {
    final tabs = visibleTabs(zen: zen);
    if (index < 0 || index >= tabs.length) {
      return null;
    }
    return tabs[index];
  }

  TabController get tabController {
    _syncTabController();
    return _tabController!;
  }

  DynamicsTabController? get controller {
    final tabController = this.tabController;
    final tag = tagForIndex(tabController.index, zen: ZenMode.isOn);
    if (tag == null || tabController.index >= tabController.length) {
      return null;
    }
    try {
      return Get.find<DynamicsTabController>(tag: tag.name);
    } catch (_) {
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _syncTabController();
    _zenWorker = ever(ZenMode.enabled, (_) => _syncTabController());
    queryData();
  }

  /// Swaps the TabController when the visible tab list changes, keeping the
  /// selected tab identity across the swap (R17) and parking the old
  /// controller for release after the current frame.
  void _syncTabController() {
    if (_closed) {
      return;
    }
    final bool zen = ZenMode.isOn;
    final TabController? old = _tabController;
    if (old != null && _builtWithZen == zen) {
      return;
    }

    final int nextLength = visibleTabs(zen: zen).length;
    final int nextIndex;
    if (old == null) {
      nextIndex = initialIndexFor(Pref.defaultDynamicTypeIndex, zen: zen);
    } else if (zen) {
      _savedSelection = tagForIndex(old.index, zen: false);
      nextIndex = 0;
    } else {
      final tabs = visibleTabs(zen: false);
      final DynamicsTabType? saved = _savedSelection;
      _savedSelection = null;
      final int restored = saved == null ? -1 : tabs.indexOf(saved);
      // A page born already-collapsed has nothing remembered, so fall back to
      // the clamped stored default instead of guessing.
      nextIndex = restored >= 0
          ? restored
          : initialIndexFor(Pref.defaultDynamicTypeIndex, zen: false);
    }

    final TabController next = TabController(
      vsync: this,
      length: nextLength,
      initialIndex: nextIndex.clamp(0, nextLength - 1),
    );

    if (old != null) {
      _pendingTabDisposals.add(old);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _releaseTabController(old);
      });
    }
    _tabController = next;
    _builtWithZen = zen;
  }

  /// Disposes a displaced controller exactly once: the pending set is the
  /// single owner, so a close that already swept it wins over a late callback.
  void _releaseTabController(TabController controller) {
    if (_pendingTabDisposals.remove(controller)) {
      controller.dispose();
    }
  }

  void _jumpToTab(int mid) {
    tabController.index = jumpTargetFor(mid, zen: ZenMode.isOn);
  }

  void onSelectUp(int mid) {
    if (ZenMode.isOn) {
      // R14/R17: the UP panel is hidden while Zen is on, so a stray selection
      // only lands on 投稿 — hostMid/currentMid and the UP controller stay
      // untouched and Zen OFF restores exactly the previous UP state.
      tabController.index = 0;
      return;
    }

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
    // Order matters: stop the zen worker first so a flip can no longer swap
    // controllers, then sweep the current controller together with anything
    // still parked for post-frame release — each exactly once.
    _closed = true;
    _zenWorker?.dispose();
    _zenWorker = null;

    final TabController? current = _tabController;
    final Set<TabController> toDispose = <TabController>{
      ..._pendingTabDisposals,
      ?current,
    };
    _pendingTabDisposals.clear();
    for (final controller in toDispose) {
      controller.dispose();
    }
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
