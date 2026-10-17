import 'dart:io';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _RcmdController extends RcmdController {
  @override
  Future<LoadingState> customGetData() async => Success<List<dynamic>?>([1]);
}

void main() {
  setUpAll(() async {
    try {
      final dir = Directory.systemTemp.createTempSync('rcmd_test_');
      Hive.init(dir.path);
      GStorage.setting = await Hive.openBox('setting');
    } catch (_) {
      // Already initialized by another test file in the same isolate.
    }
  });

  test('reload clears the saved marker before replacing a shorter feed', () async {
    final controller = _RcmdController()
      ..lastRefreshAt = 2
      ..loadingState.value = Success<List<dynamic>?>([1, 2, 3]);

    await controller.onReload();

    expect(controller.loadingState.value, isA<Success<List<dynamic>?>>());
    expect(controller.loadingState.value.data, [1]);
    expect(controller.lastRefreshAt, isNull);
  });
}
