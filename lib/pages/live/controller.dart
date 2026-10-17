import 'package:PiliPlus/common/widgets/pair.dart';
import 'package:PiliPlus/features/jev/jev_final_screen.dart';
import 'package:PiliPlus/features/shielding/live_follow_exempt.dart';
import 'package:PiliPlus/features/shielding/live_shielding.dart';
import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/http/live.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data_list_item.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_list.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/data.dart';
import 'package:PiliPlus/models_new/live/live_second_list/data.dart';
import 'package:PiliPlus/models_new/live/live_second_list/tag.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:flutter/widgets.dart' show ScrollController;
import 'package:get/get.dart';

class LiveController extends CommonListController with AccountMixin {
  LiveController({
    ShieldRuleSet Function()? ruleSetProvider,
    Future<Set<int>?> Function()? followRoomIdsProvider,
  }) : _ruleSetProvider = ruleSetProvider ?? _storedRuleSet,
       _followRoomIdsProvider =
           followRoomIdsProvider ?? LiveFollowExempt.followedRoomIds;

  final ShieldRuleSet Function() _ruleSetProvider;

  /// 已关注主播房间号来源（issue #115）。进程内按控制器实例记忆一次：
  /// 刷新不重取，切换账号时重置。测试注入替身避免触网。
  /// 返回 null = 关注状态未知（查询失败），调用方保留候选并跳过所有直播过滤。
  final Future<Set<int>?> Function() _followRoomIdsProvider;
  Future<Set<int>?>? _followedRoomIdsFuture;

  Future<Set<int>?> _followedRoomIds() =>
      _followedRoomIdsFuture ??= () async {
        try {
          return await _followRoomIdsProvider();
        } catch (_) {
          // 关注查询异常 → 状态未知（不能当作未关注，issue #115）。
          return null;
        }
      }();

  /// Keeps this feature independent of any in-flight runtime hook: the rules
  /// are read straight from the shielding store on every page load.
  static ShieldRuleSet _storedRuleSet() => ShieldSettingsStore().snapshot();

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  int? count;

  /// Size of the latest source page, before live shielding removed anything.
  int sourcePageCount = 0;

  /// Cards live shielding removed from the loaded pages so far.
  int hiddenCardCount = 0;

  /// Set when the loaded page was fully hidden, so automatic paging stops
  /// instead of requesting more pages to refill the grid with blocked cards.
  bool autoPagingPaused = false;

  int _lastRawPageSize = 0;

  /// Raw cards accepted from the server, used to decide source exhaustion.
  /// The visible count must never drive this: shielding shortens it.
  int _sourceLoadedCount = 0;

  /// True when the visible list is empty only because live shielding removed
  /// every loaded card, which stays distinguishable from a server empty page.
  bool get isFilteredEmpty => sourcePageCount > 0;

  // area
  int? areaId;
  String? sortType;
  int? parentAreaId;
  final RxInt areaIndex = 0.obs;

  // tag
  final RxInt tagIndex = 0.obs;
  List<LiveSecondTag>? newTags;

  final Rx<Pair<LiveCardList?, LiveCardList?>> topState =
      Pair<LiveCardList?, LiveCardList?>(first: null, second: null).obs;

  final followController = ScrollController();

  bool showFirstFrame = false;

  @override
  void checkIsEnd(int length) {
    if (count != null && _sourceLoadedCount >= count!) {
      isEnd = true;
    }
  }

  @override
  List? getDataList(response) {
    final dataList = response.cardList as List?;
    _lastRawPageSize = dataList?.length ?? 0;
    sourcePageCount = _lastRawPageSize;
    _sourceLoadedCount += _lastRawPageSize;
    return dataList;
  }

  @override
  Future<void> handleListResponse(List dataList) async {
    final before = dataList.length;
    // 已关注主播豁免所有直播过滤（含硬屏蔽与 Jev，issue #115）。
    final followed = await _followedRoomIds();
    if (followed == null) {
      // 关注查询失败 → 状态未知 → 保留候选，跳过所有直播过滤（issue #115）。
      return;
    }
    LiveShielding.removeBlocked(
      dataList,
      _ruleSetProvider(),
      exemptRoomIds: followed,
    );
    final visible = await JevFinalScreen.live<dynamic>(
      followedRoomIds: followed,
    ).screen(dataList);
    if (isClosed) return;
    if (!identical(visible, dataList)) {
      dataList
        ..clear()
        ..addAll(visible);
    }
    final removed = before - dataList.length;
    hiddenCardCount += removed;
    autoPagingPaused = removed > 0 && removed == _lastRawPageSize;
  }

  /// Re-applies the live rules to the already loaded page, so a rule saved from
  /// a card entry removes every newly matching card without another request.
  /// 已关注主播豁免同样生效（issue #115）。
  Future<int> refilterLoadedItems() async {
    if (loadingState.value case Success(:final response)) {
      final items = response;
      if (items == null || items.isEmpty) return 0;
      final followed = await _followedRoomIds();
      if (followed == null) return 0; // 关注状态未知 → 不动已加载列表。
      final removed = LiveShielding.removeBlocked(
        items,
        _ruleSetProvider(),
        exemptRoomIds: followed,
      );
      if (removed == 0) return 0;
      hiddenCardCount += removed;
      loadingState.refresh();
      return removed;
    }
    return 0;
  }

  /// Clears the pause left by a fully hidden page. Driven by an actual user
  /// scroll gesture, which is what makes the next page a user request instead
  /// of a chain request caused by shielding.
  Future<void> resumeAutoPaging() async {
    if (!autoPagingPaused) return;
    autoPagingPaused = false;
    if (isEnd || isLoading) return;
    if (!scrollController.hasClients) return;
    if (scrollController.position.extentAfter > 8) return;
    await onLoadMore();
  }

  @override
  Future<void> onLoadMore() {
    if (autoPagingPaused) return Future.value();
    return super.onLoadMore();
  }

  @override
  bool customHandleResponse(bool isRefresh, Success response) {
    if (isRefresh) {
      sourcePageCount = 0;
      hiddenCardCount = 0;
      autoPagingPaused = false;
      _lastRawPageSize = 0;
      _sourceLoadedCount = 0;
      final res = response.response;
      if (res is LiveIndexData) {
        if (res.hasMore == 0) {
          isEnd = true;
        }
        topState.value = Pair(first: res.followItem, second: res.areaItem);
      } else if (res is LiveSecondData) {
        count = res.count;
        newTags = res.newTags;
        if (sortType != null) {
          tagIndex.value =
              newTags?.indexWhere((e) => e.sortType == sortType) ?? -1;
        }
      }
    }
    return false;
  }

  @override
  Future<LoadingState> customGetData() {
    if (areaIndex.value != 0) {
      return LiveHttp.liveSecondList(
        pn: page,
        areaId: areaId,
        parentAreaId: parentAreaId,
        sortType: sortType,
      );
    }
    return LiveHttp.liveFeedIndex(pn: page);
  }

  @override
  Future<void> onRefresh() {
    if (isLoading || isClosed) return Future.value();
    count = null;
    page = 1;
    isEnd = false;
    if (areaIndex.value != 0) {
      queryTop().whenComplete(followController.jumpToTop);
      return queryData();
    }
    return queryData().whenComplete(followController.jumpToTop);
  }

  Future<void> queryTop() async {
    final res = await LiveHttp.liveFeedIndex(pn: page, moduleSelect: true);
    if (res case Success(:final response)) {
      topState.value = Pair(
        first: response.followItem,
        second: response.areaItem,
      );
      areaIndex.value =
          (response.areaItem?.cardData?.areaEntranceV3?.list?.indexWhere(
                (e) => e.areaV2Id == areaId && e.areaV2ParentId == parentAreaId,
              ) ??
              -2) +
          1;
    }
  }

  void onSelectArea(int index, CardLiveItem? cardLiveItem) {
    if (isLoading) {
      return; // areaIndex conflict
    }
    if (index == areaIndex.value) {
      return;
    }
    tagIndex.value = 0;
    newTags = null;
    sortType = null;
    areaIndex.value = index;
    areaId = cardLiveItem?.areaV2Id;
    parentAreaId = cardLiveItem?.areaV2ParentId;

    count = null;
    page = 1;
    isEnd = false;
    queryData();
  }

  void onSelectTag(int index, String? sortType) {
    if (isLoading) {
      return;
    }
    tagIndex.value = index;
    this.sortType = sortType;

    count = null;
    page = 1;
    isEnd = false;
    queryData();
  }

  @override
  void onChangeAccount(bool isLogin) {
    // 换账号后关注列表变了，豁免集随之失效。
    _followedRoomIdsFuture = null;
    onReload();
  }

  @override
  void onClose() {
    followController.dispose();
    super.onClose();
  }
}
