import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/recommendation_metrics.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

class RcmdController extends CommonListController {
  late bool enableSaveLastData = Pref.enableSaveLastData;
  final bool appRcmd = Pref.appRcmd;

  int? lastRefreshAt;
  late bool savedRcmdTip = Pref.savedRcmdTip;
  RecommendationPhaseMeasurement? _firstScreenMeasurement;
  bool _firstScreenReported = false;

  @override
  bool get isEnd => false;

  @override
  void onInit() {
    super.onInit();
    page = 0;
    _beginFirstScreenMeasurement();
    queryData();
  }

  bool get hasPendingFirstScreenMeasurement =>
      _firstScreenMeasurement != null && !_firstScreenReported;

  void recordFirstScreenVisible(int itemCount) {
    if (!hasPendingFirstScreenMeasurement) return;
    RecommendationMetrics.finishPhase(
      _firstScreenMeasurement,
      outputCount: itemCount,
    );
    _firstScreenMeasurement = null;
    _firstScreenReported = true;
  }

  void _beginFirstScreenMeasurement() {
    _firstScreenReported = false;
    _firstScreenMeasurement = RecommendationMetrics.startPhase(
      RecommendationPhase.firstScreenVisible,
      inputCount: 0,
    );
  }

  @override
  Future<LoadingState> customGetData() {
    return appRcmd
        ? VideoHttp.rcmdVideoListApp(freshIdx: page)
        : VideoHttp.rcmdVideoList(freshIdx: page, ps: 20);
  }

  @override
  bool handleError(String? errMsg) {
    return enableSaveLastData;
  }

  @override
  void handleListResponse(List dataList) {
    if (enableSaveLastData && page == 0) {
      if (loadingState.value case Success(:final response)) {
        if (response != null && response.isNotEmpty) {
          if (savedRcmdTip) {
            lastRefreshAt = dataList.length;
          }
          if (response.length > 200) {
            dataList.addAll(response.take(50));
          } else {
            dataList.addAll(response);
          }
        }
      }
    }
  }

  @override
  Future<void> onRefresh() {
    page = 0;
    isEnd = false;
    if (!isLoading) _beginFirstScreenMeasurement();
    return queryData();
  }
}
