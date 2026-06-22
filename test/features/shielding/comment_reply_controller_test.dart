// ignore_for_file: unnecessary_lambdas

import 'dart:io';

import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/common/reply_controller.dart';
import 'package:PiliPlus/pages/video/reply_reply/controller.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  setUpAll(() async {
    try {
      final dir = Directory.systemTemp.createTempSync('hive_test_');
      Hive.init(dir.path);
      GStorage.setting = await Hive.openBox('setting');
    } catch (_) {
      // Already initialized by another test file in the same isolate.
    }
  });

  group('ReplyController comment shielding', () {
    test('filters nested preview replies with comment scoped rules', () {
      final ruleSet = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'spoiler',
            type: ShieldRuleType.keyword,
            matchMode: ShieldMatchMode.contains,
            scope: ShieldScope.comment,
            action: ShieldAction.block,
            pattern: '剧透',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );
      final parent = ReplyInfo(
        id: Int64(1),
        mid: Int64(1),
        content: Content(message: '正常主评论'),
        member: Member(mid: Int64(1), name: '用户A'),
        replies: [
          ReplyInfo(
            id: Int64(2),
            mid: Int64(2),
            content: Content(message: '正常子评论'),
            member: Member(mid: Int64(2), name: '用户B'),
          ),
          ReplyInfo(
            id: Int64(3),
            mid: Int64(3),
            content: Content(message: '剧透子评论'),
            member: Member(mid: Int64(3), name: '用户C'),
          ),
        ],
      );

      final visible = _ReplyController(ruleSet).applyShielding([parent]);

      expect(visible, [parent]);
      expect(parent.replies.map((reply) => reply.id.toInt()), [2]);
    });

    test('filters first floor root reply in reply detail pages', () {
      final controller = _ReplyReplyController(
        ShieldRuleSet(
          rules: [
            ShieldRule(
              id: 'root-spoiler',
              type: ShieldRuleType.keyword,
              matchMode: ShieldMatchMode.contains,
              scope: ShieldScope.comment,
              action: ShieldAction.block,
              pattern: '剧透',
              updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          ],
        ),
      );
      final visibleRoot = ReplyInfo(
        id: Int64(1),
        mid: Int64(1),
        content: Content(message: '正常楼层'),
        member: Member(mid: Int64(1), name: '用户A'),
      );
      final blockedRoot = ReplyInfo(
        id: Int64(2),
        mid: Int64(2),
        content: Content(message: '剧透楼层'),
        member: Member(mid: Int64(2), name: '用户B'),
      );

      expect(controller.applyFirstFloorShielding(visibleRoot), visibleRoot);
      expect(controller.applyFirstFloorShielding(blockedRoot), isNull);
    });

    test('legacy reply keyword path obeys comment scene switch', () {
      addTearDown(() {
        ReplyGrpc.replyRegExp = RegExp('', caseSensitive: false);
        ReplyGrpc.enableFilter = false;
        ReplyGrpc.useLegacyTextFilter = false;
        ReplyGrpc.antiGoodsReply = false;
        ReplyGrpc.shieldRuleSetProvider = null;
      });

      ReplyGrpc.replyRegExp = RegExp('剧透', caseSensitive: false);
      ReplyGrpc.enableFilter = true;
      ReplyGrpc.useLegacyTextFilter = true;
      ReplyGrpc.antiGoodsReply = false;
      ReplyGrpc.shieldRuleSetProvider = () => ShieldRuleSet(
        commentEnabled: false,
        rules: [
          ShieldRule(
            id: 'old-comment',
            type: ShieldRuleType.keyword,
            matchMode: ShieldMatchMode.exact,
            scope: ShieldScope.comment,
            action: ShieldAction.block,
            pattern: '剧透',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      final reply = ReplyInfo(content: Content(message: '剧透评论'));

      expect(ReplyGrpc.needRemoveGrpc(reply), isFalse);
    });

    test(
      'legacy reply keyword path is disabled after merge into shielding',
      () {
        addTearDown(() {
          ReplyGrpc.replyRegExp = RegExp('', caseSensitive: false);
          ReplyGrpc.enableFilter = false;
          ReplyGrpc.useLegacyTextFilter = false;
          ReplyGrpc.antiGoodsReply = false;
          ReplyGrpc.shieldRuleSetProvider = null;
        });

        ReplyGrpc.replyRegExp = RegExp('剧透', caseSensitive: false);
        ReplyGrpc.enableFilter = true;
        ReplyGrpc.antiGoodsReply = false;
        ReplyGrpc.shieldRuleSetProvider = () => ShieldRuleSet();

        final reply = ReplyInfo(content: Content(message: '剧透评论'));

        expect(ReplyGrpc.needRemoveGrpc(reply), isFalse);
      },
    );
  });

  group('ReplyController config + rule composition', () {
    test(
      'config level threshold removes parent reply and children disappear',
      () {
        final ruleSet = ShieldRuleSet();
        const config = CommentShieldingConfig(levelThreshold: 5);
        final parent = ReplyInfo(
          id: Int64(1),
          mid: Int64(1),
          content: Content(message: '正常主评论'),
          member: Member(
            mid: Int64(1),
            name: '用户A',
            level: Int64(2),
          ),
          replies: [
            ReplyInfo(
              id: Int64(2),
              mid: Int64(2),
              content: Content(message: '子评论'),
              member: Member(mid: Int64(2), name: '用户B', level: Int64(6)),
            ),
          ],
        );

        final visible = _ConfigurableReplyController(
          ruleSet,
          config,
        ).applyShielding([parent]);

        expect(visible, isEmpty);
      },
    );

    test(
      'config gender filter removes only matching child reply',
      () {
        final ruleSet = ShieldRuleSet();
        const config = CommentShieldingConfig(genderFilter: ['女']);
        final parent = ReplyInfo(
          id: Int64(1),
          mid: Int64(1),
          content: Content(message: '正常主评论'),
          member: Member(mid: Int64(1), name: '用户A', sex: '男'),
          replies: [
            ReplyInfo(
              id: Int64(2),
              mid: Int64(2),
              content: Content(message: '正常子评论'),
              member: Member(mid: Int64(2), name: '用户B', sex: '男'),
            ),
            ReplyInfo(
              id: Int64(3),
              mid: Int64(3),
              content: Content(message: '被屏蔽子评论'),
              member: Member(mid: Int64(3), name: '用户C', sex: '女'),
            ),
          ],
        );

        final visible = _ConfigurableReplyController(
          ruleSet,
          config,
        ).applyShielding([parent]);

        expect(visible, [parent]);
        expect(parent.replies.map((r) => r.id.toInt()), [2]);
      },
    );

    test(
      'config filtering works when ShieldRuleSet.commentEnabled is false',
      () {
        final ruleSet = ShieldRuleSet(commentEnabled: false);
        const config = CommentShieldingConfig(levelThreshold: 5);
        final parent = ReplyInfo(
          id: Int64(1),
          mid: Int64(1),
          content: Content(message: '低等级评论'),
          member: Member(
            mid: Int64(1),
            name: '用户A',
            level: Int64(2),
          ),
        );

        final visible = _ConfigurableReplyController(
          ruleSet,
          config,
        ).applyShielding([parent]);

        expect(visible, isEmpty);
      },
    );

    test(
      'existing comment keyword rule obeys ShieldRuleSet.commentEnabled',
      () {
        final ruleSet = ShieldRuleSet(
          commentEnabled: false,
          rules: [
            ShieldRule(
              id: 'spoiler',
              type: ShieldRuleType.keyword,
              matchMode: ShieldMatchMode.exact,
              scope: ShieldScope.comment,
              action: ShieldAction.block,
              pattern: '剧透',
              updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          ],
        );
        const config = CommentShieldingConfig();
        final parent = ReplyInfo(
          id: Int64(1),
          mid: Int64(1),
          content: Content(message: '剧透评论'),
          member: Member(mid: Int64(1), name: '用户A'),
        );

        final visible = _ConfigurableReplyController(
          ruleSet,
          config,
        ).applyShielding([parent]);

        expect(visible, [parent]);
      },
    );
  });
}

class _ReplyController extends ReplyController<MainListReply> {
  _ReplyController(this.ruleSet);

  final ShieldRuleSet ruleSet;

  @override
  ShieldRuleSet get shieldingRuleSet => ruleSet;

  @override
  Object get sourceId => 1;

  @override
  Future<LoadingState<MainListReply>> customGetData() {
    throw UnimplementedError();
  }
}

class _ConfigurableReplyController extends ReplyController<MainListReply> {
  _ConfigurableReplyController(this._ruleSet, this._config);

  final ShieldRuleSet _ruleSet;
  final CommentShieldingConfig _config;

  @override
  ShieldRuleSet get shieldingRuleSet => _ruleSet;

  @override
  CommentShieldingConfig get commentShieldingConfig => _config;

  @override
  Object get sourceId => 1;

  @override
  Future<LoadingState<MainListReply>> customGetData() {
    throw UnimplementedError();
  }
}

class _ReplyReplyController extends VideoReplyReplyController {
  _ReplyReplyController(this.ruleSet)
    : super(
        hasRoot: false,
        id: null,
        oid: 1,
        rpid: 1,
        dialog: null,
        replyType: 1,
      );

  final ShieldRuleSet ruleSet;

  @override
  ShieldRuleSet get shieldingRuleSet => ruleSet;

  @override
  void jumpToItem(int index) {}
}
