import 'dart:io';

import 'package:PiliPlus/features/shielding/comment_shielding_config.dart';
import 'package:PiliPlus/features/shielding/shielding_store.dart';
import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/comment_shield_settings/view.dart';
import 'package:PiliPlus/pages/setting/view.dart';
import 'package:PiliPlus/router/app_pages.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync(
      'comment_shield_settings_test_',
    );
    Hive.init(dir.path);
    Accounts.account = await Hive.openBox('account');
  });

  group('CommentShieldSettingsPage', () {
    test('SettingType includes commentShieldSetting', () {
      expect(
        SettingType.values,
        contains(SettingType.commentShieldSetting),
      );
      expect(SettingType.commentShieldSetting.title, '评论区屏蔽设置');
    });

    test('comment shield route renders the settings page', () {
      final route = Routes.getPages.singleWhere(
        (page) => page.name == '/commentShieldSetting',
      );

      expect(route.page(), isA<CommentShieldSettingsPage>());
    });

    testWidgets('settings list contains first-level comment shield entry', (
      tester,
    ) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: SettingPage(),
        ),
      );
      await tester.pump();

      expect(find.text('评论区屏蔽设置'), findsOneWidget);
    });

    testWidgets('page title is correct', (tester) async {
      final store = CommentShieldingStore(box: _MemoryBox());

      await tester.pumpWidget(
        GetMaterialApp(
          home: CommentShieldSettingsPage(store: store),
        ),
      );
      await tester.pump();

      expect(find.text('评论区屏蔽设置'), findsOneWidget);
    });

    testWidgets('no master switch is rendered', (tester) async {
      final store = CommentShieldingStore(box: _MemoryBox());

      await tester.pumpWidget(
        GetMaterialApp(
          home: CommentShieldSettingsPage(store: store),
        ),
      );
      await tester.pump();

      expect(find.text('评论区屏蔽设置'), findsOneWidget);
      expect(find.text('启用评论区屏蔽'), findsNothing);
    });

    testWidgets('all nine direct controls render', (tester) async {
      final store = CommentShieldingStore(box: _MemoryBox());

      await tester.pumpWidget(
        GetMaterialApp(
          home: CommentShieldSettingsPage(store: store),
        ),
      );
      await tester.pump();

      // Each label should exist in the widget tree (may need scrolling)
      for (final label in [
        '用户等级阈值',
        '屏蔽性别',
        '屏蔽会员类型',
        '屏蔽IP属地',
        '最少字数',
        '最多字数',
        '最低点赞数',
        '屏蔽含图片评论',
        '屏蔽含表情评论',
      ]) {
        await tester.scrollUntilVisible(find.text(label), 100);
        await tester.pump();
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('changing blockWithPicture saves config', (tester) async {
      final box = _MemoryBox();
      final store = CommentShieldingStore(box: box);

      await tester.pumpWidget(
        GetMaterialApp(
          home: CommentShieldSettingsPage(store: store),
        ),
      );
      await tester.pump();

      // Find and tap the switch for blockWithPicture
      final pictureSwitch = find.text('屏蔽含图片评论');
      expect(pictureSwitch, findsOneWidget);

      // The Switch is part of a ListTile with that title - scroll to it and tap
      await tester.scrollUntilVisible(pictureSwitch, 100);
      await tester.tap(
        find
            .descendant(
              of: find.ancestor(
                of: pictureSwitch,
                matching: find.byType(ListTile),
              ),
              matching: find.byType(Switch),
            )
            .first,
      );
      await tester.pumpAndSettle();

      // Verify the config was saved
      final saved = store.snapshot();
      expect(saved.blockWithPicture, isTrue);
    });

    testWidgets('blank number input clears an existing threshold', (
      tester,
    ) async {
      final box = _MemoryBox();
      final store = CommentShieldingStore(box: box);
      await store.save(const CommentShieldingConfig(minCharCount: 8));

      await tester.pumpWidget(
        GetMaterialApp(
          home: CommentShieldSettingsPage(store: store),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('最少字数'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(store.snapshot().minCharCount, isNull);
    });

    testWidgets('invalid min greater than max input does not save', (
      tester,
    ) async {
      final box = _MemoryBox();
      final store = CommentShieldingStore(box: box);
      await store.save(
        const CommentShieldingConfig(minCharCount: 2, maxCharCount: 10),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: CommentShieldSettingsPage(store: store),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('最少字数'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '12');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final saved = store.snapshot();
      expect(saved.minCharCount, 2);
      expect(saved.maxCharCount, 10);
    });
  });
}

class _MemoryBox implements ShieldSettingsBox {
  _MemoryBox([Map<String, Object?>? values]) : values = values ?? {};

  final Map<String, Object?> values;

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
