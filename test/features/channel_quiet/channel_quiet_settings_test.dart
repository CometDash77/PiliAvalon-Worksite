import 'package:PiliPlus/pages/channel_quiet_settings/view.dart';
import 'package:PiliPlus/pages/video/channel_quiet/channel_quiet_rule.dart';
import 'package:PiliPlus/pages/video/channel_quiet/channel_quiet_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  group('ChannelQuietSettingsPage', () {
    late ChannelQuietStore store;
    late _MemoryBox box;

    setUp(() {
      box = _MemoryBox();
      store = ChannelQuietStore(box: box);
    });

    Widget buildPage({bool showAppBar = false}) => GetMaterialApp(
          home: ChannelQuietSettingsPage(
            showAppBar: showAppBar,
            store: store,
          ),
        );

    testWidgets('shows loading indicator before data loads',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPage());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('暂无频道规则'), findsNothing);
    });

    testWidgets('shows empty state when no rules exist',
        (WidgetTester tester) async {
      await store.load(); // seed cache as empty
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('暂无频道规则'), findsOneWidget);
      expect(find.text('可在视频详情页的更多菜单添加当前频道'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('lists stored rules with title, subtitle, and switch',
        (WidgetTester tester) async {
      await store.add(
        key: ChannelQuietRule.ugcKey(42),
        channelUid: '42',
        channelName: 'TestChannel',
        hideComments: true,
        hideDanmaku: false,
      );
      await store.add(
        key: ChannelQuietRule.pgcKey(100),
        channelUid: '100',
        channelName: 'BangumiShow',
        hideComments: false,
        hideDanmaku: true,
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Both rules visible
      expect(find.text('TestChannel'), findsOneWidget);
      expect(find.text('BangumiShow'), findsOneWidget);

      // Subtitle contains type, uid, and actions label
      expect(find.textContaining('UP 42'), findsOneWidget);
      expect(find.textContaining('PGC 100'), findsOneWidget);
      expect(find.textContaining('隐藏评论'), findsOneWidget);
      expect(find.textContaining('隐藏弹幕'), findsOneWidget);

      // Each rule has a Switch
      expect(find.byType(Switch), findsNWidgets(2));

      // Summary text
      expect(find.textContaining('2 条规则'), findsOneWidget);
    });

    testWidgets('toggle sets both hide flags via switch',
        (WidgetTester tester) async {
      await store.add(
        key: ChannelQuietRule.ugcKey(1),
        channelUid: '1',
        channelName: 'ToggleMe',
        hideComments: true,
        hideDanmaku: false,
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Switch should be ON because hideComments is true
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      Switch sw = tester.widget<Switch>(switchFinder);
      expect(sw.value, isTrue);

      // Tap the switch to turn OFF (sets both to false)
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // After reload, switch should be OFF
      final updatedSwitch = tester.widget<Switch>(find.byType(Switch));
      expect(updatedSwitch.value, isFalse);

      // Subtitle should show "未隐藏"
      expect(find.textContaining('未隐藏'), findsOneWidget);

      // Verify persistence: both flags false
      final rules = await store.load();
      expect(rules.single.hideComments, isFalse);
      expect(rules.single.hideDanmaku, isFalse);
    });

    testWidgets('toggle ON sets both hide flags to true',
        (WidgetTester tester) async {
      await store.add(
        key: ChannelQuietRule.ugcKey(1),
        channelUid: '1',
        channelName: 'OffByDefault',
        hideComments: false,
        hideDanmaku: false,
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Switch should be OFF
      Switch sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isFalse);

      // Tap to turn ON
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Switch should now be ON
      final updatedSwitch = tester.widget<Switch>(find.byType(Switch));
      expect(updatedSwitch.value, isTrue);

      // Subtitle should show both actions (combined as 隐藏评论、弹幕)
      expect(find.textContaining('隐藏评论、弹幕'), findsOneWidget);
    });

    testWidgets('edit dialog opens on tap and saves changes',
        (WidgetTester tester) async {
      await store.add(
        key: ChannelQuietRule.ugcKey(1),
        channelUid: '1',
        channelName: 'Original',
        hideComments: true,
        hideDanmaku: false,
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Tap the rule to open editor
      await tester.tap(find.text('Original'));
      await tester.pumpAndSettle();

      // Editor dialog is visible
      expect(find.text('编辑频道屏蔽'), findsOneWidget);
      expect(find.text('隐藏评论'), findsOneWidget);
      expect(find.text('隐藏弹幕'), findsOneWidget);

      // Clear and retype channel name
      final nameField = find.widgetWithText(TextFormField, 'Original');
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Renamed');
      await tester.pumpAndSettle();

      // Tap save
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Rule should be renamed
      expect(find.text('Renamed'), findsOneWidget);
      expect(find.text('Original'), findsNothing);
    });

    testWidgets('delete via long-press shows confirmation and removes rule',
        (WidgetTester tester) async {
      await store.add(
        key: ChannelQuietRule.ugcKey(1),
        channelUid: '1',
        channelName: 'ToDelete',
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('ToDelete'), findsOneWidget);

      // Long-press the rule
      await tester.longPress(find.text('ToDelete'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('删除频道屏蔽'), findsOneWidget);
      expect(find.text('ToDelete'), findsWidgets); // in dialog + in list

      // Confirm deletion
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // Rule removed
      expect(find.text('ToDelete'), findsNothing);
      expect(find.text('暂无频道规则'), findsOneWidget);
    });

    testWidgets('delete dialog cancel leaves rule intact',
        (WidgetTester tester) async {
      await store.add(
        key: ChannelQuietRule.ugcKey(1),
        channelUid: '1',
        channelName: 'KeepMe',
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Long-press, then cancel
      await tester.longPress(find.text('KeepMe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Rule still present
      expect(find.text('KeepMe'), findsOneWidget);
      expect(find.text('暂无频道规则'), findsNothing);
    });

    testWidgets('summary shows correct counts', (WidgetTester tester) async {
      await store.add(
        key: ChannelQuietRule.ugcKey(1),
        channelUid: '1',
        channelName: 'A',
        hideComments: true,
        hideDanmaku: false,
      );
      await store.add(
        key: ChannelQuietRule.ugcKey(2),
        channelUid: '2',
        channelName: 'B',
        hideComments: false,
        hideDanmaku: true,
      );
      await store.add(
        key: ChannelQuietRule.ugcKey(3),
        channelUid: '3',
        channelName: 'C',
        hideComments: true,
        hideDanmaku: true,
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // 3 rules total, 2 hide comments, 2 hide danmaku
      expect(find.textContaining('3 条规则'), findsOneWidget);
      expect(find.textContaining('评论 2'), findsOneWidget);
      expect(find.textContaining('弹幕 2'), findsOneWidget);
    });

    testWidgets('sort order: newest updated first', (WidgetTester tester) async {
      // Add rule A first (older)
      await store.add(
        key: ChannelQuietRule.ugcKey(1),
        channelUid: '1',
        channelName: 'Alpha',
      );

      // Small delay so updatedAt differs
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Add rule B second (newer)
      await store.add(
        key: ChannelQuietRule.ugcKey(2),
        channelUid: '2',
        channelName: 'Beta',
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      // Beta (newer) should appear before Alpha (older) in the list
      final alphaIndex = _textTop(tester, 'Alpha');
      final betaIndex = _textTop(tester, 'Beta');
      expect(betaIndex, lessThan(alphaIndex));
    });
  });
}

/// Returns the vertical offset of the center of the first widget matching
/// [text].
double _textTop(WidgetTester tester, String text) {
  final finder = find.text(text);
  expect(finder, findsOneWidget);
  return tester.getCenter(finder).dy;
}

class _MemoryBox implements ChannelQuietBox {
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
