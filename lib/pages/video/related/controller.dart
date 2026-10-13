import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:get/get.dart';

class RelatedController
    extends CommonListController<List<HotVideoItemModel>?, HotVideoItemModel> {
  RelatedController({this.autoQuery = true, String? bvid})
    : bvid = bvid ?? Get.arguments['bvid'];
  String bvid;
  String? _queriedBvid;
  final bool autoQuery;

  @override
  void onInit() {
    super.onInit();
    if (autoQuery) {
      queryData();
    }
  }

  @override
  Future<LoadingState<List<HotVideoItemModel>?>> customGetData() {
    _queriedBvid = bvid;
    return VideoHttp.relatedVideoList(bvid: bvid);
  }

  /// 对齐当前详情视频。
  /// refresh=false（Zen ON，面板隐藏）：仅记录 bvid，不触发请求；
  /// 一致性依据是实际请求过的 _queriedBvid，而非 bvid——
  /// 否则"Zen 期间切集、恢复展示"会因 bvid 已同步而漏掉重查。
  void syncIfNeeded(String currentBvid, {bool refresh = true}) {
    bvid = currentBvid;
    if (!refresh || _queriedBvid == currentBvid) return;
    queryData();
  }
}
