import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:get/get.dart';

class RelatedController
    extends CommonListController<List<HotVideoItemModel>?, HotVideoItemModel> {
  RelatedController({this.autoQuery = true});
  String bvid = Get.arguments['bvid'];
  final bool autoQuery;

  @override
  void onInit() {
    super.onInit();
    if (autoQuery) {
      queryData();
    }
  }

  @override
  Future<LoadingState<List<HotVideoItemModel>?>> customGetData() async {
    final state = await VideoHttp.relatedVideoList(bvid: bvid);
    return switch (state) {
      Success(:final response) => Success(
        response == null
            ? null
            : ShieldingAdapters.filterRelatedVideos(
                response,
                ShieldSettingsStore().snapshot(),
              ),
      ),
      _ => state,
    };
  }
}
