import 'dart:io';

import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_item_grpc.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  setUpAll(() async {
    try {
      final dir = Directory.systemTemp.createTempSync('hive_test_');
      Hive.init(dir.path);
      GStorage.setting = await Hive.openBox('setting');
      GStorage.localCache = await Hive.openBox('localCache');
      GStorage.reply = null;
    } catch (_) {
      // Already initialized by another test file in the same isolate.
    }
  });

  group('comment decoration quick actions', () {
    testWidgets('avatar pendant action appears and creates comment rule', (
      tester,
    ) async {
      final store = ShieldSettingsStore(box: _MemoryBox());
      final reply = _reply(
        member: Member(
          mid: Int64(42),
          name: '评论者',
          garbPendantImage: 'https://i0.hdslb.com/pendant.png',
        ),
      );

      await _pumpReply(tester, reply: reply, store: store);
      await tester.longPress(find.byType(ReplyItemGrpc));
      await tester.pumpAndSettle();

      expect(find.text('屏蔽头像挂件'), findsOneWidget);
      await tester.tap(find.text('屏蔽头像挂件'));
      await tester.pumpAndSettle();

      final rules = (await store.load()).rules;
      expect(rules, hasLength(1));
      expect(rules.single.type, ShieldRuleType.avatarPendant);
      expect(rules.single.scope, ShieldScope.comment);
      expect(rules.single.matchMode, ShieldMatchMode.exact);
      expect(rules.single.pattern, 'https://i0.hdslb.com/pendant.png');
    });

    testWidgets('garb action appears and creates comment rule', (tester) async {
      final store = ShieldSettingsStore(box: _MemoryBox());
      final reply = _reply(
        memberV2: MemberV2(
          garb: MemberV2_Garb(cardNumber: 'NO.0002'),
        ),
      );

      await _pumpReply(tester, reply: reply, store: store);
      await tester.longPress(find.byType(ReplyItemGrpc));
      await tester.pumpAndSettle();

      expect(find.text('屏蔽装扮卡片'), findsOneWidget);
      await tester.tap(find.text('屏蔽装扮卡片'));
      await tester.pumpAndSettle();

      final rules = (await store.load()).rules;
      expect(rules, hasLength(1));
      expect(rules.single.type, ShieldRuleType.garb);
      expect(rules.single.scope, ShieldScope.comment);
      expect(rules.single.matchMode, ShieldMatchMode.exact);
      expect(rules.single.pattern, 'NO.0002');
    });

    testWidgets('decoration actions are hidden when data is absent', (
      tester,
    ) async {
      await _pumpReply(tester, reply: _reply());
      await tester.longPress(find.byType(ReplyItemGrpc));
      await tester.pumpAndSettle();

      expect(find.text('屏蔽头像挂件'), findsNothing);
      expect(find.text('屏蔽装扮卡片'), findsNothing);
    });
  });
}

Future<void> _pumpReply(
  WidgetTester tester, {
  required ReplyInfo reply,
  ShieldSettingsStore? store,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      home: Scaffold(
        body: ReplyItemGrpc(
          replyItem: reply,
          replyLevel: 1,
          needDivider: false,
          shieldSettingsStore: store,
        ),
      ),
    ),
  );
  await tester.pump();
}

ReplyInfo _reply({
  Member? member,
  MemberV2? memberV2,
}) => ReplyInfo(
  id: Int64(1),
  oid: Int64(2),
  type: Int64(1),
  mid: Int64(42),
  ctime: Int64(1),
  member: member ?? Member(mid: Int64(42), name: '评论者'),
  memberV2: memberV2,
  content: Content(message: 'hello'),
  replyControl: ReplyControl(),
);

class _MemoryBox implements ShieldSettingsBox {
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
