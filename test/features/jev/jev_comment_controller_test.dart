import 'dart:async';

import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/jev/jev_comment_screening.dart';

import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/common/reply_controller.dart';
import 'package:PiliPlus/pages/video/reply_reply/controller.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

import 'jev_comment_screening_test.dart' show MemoryBox, Credentials;

typedef _Screen = Future<List<ReplyInfo>> Function(List<ReplyInfo>);

ReplyInfo _reply(
  int id,
  String message, [
  List<ReplyInfo> children = const [],
]) => ReplyInfo(
  id: Int64(id),
  content: Content(message: message),
  replies: children,
);

Future<List<ReplyInfo>> _hideAdvertising(List<ReplyInfo> replies) async {
  final visible = replies
      .where((r) => r.content.message != 'advertising')
      .toList();
  for (final reply in visible) {
    final children = await _hideAdvertising(reply.replies);
    reply.replies
      ..clear()
      ..addAll(children);
  }
  return visible;
}

class _MainController extends ReplyController<MainListReply> {
  _MainController(this.responses, {this.screen = _hideAdvertising});
  final List<MainListReply> responses;
  final _Screen? screen;
  int fetched = 0;
  @override
  dynamic get sourceId => 1;
  @override
  ShieldRuleSet get shieldingRuleSet => ShieldRuleSet(globalEnabled: false);
  @override
  CommentShieldingConfig get commentShieldingConfig =>
      const CommentShieldingConfig(minCharCount: 2);
  @override
  Future<List<ReplyInfo>> screenComments(List<ReplyInfo> replies) =>
      screen?.call(replies) ?? super.screenComments(replies);
  @override
  List<ReplyInfo> getDataList(MainListReply response) => response.replies;
  @override
  Future<LoadingState<MainListReply>> customGetData() async =>
      Success(responses[fetched++]);
}

class _CoreMainController extends _MainController {
  _CoreMainController(super.responses, this.service) : super(screen: null);
  final JevCommentScreening service;
  @override
  JevCommentScreening get commentScreening => service;
}

class _DetailController extends VideoReplyReplyController {
  _DetailController(
    this.response, {
    this.screen = _hideAdvertising,
    this.service,
    super.initialRoot,
    bool dialog = false,
  }) : super(
         hasRoot: initialRoot != null,
         id: null,
         oid: 1,
         rpid: 2,
         dialog: dialog ? 3 : null,
         replyType: 1,
       );
  final dynamic response;
  final _Screen? screen;
  final JevCommentScreening? service;
  @override
  JevCommentScreening get commentScreening => service ?? super.commentScreening;
  @override
  ShieldRuleSet get shieldingRuleSet => ShieldRuleSet(globalEnabled: false);
  @override
  CommentShieldingConfig get commentShieldingConfig =>
      const CommentShieldingConfig();
  @override
  Future<List<ReplyInfo>> screenComments(List<ReplyInfo> replies) =>
      screen?.call(replies) ?? super.screenComments(replies);
  @override
  Future<LoadingState> customGetData() async => Success(response);
}

MainListReply _page(
  List<ReplyInfo> replies, {
  int next = 1,
  bool end = false,
}) => MainListReply(
  replies: replies,
  cursor: CursorReply(next: Int64(next), isEnd: end),
  subjectControl: SubjectControl(count: Int64(20)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real queryData -> screening -> Jev transport hides roots and nested replies', () async {
    final store = JevSettingsStore(box: MemoryBox());
    await store.save(
      const JevSettings(
        enabled: true,
        commentEnabled: true,
        provider: JevProvider.openRouter,
        providerConfirmed: true,
      ),
    );
    final gate = Completer<void>();
    final sentTexts = <String>[];
    final service = JevCommentScreening(
      settings: store,
      credentials: Credentials(),
      transport: ({required provider, required apiKey, required body}) async {
        expect(provider, JevProvider.openRouter);
        final candidates = (body['state'] as Map)['candidates'] as Map;
        sentTexts.addAll(
          candidates.values.map((c) => (c as Map)['text'] as String).toList(),
        );
        await gate.future;
        return {
          'answers': {
            for (final entry in candidates.entries)
              entry.key: {
                'type': 'noul',
                'noul': (entry.value as Map)['text'] == 'advertising'
                    ? .95
                    : .01,
              },
          },
        };
      },
    );
    final controller = _CoreMainController([
      _page([
        _reply(1, 'advertising'),
        _reply(2, 'normal criticism', [
          _reply(3, 'advertising'),
          _reply(4, 'relevant', [_reply(5, 'x'), _reply(6, 'related joke')]),
        ]),
      ]),
    ], service);
    final pending = controller.queryData();
    await Future<void>.delayed(Duration.zero);
    expect(controller.loadingState.value, isA<Loading>());
    expect(sentTexts, ['advertising', 'normal criticism', 'advertising']);
    gate.complete();
    await pending;
    expect(sentTexts, [
      'advertising',
      'normal criticism',
      'advertising',
      'relevant',
      'related joke',
    ]);
    final root = controller.loadingState.value.data!.single;
    expect(root.id, Int64(2));
    expect(root.replies.single.id, Int64(4));
    expect(root.replies.single.replies.single.id, Int64(6));
  });

  test(
    'real transport failure retains comments and completes publication',
    () async {
      final store = JevSettingsStore(box: MemoryBox());
      await store.save(
        const JevSettings(
          enabled: true,
          commentEnabled: true,
          provider: JevProvider.openRouter,
          providerConfirmed: true,
        ),
      );
      final controller = _CoreMainController(
        [
          _page([_reply(1, 'uncertain')]),
        ],
        JevCommentScreening(
          settings: store,
          credentials: Credentials(),
          transport: ({
            required provider,
            required apiKey,
            required body,
          }) async => throw StateError('offline'),
        ),
      );
      await controller.queryData();
      expect(controller.loadingState.value.data!.single.id, Int64(1));
      expect(controller.isLoading, isFalse);
    },
  );

  test(
    'queryData awaits semantic decisions, after cheap rules, before publish',
    () async {
      final gate = Completer<List<ReplyInfo>>();
      List<ReplyInfo>? received;
      final controller = _MainController(
        [
          _page([
            _reply(1, 'x'),
            _reply(2, 'advertising'),
            _reply(3, 'normal criticism', [
              _reply(4, 'advertising'),
              _reply(5, 'relevant'),
            ]),
          ]),
        ],
        screen: (replies) {
          received = replies;
          return gate.future;
        },
      );
      final pending = controller.queryData();
      await Future<void>.delayed(Duration.zero);
      expect(controller.loadingState.value, isA<Loading>());
      expect(controller.isLoading, isTrue);
      expect(received!.map((r) => r.id.toInt()), [2, 3]);
      gate.complete(await _hideAdvertising(received!));
      await pending;
      expect(controller.loadingState.value.data!.map((r) => r.id.toInt()), [3]);
      expect(
        controller.loadingState.value.data!.single.replies.map(
          (r) => r.id.toInt(),
        ),
        [5],
      );
      expect(controller.isLoading, isFalse);
    },
  );

  test(
    'filtered-empty page advances cursor and allows append until source ends',
    () async {
      final controller = _MainController([
        _page([_reply(1, 'advertising')], next: 11),
        _page([_reply(2, 'relevant')], next: 22),
        _page([
          _reply(3, 'advertising'),
          _reply(4, 'normal criticism'),
        ], end: true),
      ]);
      await controller.queryData();
      expect(controller.loadingState.value.data, isEmpty);
      expect(controller.isEnd, isFalse);
      expect(controller.cursorNext, Int64(11));
      expect(controller.page, 2);
      await controller.queryData(false);
      await controller.queryData(false);
      expect(controller.loadingState.value.data!.map((r) => r.id.toInt()), [
        2,
        4,
      ]);
      expect(controller.isEnd, isTrue);
      expect(controller.fetched, 3);
    },
  );

  test('refresh replaces visible comments after awaited screening', () async {
    final controller = _MainController([
      _page([_reply(1, 'relevant')]),
      _page([_reply(2, 'advertising'), _reply(3, 'new relevant')]),
    ]);
    await controller.queryData();
    await controller.onRefresh();
    expect(controller.loadingState.value.data!.map((r) => r.id.toInt()), [3]);
  });

  test('detail root and children wait; each is screened once', () async {
    final childGate = Completer<List<ReplyInfo>>();
    final calls = <List<int>>[];
    final children = [_reply(3, 'advertising'), _reply(4, 'relevant')];
    final controller = _DetailController(
      DetailListReply(
        root: _reply(2, 'advertising', children),
        cursor: CursorReply(isEnd: true),
      ),
      screen: (replies) {
        calls.add(replies.map((r) => r.id.toInt()).toList());
        expect(replies.first.replies, isEmpty);
        return childGate.future;
      },
    );
    final pending = controller.queryData();
    await Future<void>.delayed(Duration.zero);
    expect(controller.firstFloor.value, isNull);
    expect(controller.loadingState.value, isA<Loading>());
    childGate.complete(await _hideAdvertising(children));
    await pending;
    expect(calls, [
      [2, 3, 4],
    ]);
    expect(controller.firstFloor.value, isNull);
    expect(controller.loadingState.value.data!.map((r) => r.id.toInt()), [4]);
  });

  test(
    'detail visible root is published only after its children finish',
    () async {
      final gate = Completer<List<ReplyInfo>>();
      ReplyInfo? receivedRoot;
      final controller = _DetailController(
        DetailListReply(
          root: _reply(2, 'normal criticism', [_reply(3, 'advertising')]),
          cursor: CursorReply(isEnd: true),
        ),
        screen: (replies) {
          receivedRoot = replies.first;
          return gate.future;
        },
      );
      final pending = controller.queryData();
      await Future<void>.delayed(Duration.zero);
      expect(controller.firstFloor.value, isNull);
      gate.complete([receivedRoot!]);
      await pending;
      expect(controller.firstFloor.value!.id, Int64(2));
      expect(controller.firstFloor.value!.replies, isEmpty);
      expect(controller.loadingState.value.data, isEmpty);
    },
  );

  test('detail root still screened when server supplies no children', () async {
    final controller = _DetailController(
      DetailListReply(root: _reply(2, 'advertising')),
    );
    await controller.queryData();
    expect(controller.firstFloor.value, isNull);
    expect(controller.loadingState.value.data, isEmpty);
    expect(controller.isEnd, isTrue);
  });

  test(
    'real detail chain screens root despite an empty child source',
    () async {
      final store = JevSettingsStore(box: MemoryBox());
      await store.save(
        const JevSettings(
          enabled: true,
          commentEnabled: true,
          provider: JevProvider.openRouter,
          providerConfirmed: true,
        ),
      );
      var called = false;
      final controller = _DetailController(
        DetailListReply(root: _reply(2, 'advertising')),
        screen: null,
        service: JevCommentScreening(
          settings: store,
          credentials: Credentials(),
          transport:
              ({required provider, required apiKey, required body}) async {
                called = true;
                expect(
                  ((body['state'] as Map)['candidates'] as Map)['candidate_1'],
                  {'text': 'advertising'},
                );
                return {
                  'answers': {
                    'candidate_1': {'type': 'noul', 'noul': .95},
                  },
                };
              },
        ),
      );
      await controller.queryData();
      expect(called, isTrue);
      expect(controller.firstFloor.value, isNull);
      expect(controller.loadingState.value.data, isEmpty);
    },
  );

  test(
    'preloaded root waits for current policy and cannot bypass screening',
    () async {
      final gate = Completer<List<ReplyInfo>>();
      final preloaded = _reply(2, 'advertising', [_reply(9, 'old preview')]);
      List<ReplyInfo>? candidates;
      final controller = _DetailController(
        DetailListReply(
          root: _reply(2, 'server root', [_reply(3, 'relevant')]),
          cursor: CursorReply(isEnd: true),
        ),
        initialRoot: preloaded,
        screen: (replies) {
          candidates = replies;
          return gate.future;
        },
      );
      final pending = controller.queryData();
      await Future<void>.delayed(Duration.zero);
      expect(controller.firstFloor.value, isNull);
      expect(candidates!.first.content.message, 'advertising');
      expect(candidates!.first.replies, isEmpty);
      gate.complete(await _hideAdvertising(candidates!));
      await pending;
      expect(controller.firstFloor.value, isNull);
      expect(controller.loadingState.value.data!.single.id, Int64(3));
      expect(preloaded.replies.single.id, Int64(9));
    },
  );

  test('dialog real controller filters before publishing and retains uncertain replies', () async {
    final controller = _DetailController(
      DialogListReply(
        replies: [_reply(3, 'advertising'), _reply(4, 'uncertain')],
        cursor: CursorReply(isEnd: true),
      ),
      dialog: true,
    );
    await controller.queryData();
    expect(controller.loadingState.value.data!.map((r) => r.id.toInt()), [4]);
    expect(controller.firstFloor.value, isNull);
  });
}
