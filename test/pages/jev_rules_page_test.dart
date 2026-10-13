import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/pages/jev_settings/jev_rules_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryBox implements JevSettingsBox {
  final Map<String, Object?> values = {};
  bool failWrites = false;
  @override
  Object? get(String key, {Object? defaultValue}) =>
      values[key] ?? defaultValue;
  @override
  Future<void> put(String key, Object? value) async {
    if (failWrites) throw StateError('disk full');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

Future<void> _open(WidgetTester tester, JevRuleStore store) async {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: JevRulesPage(store: store)));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('create, edit, cancel, toggle, delete and reload a video rule', (
    tester,
  ) async {
    final store = JevRuleStore(box: _MemoryBox());
    await _open(tester, store);
    await _tap(tester, '添加规则');
    await tester.enterText(
      find.byKey(const ValueKey('rule-question')),
      '是否有剧透？',
    );
    await _tap(tester, '保存规则');
    var saved = await store.load();
    expect(saved.rules.single.threshold, .95);
    expect(saved.rules.single.target, JevRuleTarget.video);
    await _tap(tester, '编辑');
    await tester.enterText(
      find.byKey(const ValueKey('rule-question')),
      '取消的草稿',
    );
    await _tap(tester, '取消');
    expect((await store.load()).rules.single.question, '是否有剧透？');
    await _tap(tester, '编辑');
    await tester.enterText(
      find.byKey(const ValueKey('rule-question')),
      '是否包含广告？',
    );
    await _tap(tester, '保存规则');
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    saved = await store.load();
    expect(saved.rules.single.enabled, false);
    expect(saved.rules.single.question, '是否包含广告？');
    await tester.pumpWidget(const SizedBox());
    await _open(tester, store);
    expect(find.text('是否包含广告？'), findsOneWidget);
    await _tap(tester, '删除');
    await _tap(tester, '删除');
    expect((await store.load()).rules, isEmpty);
  });

  testWidgets('comment choice has multiple hide answers and no builtin', (
    tester,
  ) async {
    final store = JevRuleStore(box: _MemoryBox());
    await _open(tester, store);
    await _tap(tester, '评论');
    expect(find.text('根据不感兴趣主题筛选（内置）'), findsNothing);
    await _tap(tester, '添加规则');
    await tester.enterText(
      find.byKey(const ValueKey('rule-question')),
      '这条评论属于什么？',
    );
    await _tap(tester, '选择题');
    for (final label in ['教程', '广告', '娱乐']) {
      await _tap(tester, '添加选项');
      await tester.enterText(
        find.widgetWithText(TextField, '选项名称').last,
        label,
      );
    }
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.tap(find.byType(Checkbox).at(2));
    await tester.pump();
    await _tap(tester, '保存规则');
    final rule = (await store.load()).rules.single;
    expect(rule.target, JevRuleTarget.comment);
    expect(rule.type, JevRuleType.choice);
    expect(rule.hiddenOptions.length, 2);
    expect(
      rule.options
          .where((o) => rule.hiddenOptions.contains(o.id))
          .map((o) => o.label),
      ['广告', '娱乐'],
    );
    await _tap(tester, '直播间');
    expect(find.text('这条评论属于什么？'), findsNothing);
    expect(find.text('根据不感兴趣主题筛选（内置）'), findsOneWidget);
  });

  testWidgets(
    'invalid drafts and failed writes keep the editor and allow retry',
    (tester) async {
      final box = _MemoryBox();
      final store = JevRuleStore(box: box);
      await _open(tester, store);
      await _tap(tester, '添加规则');
      await _tap(tester, '保存规则');
      expect(find.byKey(const ValueKey('rule-error')), findsOneWidget);
      expect((await store.load()).rules, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('rule-question')),
        '是否有广告？',
      );
      box.failWrites = true;
      await _tap(tester, '保存规则');
      expect(find.text('保存失败，草稿已保留，请重试'), findsOneWidget);
      expect(find.byKey(const ValueKey('rule-question')), findsOneWidget);
      box.failWrites = false;
      await _tap(tester, '保存规则');
      expect((await store.load()).rules.single.question, '是否有广告？');
    },
  );
}
