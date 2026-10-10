import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo, DetailListReply, Mode;
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/common/publish/publish_route.dart';
import 'package:PiliPlus/pages/common/reply_controller.dart';
import 'package:PiliPlus/pages/video/reply_new/view.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class VideoReplyReplyController extends ReplyController
    with GetSingleTickerProviderStateMixin {
  VideoReplyReplyController({
    required this.hasRoot,
    required this.id,
    required this.oid,
    required this.rpid,
    required this.dialog,
    required this.replyType,
    this.initialRoot,
  });
  final int? dialog;
  int? id;
  // 视频aid 请求时使用的oid
  int oid;
  // rpid 请求楼中楼回复
  int rpid;
  int replyType;

  bool hasRoot = false;
  final ReplyInfo? initialRoot;
  final firstFloor = Rxn<ReplyInfo>();
  ReplyInfo? _screenedFirstFloor;
  bool _hasPendingFirstFloor = false;

  final index = RxnInt();

  final listController = ListController();

  AnimationController? _controller;
  AnimationController get animController => _controller ??= AnimationController(
    duration: const Duration(milliseconds: 1000),
    vsync: this,
  );

  late final horizontalPreview = Pref.horizontalPreview;

  @override
  dynamic get sourceId => replyType == 1 ? IdUtils.av2bv(oid) : oid;

  @override
  void onInit() {
    super.onInit();
    final cacheSortType = Pref.reply2SortType;
    sortType.value = cacheSortType;
    mode = cacheSortType == .time ? Mode.MAIN_LIST_TIME : Mode.MAIN_LIST_HOT;
    queryData();
  }

  @override
  List<ReplyInfo>? getDataList(response) {
    return dialog != null ? response.replies : response.root.replies;
  }

  @override
  bool customHandleResponse(bool isRefresh, Success response) {
    final data = response.response;

    subjectControl = data.subjectControl;
    upMid ??= data.subjectControl.upMid;
    paginationReply = data.paginationReply;
    isEnd = data.cursor.isEnd;

    // reply2Reply // isDialogue.not
    if (data is DetailListReply) {
      count.value = data.root.count.toInt();
    }

    return false;
  }

  @override
  Future<void> beforeListResponse(bool isRefresh, response) async {
    if (isRefresh && (response is DetailListReply || initialRoot != null)) {
      // Children are screened by the list pipeline. Screen only the root here.
      final source = initialRoot ?? (response as DetailListReply).root;
      _screenedFirstFloor = ReplyInfo.fromBuffer(source.writeToBuffer())
        ..replies.clear();
      _hasPendingFirstFloor = true;
    }
  }

  @override
  Future<void> prepareListResponse(List<ReplyInfo> dataList) async {
    if (!_hasPendingFirstFloor) {
      return super.prepareListResponse(dataList);
    }
    final root = _screenedFirstFloor!;
    handleListResponse(dataList);
    final visible = await screenComments([
      ...applyShielding([root]),
      ...dataList,
    ]);
    _screenedFirstFloor = visible.any((r) => identical(r, root)) ? root : null;
    dataList
      ..clear()
      ..addAll(visible.where((r) => !identical(r, root)));
  }

  @override
  void afterListResponse(bool isRefresh, response) {
    if (_hasPendingFirstFloor && isRefresh) {
      _screenedFirstFloor?.replies.addAll(getDataList(response) ?? []);
      firstFloor.value = _screenedFirstFloor;
      _screenedFirstFloor = null;
      _hasPendingFirstFloor = false;
    }
  }

  @override
  void handleListResponse(List<ReplyInfo> dataList) {
    if (id != null) {
      setIndexById(Int64(id!), dataList);
      id = null;
    }
    super.handleListResponse(dataList);
  }

  ReplyInfo? applyFirstFloorShielding(ReplyInfo reply) {
    final visible = applyShielding([reply]);
    return visible.isEmpty ? null : visible.single;
  }

  bool setIndexById(Int64 id64, [List<ReplyInfo>? replies]) {
    final index = (replies ?? loadingState.value.data!).indexWhere(
      (item) => item.id == id64,
    );
    if (index != -1) {
      this.index.value = index;
      jumpToItem(index);
      return true;
    }
    return false;
  }

  ExtendedNestedScrollController? nestedController;

  @pragma('vm:notify-debugger-on-exception')
  void jumpToItem(int index) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      animController.forward(from: 0);
      try {
        // ignore: invalid_use_of_visible_for_testing_member
        final offset = listController.getOffsetToReveal(index, 0.25);
        if (offset.isFinite) {
          if (nestedController case final nestedController?) {
            nestedController.nestedPositions.last.localJumpTo(offset);
          } else {
            scrollController.jumpTo(offset);
          }
        }
      } catch (_) {}
    });
  }

  @override
  Future<LoadingState> customGetData() => dialog != null
      ? ReplyGrpc.dialogList(
          type: replyType,
          oid: oid,
          root: rpid,
          dialog: dialog!,
          offset: paginationReply?.nextOffset,
        )
      : ReplyGrpc.detailList(
          type: replyType,
          oid: oid,
          root: rpid,
          rpid: id ?? 0,
          mode: mode,
          offset: paginationReply?.nextOffset,
        );

  @override
  Future<void> onReload() {
    if (loadingState.value.isSuccess) {
      index.value = null;
    }
    return super.onReload();
  }

  @override
  void onReply(
    ReplyInfo? replyItem, {
    int? oid,
    int? replyType,
    int? index,
  }) {
    assert(replyItem != null && index != null);

    final (bool inputDisable, String? hint) = replyHint;
    if (inputDisable) {
      return;
    }

    final oid = replyItem!.oid.toInt();
    final root = replyItem.id.toInt();
    final key = oid + root;

    Get.key.currentState!
        .push(
          PublishRoute(
            pageBuilder: (buildContext, animation, secondaryAnimation) {
              return ReplyPage(
                hint: hint,
                oid: oid,
                root: root,
                parent: root,
                replyType: this.replyType,
                replyItem: replyItem,
                items: savedReplies[key],
                onSave: (reply) {
                  if (reply.isEmpty) {
                    savedReplies.remove(key);
                  } else {
                    savedReplies[key] = reply.toList();
                  }
                },
              );
            },
          ),
        )
        .then((replyInfo) async {
          if (replyInfo is ReplyInfo) {
            savedReplies.remove(key);

            count.value += 1;
            final visible = await screenComments(applyShielding([replyInfo]));
            if (visible.isEmpty) {
              if (enableCommAntifraud) {
                onCheckReply(replyInfo, isManual: false);
              }
              return;
            }
            final replies = loadingState.value.dataOrNull;
            if (replies != null) {
              replies.insert((index! + 1).clamp(0, replies.length), replyInfo);
            }
            loadingState.refresh();
            if (enableCommAntifraud) {
              onCheckReply(replyInfo, isManual: false);
            }
          }
        });
  }

  @override
  void onClose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}
