import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shielded recommendation pagination', () {
    test('advances page when a refresh page is fully filtered out', () async {
      final controller = _PagedController([const Success(<int>[])]);

      await controller.queryData();

      expect(controller.page, 2);
      expect(controller.isEnd, isTrue);
      expect(controller.loadingState.value.data, isEmpty);
    });

    test('advances page when a load-more page is fully filtered out', () async {
      final controller = _PagedController([
        const Success([1]),
        const Success(<int>[]),
      ]);

      await controller.queryData();
      await controller.queryData(false);

      expect(controller.page, 3);
      expect(controller.isEnd, isTrue);
      expect(controller.loadingState.value.data, [1]);
    });

    test(
      'non-ending recommendation streams do not repeat all-blocked page',
      () async {
        final controller = _EndlessPagedController([
          Success([1]),
          const Success(<int>[]),
          Success([3]),
        ]);

        await controller.queryData();
        await controller.queryData(false);
        await controller.queryData(false);

        expect(controller.requestedPages, [1, 2, 3]);
        expect(controller.page, 4);
        expect(controller.loadingState.value.data, [1, 3]);
      },
    );
  });
}

class _PagedController extends CommonListController<List<int>, int> {
  _PagedController(this._responses);

  final List<LoadingState<List<int>>> _responses;
  final requestedPages = <int>[];

  @override
  Future<LoadingState<List<int>>> customGetData() async {
    requestedPages.add(page);
    return _responses.removeAt(0);
  }
}

class _EndlessPagedController extends _PagedController {
  _EndlessPagedController(super.responses);

  @override
  bool get isEnd => false;

  @override
  set isEnd(bool value) {}
}
