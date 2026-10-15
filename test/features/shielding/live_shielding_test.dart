import 'package:PiliPlus/features/shielding/live_shielding.dart';
import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data_list_item.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveShielding candidate mapping', () {
    test('maps the live card onto a live scoped candidate', () {
      final candidate = LiveShielding.candidateFor(_card());

      expect(candidate.scope, ShieldScope.live);
      expect(candidate.title, '测试直播间');
      expect(candidate.uid, '1001');
      expect(candidate.authorName, '测试主播');
      expect(candidate.category, '虚拟主播');
      expect(candidate.roomId, '9527');
    });

    test('keeps non positive identities out of the candidate', () {
      final candidate = LiveShielding.candidateFor(_card(uid: 0, roomid: -1));

      expect(candidate.uid, isNull);
      expect(candidate.roomId, isNull);
    });

    test('resolves the card out of both grid shapes', () {
      final card = _card();
      final wrapper = LiveCardList(
        cardType: 'small_card_v1',
        cardData: CardData(smallCardV1: card),
      );

      expect(LiveShielding.cardOf(card), same(card));
      expect(LiveShielding.cardOf(wrapper), same(card));
      expect(LiveShielding.cardOf('not a card'), isNull);
      expect(LiveShielding.candidateOf('not a card'), isNull);
    });

    test('offers only the identities the card carries', () {
      expect(LiveShielding.targetsFor(_card()), [
        LiveShieldTarget.host,
        LiveShieldTarget.room,
      ]);
      expect(LiveShielding.targetsFor(_card(uid: null)), [
        LiveShieldTarget.room,
      ]);
      expect(LiveShielding.targetsFor(_card(roomid: null)), [
        LiveShieldTarget.host,
      ]);
      expect(LiveShielding.targetsFor(_card(uid: null, roomid: null)), isEmpty);
    });

    test('labels a target with the name it blocks', () {
      expect(LiveShielding.labelFor(_card(), LiveShieldTarget.host), '测试主播');
      expect(LiveShielding.labelFor(_card(), LiveShieldTarget.room), '测试直播间');
      expect(
        LiveShielding.labelFor(
          _card(uname: '  ', title: null),
          LiveShieldTarget.host,
        ),
        '主播 1001',
      );
    });
  });

  group('LiveShielding.removeBlocked', () {
    test('blocks by host uid and keeps a same title card', () {
      final items = <Object>[_card(uid: 1001), _card(uid: 2002)];

      expect(
        LiveShielding.removeBlocked(items, _rules([_uidRule('1001')])),
        1,
      );
      expect(items, hasLength(1));
      expect(_uidOf(items.single), 2002);
    });

    test('blocks by host name', () {
      final items = <Object>[
        _card(uid: 1001, uname: '测试主播'),
        _card(uid: 2002, uname: '其他主播'),
      ];

      expect(
        LiveShielding.removeBlocked(items, _rules([
          _rule(ShieldRuleType.userKeyword, '测试主播'),
        ])),
        1,
      );
      expect(_uidOf(items.single), 2002);
    });

    test('blocks by card title and by text area name', () {
      final byTitle = <Object>[_card(title: '测试直播间'), _card(title: '别的直播间')];
      expect(
        LiveShielding.removeBlocked(byTitle, _rules([
          _rule(ShieldRuleType.keyword, '测试直播间', matchMode: ShieldMatchMode.contains),
        ])),
        1,
      );
      expect(_uidOf(byTitle.single), 1001);

      final byArea = <Object>[
        _card(areaName: '虚拟主播'),
        _card(areaName: '网游'),
      ];
      expect(
        LiveShielding.removeBlocked(byArea, _rules([
          _rule(ShieldRuleType.category, '虚拟主播'),
        ])),
        1,
      );
      expect(_uidOf(byArea.single), 1001);
    });

    test('matches an exact room id without confusing it with a host uid', () {
      final hostWithRoomNumber = _card(uid: 9527, roomid: 1111);
      final roomWithNumber = _card(uid: 2222, roomid: 9527);

      final byRoom = <Object>[hostWithRoomNumber, roomWithNumber];
      expect(
        LiveShielding.removeBlocked(byRoom, _rules([_roomRule('9527')])),
        1,
      );
      expect(byRoom.single, same(hostWithRoomNumber));

      final byUid = <Object>[hostWithRoomNumber, roomWithNumber];
      expect(
        LiveShielding.removeBlocked(byUid, _rules([_uidRule('9527')])),
        1,
      );
      expect(byUid.single, same(roomWithNumber));
    });

    test('keeps live rules away from other scopes', () {
      final items = <Object>[_card()];

      for (final scope in [ShieldScope.recommendation, ShieldScope.both]) {
        expect(
          LiveShielding.removeBlocked(items, _rules([
            _roomRule('9527', scope: scope),
          ])),
          0,
          reason: 'room rule in scope $scope must not touch live candidates',
        );
      }
      expect(items, hasLength(1));

      const recommendationCandidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        uid: '1001',
        roomId: '9527',
      );
      expect(
        ShieldMatcher.match(
          recommendationCandidate,
          _rules([_roomRule('9527')]),
        ).visible,
        isTrue,
      );
    });

    test('ignores disabled rules, disabled entries and global off', () {
      final items = <Object>[_card()];

      expect(
        LiveShielding.removeBlocked(items, _rules([
          _roomRule('9527', enabled: false),
        ])),
        0,
      );
      expect(
        LiveShielding.removeBlocked(
          items,
          _rules([_roomRule('9527')], globalEnabled: false),
        ),
        0,
      );
      expect(items, hasLength(1));
    });

    test('keeps the survivor order of the source page', () {
      final items = <Object>[
        _card(uid: 1),
        _card(uid: 2),
        _card(uid: 3),
        _card(uid: 4),
        _card(uid: 5),
      ];

      final removed = LiveShielding.removeBlocked(items, _rules([
        _uidRule('2'),
        _uidRule('4'),
      ]));

      expect(removed, 2);
      expect(items.map(_uidOf), [1, 3, 5]);
    });
  });

  group('LiveShielding quick action', () {
    test('saves a host rule that immediately hides the card', () async {
      final store = ShieldSettingsStore(box: _MemoryBox());
      final items = <Object>[_card(uid: 1001), _card(uid: 2002)];

      final result = await LiveShielding.applyQuickAction(
        card: _card(uid: 1001),
        target: LiveShieldTarget.host,
        store: store,
      );

      expect(result.outcome, LiveShieldQuickActionOutcome.added);
      expect(result.message, '已屏蔽主播：测试主播');
      expect(result.refiltersCurrentPage, isTrue);

      final rule = (await store.load()).rules.single;
      expect(rule.type, ShieldRuleType.uid);
      expect(rule.scope, ShieldScope.live);
      expect(rule.matchMode, ShieldMatchMode.exact);
      expect(rule.pattern, '1001');
      expect(rule.action, ShieldAction.block);
      expect(rule.source, ShieldRuleSource.quickAction);

      expect(LiveShielding.removeBlocked(items, await store.load()), 1);
      expect(_uidOf(items.single), 2002);
    });

    test('saves a room rule that immediately hides the card', () async {
      final store = ShieldSettingsStore(box: _MemoryBox());
      final items = <Object>[_card(uid: 1001, roomid: 9527)];

      final result = await LiveShielding.applyQuickAction(
        card: _card(uid: 1001, roomid: 9527),
        target: LiveShieldTarget.room,
        store: store,
      );

      expect(result.outcome, LiveShieldQuickActionOutcome.added);
      expect(result.message, '已屏蔽直播间：测试直播间');

      final rule = (await store.load()).rules.single;
      expect(rule.type, ShieldRuleType.roomId);
      expect(rule.scope, ShieldScope.live);
      expect(rule.matchMode, ShieldMatchMode.exact);
      expect(rule.pattern, '9527');

      expect(LiveShielding.removeBlocked(items, await store.load()), 1);
      expect(items, isEmpty);
    });

    test('reports a duplicate rule and still re-filters the page', () async {
      final store = ShieldSettingsStore(box: _MemoryBox());
      final card = _card(uid: 1001, roomid: 9527);

      await LiveShielding.applyQuickAction(
        card: card,
        target: LiveShieldTarget.room,
        store: store,
      );
      final again = await LiveShielding.applyQuickAction(
        card: card,
        target: LiveShieldTarget.room,
        store: store,
      );

      expect(again.outcome, LiveShieldQuickActionOutcome.duplicate);
      expect(again.message, '规则已存在：测试直播间');
      expect(again.refiltersCurrentPage, isTrue);
      expect((await store.load()).rules, hasLength(1));
    });

    test('reports a persistence failure without asking for a re-filter', () async {
      final store = ShieldSettingsStore(box: _ThrowingBox());

      final result = await LiveShielding.applyQuickAction(
        card: _card(),
        target: LiveShieldTarget.room,
        store: store,
      );

      expect(result.outcome, LiveShieldQuickActionOutcome.failure);
      expect(result.message, LiveShielding.failureMessage);
      expect(result.refiltersCurrentPage, isFalse);
    });

    test('reports a missing identity instead of saving a wrong rule', () async {
      final store = ShieldSettingsStore(box: _MemoryBox());

      final result = await LiveShielding.applyQuickAction(
        card: _card(uid: 0, roomid: null),
        target: LiveShieldTarget.host,
        store: store,
      );

      expect(result.outcome, LiveShieldQuickActionOutcome.unavailable);
      expect(result.message, LiveShielding.unavailableMessage);
      expect(result.refiltersCurrentPage, isFalse);
      expect((await store.load()).rules, isEmpty);
    });
  });
}

CardLiveItem _card({
  int? uid = 1001,
  int? roomid = 9527,
  String? uname = '测试主播',
  String? title = '测试直播间',
  String? areaName = '虚拟主播',
}) => CardLiveItem(
  uid: uid,
  roomid: roomid,
  uname: uname,
  title: title,
  areaName: areaName,
);

int? _uidOf(Object item) => LiveShielding.cardOf(item)?.uid;

ShieldRule _rule(
  ShieldRuleType type,
  String pattern, {
  ShieldScope scope = ShieldScope.live,
  ShieldMatchMode matchMode = ShieldMatchMode.exact,
  bool enabled = true,
}) => ShieldRule(
  id: '${type.name}-$pattern',
  type: type,
  matchMode: matchMode,
  scope: scope,
  action: ShieldAction.block,
  pattern: pattern,
  enabled: enabled,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

ShieldRule _uidRule(String pattern, {bool enabled = true}) =>
    _rule(ShieldRuleType.uid, pattern, enabled: enabled);

ShieldRule _roomRule(
  String pattern, {
  ShieldScope scope = ShieldScope.live,
  bool enabled = true,
}) => _rule(ShieldRuleType.roomId, pattern, scope: scope, enabled: enabled);

ShieldRuleSet _rules(List<ShieldRule> rules, {bool globalEnabled = true}) =>
    ShieldRuleSet(rules: rules, globalEnabled: globalEnabled);

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

class _ThrowingBox implements ShieldSettingsBox {
  @override
  Object? get(String key, {Object? defaultValue}) => defaultValue;

  @override
  Future<void> put(String key, Object? value) =>
      Future<void>.error(StateError('persist failed'));

  @override
  Future<void> delete(String key) async {}
}
