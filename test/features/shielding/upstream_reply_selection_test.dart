import 'dart:io';

import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_item_grpc.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('reply_selection_test_');
    Hive.init(directory.path);
    GStorage.setting = await Hive.openBox('setting');
    GStorage.localCache = await Hive.openBox('localCache');
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets(
    'selected comment text saves a structured rule, not legacy regex',
    (
      tester,
    ) async {
      const message = 'literal [text]';
      final store = ShieldSettingsStore(box: _MemoryBox());
      await store.load();
      await tester.runAsync(
        () => GStorage.setting.put(SettingBoxKey.banWordForReply, 'existing'),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          builder: FlutterSmartDialog.init(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showReplyCopyDialog(
                  context,
                  message,
                  const {},
                  shieldSettingsStore: store,
                ),
                child: const Text('copy comment'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('copy comment'));
      await tester.pumpAndSettle();

      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll(SelectionChangedCause.toolbar);
      await tester.pump();
      final area = tester.widget<SelectionArea>(find.byType(SelectionArea));
      final toolbar = area.contextMenuBuilder!(
        region.context,
        region,
      ) as AdaptiveTextSelectionToolbar;
      toolbar.buttonItems!
          .singleWhere((item) => item.label == '加入过滤')
          .onPressed!();
      await tester.pumpAndSettle();
      expect(find.text('屏蔽评论关键词「$message」'), findsOneWidget);
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      final rules = (await store.load()).rules;
      expect(rules, hasLength(1));
      expect(rules.single.type, ShieldRuleType.keyword);
      expect(rules.single.scope, ShieldScope.comment);
      expect(rules.single.matchMode, ShieldMatchMode.contains);
      expect(rules.single.pattern, message);
      expect(GStorage.setting.get(SettingBoxKey.banWordForReply), 'existing');
      final dismissal = SmartDialog.dismiss(status: SmartStatus.allToast);
      await tester.pumpAndSettle();
      await dismissal;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

class _MemoryBox implements ShieldSettingsBox {
  final _values = <String, Object?>{};

  @override
  Object? get(String key, {Object? defaultValue}) =>
      _values.containsKey(key) ? _values[key] : defaultValue;

  @override
  Future<void> put(String key, Object? value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
