import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data_list_item.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_list.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/data.dart';
import 'package:PiliPlus/models_new/live/live_second_list/data.dart';
import 'package:PiliPlus/models_new/live/live_second_list/tag.dart';
import 'package:PiliPlus/pages/live/controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters the current page immediately and preserves survivor order', () async {
    final store = ShieldSettingsStore(box: _MemoryBox());
    final controller = _TestLiveController(store, [
      Success(
        LiveIndexData(
          hasMore: 1,
          cardList: [
            _feedItem(uid: 1),
            _feedItem(uid: 2),
            _feedItem(uid: 3),
          ],
        ),
      ),
    ]);
    await controller.queryData();
    await store.addQuickActionRule(
      type: ShieldRuleType.uid,
      scope: ShieldScope.live,
      pattern: '2',
    );

    await controller.applySavedLiveRules();

    expect(_uids(controller), ['1', '3']);
    expect(controller.requestedPages, [1]);
  });

  test('does not backfill filtered pages; continuation stays user-driven', () async {
    final store = ShieldSettingsStore(box: _MemoryBox());
    await store.save(
      ShieldRuleSet(
        rules: [_rule(ShieldRuleType.uid, '42')],
      ),
    );
    final controller = _TestLiveController(store, [
      Success(
        LiveIndexData(
          hasMore: 1,
          cardList: [
            _feedItem(uid: 42),
            _feedItem(uid: 99),
            _feedItem(uid: 42, roomId: 8),
          ],
        ),
      ),
      Success(
        LiveIndexData(hasMore: 1, cardList: [_feedItem(uid: 42, roomId: 9)]),
      ),
      Success(
        LiveIndexData(hasMore: 0, cardList: [_feedItem(uid: 101, roomId: 10)]),
      ),
    ]);

    await controller.queryData();
    expect(_uids(controller), ['99']);
    expect(controller.filteredPageNeedsLoadMore, isTrue);
    expect(controller.requestedPages, [1]);

    await controller.onLoadMore();
    expect(controller.requestedPages, [1]);

    await controller.loadMoreAfterFilteredPage();
    expect(controller.requestedPages, [1, 2]);
    expect(_uids(controller), ['99']);
    expect(controller.page, 3);
    expect(controller.isEnd, isFalse);

    await controller.onLoadMore();
    expect(controller.requestedPages, [1, 2]);

    await controller.loadMoreAfterFilteredPage();
    expect(controller.requestedPages, [1, 2, 3]);
    expect(_uids(controller), ['99', '101']);
    expect(controller.isEnd, isTrue);
  });

  test('server-empty and API-error states remain distinct from filtered-empty', () async {
    final emptyController = _TestLiveController(
      ShieldSettingsStore(box: _MemoryBox()),
      [Success(LiveIndexData(hasMore: 0, cardList: const []))],
    );
    await emptyController.queryData();

    expect(emptyController.filteredPageEmpty, isFalse);
    expect(emptyController.isEnd, isTrue);
    expect(_uids(emptyController), isEmpty);

    final errorController = _TestLiveController(
      ShieldSettingsStore(box: _MemoryBox()),
      [const Error('network error')],
    );
    await errorController.queryData();

    expect(errorController.loadingState.value, isA<Error>());
    expect(errorController.filteredPageEmpty, isFalse);
  });

  test('area exhaustion follows raw source count; load-more errors keep survivors', () async {
    final store = ShieldSettingsStore(box: _MemoryBox());
    await store.save(ShieldRuleSet(rules: [_rule(ShieldRuleType.uid, '42')]));
    final controller = _TestLiveController(store, [
      Success(
        LiveSecondData(
          count: 4,
          cardList: [CardLiveItem(uid: 42), CardLiveItem(uid: 43)],
        ),
      ),
      Success(
        LiveSecondData(
          count: 4,
          cardList: [CardLiveItem(uid: 44), CardLiveItem(uid: 45)],
        ),
      ),
    ])..areaIndex.value = 1;

    await controller.queryData();
    expect(_uids(controller), ['43']);
    expect(controller.isEnd, isFalse);

    await controller.loadMoreAfterFilteredPage();
    expect(_uids(controller), ['43', '44', '45']);
    expect(controller.isEnd, isTrue);

    final errorController = _TestLiveController(store, [
      Success(
        LiveSecondData(count: 4, cardList: [CardLiveItem(uid: 43)]),
      ),
      const Error('network error'),
    ])..areaIndex.value = 1;
    await errorController.queryData();
    final visibleBeforeError = _uids(errorController);
    await errorController.onLoadMore();
    expect(_uids(errorController), visibleBeforeError);
    expect(errorController.loadingState.value, isA<Success<List?>>());
  });

  test('area, tag, and refresh requests restart source pagination at page one', () async {
    final controller = _TestLiveController(
      ShieldSettingsStore(box: _MemoryBox()),
      [
        Success(
          LiveSecondData(
            count: 5,
            cardList: [CardLiveItem(uid: 1)],
            newTags: [LiveSecondTag(name: '标签', sortType: 'popular')],
          ),
        ),
        Success(
          LiveSecondData(count: 3, cardList: [CardLiveItem(uid: 2)]),
        ),
        Success(
          LiveSecondData(count: 4, cardList: [CardLiveItem(uid: 3)]),
        ),
      ],
    );

    await controller.onSelectArea(
      1,
      CardLiveItem(areaV2Id: 12, areaV2ParentId: 3),
    );
    expect(controller.requestedPages, [1]);
    expect(controller.page, 2);

    await controller.onSelectTag(0, 'popular');
    expect(controller.requestedPages, [1, 1]);
    expect(controller.page, 2);
    expect(_uids(controller), ['2']);

    await controller.onRefresh();
    expect(controller.requestedPages, [1, 1, 1]);
    expect(controller.page, 2);
    expect(_uids(controller), ['3']);
  });
}

ShieldRule _rule(ShieldRuleType type, String pattern) => ShieldRule(
  id: '$type-$pattern',
  type: type,
  matchMode: ShieldMatchMode.exact,
  scope: ShieldScope.live,
  action: ShieldAction.block,
  pattern: pattern,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
);

LiveCardList _feedItem({required int uid, int? roomId}) => LiveCardList(
  cardType: 'small_card_v1',
  cardData: CardData(
    smallCardV1: CardLiveItem(
      uid: uid,
      roomid: roomId ?? uid + 100,
      title: '直播 $uid',
      uname: '主播 $uid',
      areaName: '游戏',
    ),
  ),
);

List<String> _uids(LiveController controller) =>
    (controller.loadingState.value.dataOrNull as List? ?? const [])
        .map((item) => item is LiveCardList
            ? item.cardData?.smallCardV1?.uid.toString()
            : (item as CardLiveItem).uid.toString())
        .whereType<String>()
        .toList();

class _TestLiveController extends LiveController {
  _TestLiveController(ShieldSettingsStore store, this.responses)
    : super(shieldStore: store);

  final List<LoadingState> responses;
  final requestedPages = <int>[];

  @override
  Future<void> queryTop() async {}

  @override
  Future<LoadingState> customGetData() async {
    requestedPages.add(page);
    return responses.removeAt(0);
  }
}

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
