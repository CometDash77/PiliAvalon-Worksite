import 'dart:async';

import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_evaluator.dart';
import 'package:PiliPlus/features/jev/jev_final_screen.dart';
import 'package:PiliPlus/features/jev/jev_preference_store.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data_list_item.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_list.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/pages/video/reply_reply/controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';

class _MemoryBox implements JevSettingsBox {
  final values = <String, Object?>{};

  @override
  Object? get(String key, {Object? defaultValue}) =>
      values.containsKey(key) ? values[key] : defaultValue;

  @override
  Future<void> put(String key, Object? value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _Evaluator extends JevEvaluator {
  _Evaluator()
    : super(
        settings: JevSettingsStore(box: _MemoryBox()),
        preferences: JevPreferenceStore(box: _MemoryBox()),
      );
  final calls = <(JevSurface, List<JevCandidate>)>[];
  bool fail = false;
  Completer<void>? waitFor;

  @override
  Future<JevScreening> screen(
    List<JevCandidate> candidates, {
    required JevSurface surface,
    Duration? passTimeout,
  }) async {
    if (waitFor != null) await waitFor!.future;
    calls.add((surface, candidates));
    if (fail) throw StateError('offline');
    return JevScreening(
      status: JevScreenStatus.evaluated,
      hidden: candidates.map((candidate) => candidate.title == 'hide').toList(),
    );
  }
}

class _VideoReplies extends VideoReplyReplyController {
  _VideoReplies(JevEvaluator evaluator)
    : super(
        hasRoot: false,
        id: 42,
        oid: 1,
        rpid: 1,
        dialog: null,
        replyType: 1,
        isVideoDetail: true,
        jevEvaluator: evaluator,
      );
  int? jumpedTo;
  @override
  List<ReplyInfo> applyShielding(List<ReplyInfo> replies) => replies;
  @override
  void jumpToItem(int index) {
    jumpedTo = index;
  }
}


class _PageController extends CommonListController<List<int>, int> {
  @override
  Future<LoadingState<List<int>>> customGetData() async =>
      Success(List.of(const [1, 2]));

  @override
  Future<void> handleListResponse(List<int> items) async {
    await Future<void>.delayed(Duration.zero);
    items.clear();
  }
}

void main() {
  test(
    // Comment screening left handleListResponse in issue #122: it now runs in
    // prepareListResponse -> screenComments. The jump targets the raw list
    // index immediately; downstream filtering reorders visible items.
    'video target lookup jumps to the raw list index without screening here',
    () async {
      final evaluator = _Evaluator();
      final controller = _VideoReplies(evaluator);
      final replies = [
        ReplyInfo(
          id: Int64(1),
          content: Content(message: 'hide'),
        ),
        ReplyInfo(
          id: Int64(42),
          content: Content(message: 'keep'),
        ),
      ];
      await controller.handleListResponse(replies);
      expect(controller.jumpedTo, 1);
      expect(evaluator.calls, isEmpty);
    },
  );
  test('live maps both source card shapes with only title and area', () async {
    final evaluator = _Evaluator();
    final raw = CardLiveItem(
      title: 'keep',
      areaName: '游戏',
      uid: 12,
      roomid: 34,
      uname: 'private',
    );
    final wrapped = LiveCardList.fromJson({
      'card_type': 'small_card_v1',
      'card_data': {
        'small_card_v1': {'title': 'hide', 'area_name': '聊天', 'uid': 56},
      },
    });
    final result = await JevFinalScreen.live<Object>(evaluator: evaluator)
        .screen([raw, wrapped]);
    expect(result, [raw]);
    expect(evaluator.calls.single.$1, JevSurface.live);
    expect(evaluator.calls.single.$2.first.toContext(), {
      'title': 'keep',
      'tags': ['游戏'],
    });
  });

  test(
    'all-filtered async page remains a successful nonterminal source page',
    () async {
      final controller = _PageController();
      await controller.queryData();
      expect(controller.loadingState.value.data, isEmpty);
      expect(controller.isEnd, isFalse);
      expect(controller.page, 2);
      expect(controller.isLoading, isFalse);
      controller.onClose();
    },
  );
}
