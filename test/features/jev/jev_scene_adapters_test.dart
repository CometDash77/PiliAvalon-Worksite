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

ReplyInfo _reply(String body, {List<ReplyInfo>? children}) => ReplyInfo(
  content: Content(message: body),
  replies: children,
);

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
    'video target lookup waits for screening and uses the visible index',
    () async {
      final evaluator = _Evaluator()..waitFor = Completer<void>();
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
      final pending = controller.handleListResponse(replies);
      expect(controller.jumpedTo, isNull);
      evaluator.waitFor!.complete();
      await pending;
      expect(replies.map((r) => r.id.toInt()), [42]);
      expect(controller.jumpedTo, 0);
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
    'comments filter roots and previews while retaining parent body and counts',
    () async {
      final evaluator = _Evaluator();
      final root = _reply('keep', children: [_reply('hide'), _reply('child')])
        ..count = Int64(10);
      final visible = await JevFinalScreen.comments([
        root,
        _reply('hide'),
      ], evaluator: evaluator);
      expect(visible, [root]);
      expect(root.replies.map((reply) => reply.content.message), ['child']);
      expect(root.count.toInt(), 10);
      expect(
        evaluator.calls.every((call) => call.$1 == JevSurface.comment),
        isTrue,
      );
      expect(evaluator.calls.last.$2.first.toContext(), {
        'title': 'hide',
        'snippet': 'keep',
      });
    },
  );

  test(
    'empty bodies stay visible and failures preserve source order',
    () async {
      final evaluator = _Evaluator()..fail = true;
      final items = [_reply(''), _reply('hide'), _reply('keep')];
      final result = await JevFinalScreen.comment(evaluator: evaluator)
          .screen(items);
      expect(identical(result, items), isTrue);
      expect(evaluator.calls.single.$2.map((candidate) => candidate.title), [
        'hide',
        'keep',
      ]);
    },
  );

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
