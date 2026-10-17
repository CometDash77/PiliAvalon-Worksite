import 'package:PiliPlus/http/live.dart';
import 'package:PiliPlus/models_new/live/live_follow/data.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:get/get.dart';

/// 已关注主播的房间号目录（issue #115）：直播推荐里被关注的卡片豁免
/// 所有直播过滤（硬屏蔽与 Jev 语义过滤都不再作用）。
///
/// 数据来源是「已关注且开播」列表接口（xlive/web-ucenter/user/following）：
/// 推荐卡上的主播必然在播，因此按 roomid 匹配即可覆盖。
///
/// 失败语义（issue #115 已确认）：未登录按未关注处理，返回空集照常过滤；
/// 查询失败不能当作未关注——返回 null 表示「关注状态未知」，由调用方
/// 保留候选并跳过所有直播过滤。
abstract final class LiveFollowExempt {
  /// # ponytail: 上限 10 页 × 每页 50 = 500 个关注直播间；超过后新关注的
  /// 主播不再豁免。需要更大覆盖时把 maxPages 调大即可。
  static const int maxPages = 10;
  static const int pageSize = 50;

  /// null = 查询失败、关注状态未知；空集 = 未登录（或已登录无关注），
  /// 按未关注处理。
  static Future<Set<int>?> followedRoomIds() async {
    final loggedIn =
        Get.isRegistered<AccountService>() &&
        Get.find<AccountService>().isLogin.value;
    if (!loggedIn) return const <int>{};
    final rooms = <int>{};
    try {
      for (var page = 1; page <= maxPages; page++) {
        final res = await LiveHttp.liveFollow(page, pageSize: pageSize);
        if (res is! Success<LiveFollowData>) {
          return null;
        }
        final list = res.response.list;
        if (list == null || list.isEmpty) break;
        for (final item in list) {
          final roomid = item.roomid;
          if (roomid != null && roomid > 0) rooms.add(roomid);
        }
        final totalPage = res.response.totalPage;
        if (totalPage != null && totalPage > 0 && page >= totalPage) break;
        if (list.length < pageSize) break;
      }
    } catch (_) {
      return null;
    }
    return rooms;
  }
}
