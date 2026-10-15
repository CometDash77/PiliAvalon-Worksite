import 'package:PiliPlus/features/shielding/live_shielding.dart';
import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data_list_item.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_list.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/data.dart';
import 'package:PiliPlus/models_new/live/live_second_list/data.dart';
import 'package:PiliPlus/pages/live/controller.dart';
import 'package:flutter_test/flutter_test.dart';

ShieldRuleSet _liveRuleSet = ShieldRuleSet();

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  setUp(() {
    _liveRuleSet = ShieldRuleSet();
  });

  test('filters each loaded page and keeps the survivor order', () async {
    _liveRuleSet = _rules([_uidRule('1002')]);
    final controller = _TestLiveController(
      pages: [
        [_card(1001), _card(1002), _card(1003)],
        [_card(1004), _card(1002)],
      ],
    );

    await controller.queryData();

    expect(_uids(controller), [1001, 1003]);
    expect(controller.sourcePageCount, 3);
    expect(controller.hiddenCardCount, 1);
    expect(controller.autoPagingPaused, isFalse);

    await controller.onLoadMore();

    expect(_uids(controller), [1001, 1003, 1004]);
    expect(controller.hiddenCardCount, 2);
    expect(controller.requestedPages, [1, 2]);
  });

  test('stops automatic paging when the loaded page is fully hidden', () async {
    _liveRuleSet = _rules([_roomRule('9527')]);
    final controller = _TestLiveController(
      pages: [
        [_card(1001)],
        [_card(9527)],
      ],
    );

    await controller.queryData();
    await controller.onLoadMore();

    expect(_uids(controller), [1001]);
    expect(controller.hiddenCardCount, 1);
    expect(controller.autoPagingPaused, isTrue);

    await controller.onLoadMore();

    expect(controller.requestedPages, [1, 2]);
    expect(controller.isEnd, isFalse);
  });

  test('resuming without a scroll viewport only clears the pause', () async {
    _liveRuleSet = _rules([_roomRule('9527')]);
    final controller = _TestLiveController(
      pages: [
        [_card(1001)],
        [_card(9527)],
        [_card(1005)],
      ],
    );

    await controller.queryData();
    await controller.onLoadMore();
    expect(controller.autoPagingPaused, isTrue);

    await controller.resumeAutoPaging();

    expect(controller.autoPagingPaused, isFalse);
    expect(controller.requestedPages, [1, 2]);
  });

  test('separates a fully hidden page from a server empty page', () async {
    _liveRuleSet = _rules([_uidRule('1002')]);
    final hidden = _TestLiveController(
      pages: [
        [_card(1002)],
      ],
    );

    await hidden.queryData();

    expect(_uids(hidden), isEmpty);
    expect(hidden.isFilteredEmpty, isTrue);
    expect(hidden.sourcePageCount, 1);
    expect(hidden.hiddenCardCount, 1);
    expect(hidden.isEnd, isFalse);

    _liveRuleSet = ShieldRuleSet();
    final empty = _TestLiveController(
      pages: [const []],
    );

    await empty.queryData();

    expect(_uids(empty), isEmpty);
    expect(empty.isFilteredEmpty, isFalse);
    expect(empty.sourcePageCount, 0);
    expect(empty.isEnd, isTrue);
  });

  test('decides source exhaustion from the raw page progress', () async {
    _liveRuleSet = _rules([_uidRule('1002')]);
    final controller = _TestLiveController(
      totalCount: 3,
      pages: [
        [_card(1001), _card(1002)],
        [_card(1003)],
      ],
    );

    await controller.queryData();

    expect(controller.count, 3);
    expect(controller.isEnd, isFalse);

    await controller.onLoadMore();

    expect(_uids(controller), [1001, 1003]);
    expect(controller.isEnd, isTrue);
  });

  test('refresh resets the counters and re-applies the rules', () async {
    _liveRuleSet = _rules([_uidRule('1002')]);
    final controller = _TestLiveController(
      pages: [
        [_card(1001), _card(1002)],
        [_card(1001), _card(1003)],
      ],
    );

    await controller.queryData();
    await controller.onLoadMore();
    expect(controller.hiddenCardCount, 1);

    await controller.onRefresh();

    expect(controller.requestedPages, [1, 2, 1]);
    expect(_uids(controller), [1001]);
    expect(controller.hiddenCardCount, 1);
    expect(controller.sourcePageCount, 2);
    expect(controller.autoPagingPaused, isFalse);
    expect(controller.isEnd, isFalse);
  });

  test('switching area restarts the source page sequence', () async {
    _liveRuleSet = _rules([_uidRule('1002')]);
    final controller = _TestLiveController(
      pages: [
        [_card(1001)],
        [_card(1002)],
        [_card(1003)],
      ],
    );

    await controller.queryData();
    await controller.onLoadMore();
    expect(_uids(controller), [1001]);
    expect(controller.hiddenCardCount, 1);

    controller.onSelectArea(1, _card(4001));
    await _settle();

    expect(controller.requestedPages, [1, 2, 1]);
    expect(_uids(controller), [1001]);
    expect(controller.hiddenCardCount, 0);
    expect(controller.sourcePageCount, 1);
    expect(controller.isEnd, isFalse);
  });

  test('switching tag restarts the source page sequence', () async {
    _liveRuleSet = _rules([_uidRule('1002')]);
    final controller = _TestLiveController(
      pages: [
        [_card(1001), _card(1002)],
        [_card(1003)],
      ],
    );

    await controller.queryData();
    expect(_uids(controller), [1001]);
    expect(controller.hiddenCardCount, 1);

    controller.onSelectTag(1, 'rank');
    await _settle();

    expect(controller.requestedPages, [1, 1]);
    expect(_uids(controller), [1001]);
    expect(controller.hiddenCardCount, 1);
    expect(controller.sourcePageCount, 2);
    expect(controller.isEnd, isFalse);
  });

  test('a quick action removes the card from the loaded page', () async {
    final store = ShieldSettingsStore(box: _MemoryBox());
    final controller = _TestLiveController(
      pages: [
        [_card(1001), _card(1002)],
      ],
    );

    await controller.queryData();
    expect(_uids(controller), [1001, 1002]);

    await LiveShielding.applyQuickAction(
      card: _card(1002),
      target: LiveShieldTarget.host,
      store: store,
    );
    // The page filters through its provider, so the saved rule is picked up
    // on the very next pass without another request.
    _liveRuleSet = await store.load();

    expect(controller.refilterLoadedItems(), 1);
    expect(_uids(controller), [1001]);
    expect(controller.hiddenCardCount, 1);
    expect(controller.requestedPages, [1]);

    await LiveShielding.applyQuickAction(
      card: _card(1004),
      target: LiveShieldTarget.room,
      store: store,
    );
    _liveRuleSet = await store.load();

    expect(controller.refilterLoadedItems(), 0);
    expect(controller.requestedPages, [1]);
  });
}

class _TestLiveController extends LiveController {
  _TestLiveController({required this.pages, this.totalCount})
    : super(ruleSetProvider: () => _liveRuleSet);

  final List<List<CardLiveItem>> pages;
  final int? totalCount;
  final List<int> requestedPages = [];

  @override
  Future<LoadingState> customGetData() async {
    requestedPages.add(page);
    final index = page - 1;
    final cards = index >= 0 && index < pages.length
        ? pages[index]
        : const <CardLiveItem>[];
    if (totalCount != null) {
      return Success<LiveSecondData>(
        LiveSecondData(count: totalCount, cardList: [...cards]),
      );
    }
    return Success<LiveIndexData>(
      LiveIndexData(
        cardList: [
          for (final card in cards)
            LiveCardList(
              cardType: 'small_card_v1',
              cardData: CardData(smallCardV1: card),
            ),
        ],
        hasMore: 1,
      ),
    );
  }
}

CardLiveItem _card([int uid = 1001, int? roomid]) => CardLiveItem(
  uid: uid,
  roomid: roomid ?? uid,
  uname: '主播$uid',
  title: '直播间$uid',
  areaName: '虚拟主播',
);

List<int?> _uids(LiveController controller) {
  final state = controller.loadingState.value;
  if (state is! Success<List?>) {
    fail('expected a loaded success state, got $state');
  }
  return [
    for (final item in state.response!) LiveShielding.cardOf(item)?.uid,
  ];
}

ShieldRule _uidRule(String pattern) => ShieldRule(
  id: 'uid-$pattern',
  type: ShieldRuleType.uid,
  matchMode: ShieldMatchMode.exact,
  scope: ShieldScope.live,
  action: ShieldAction.block,
  pattern: pattern,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

ShieldRule _roomRule(String pattern) => ShieldRule(
  id: 'roomId-$pattern',
  type: ShieldRuleType.roomId,
  matchMode: ShieldMatchMode.exact,
  scope: ShieldScope.live,
  action: ShieldAction.block,
  pattern: pattern,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

ShieldRuleSet _rules(List<ShieldRule> rules) => ShieldRuleSet(rules: rules);

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
