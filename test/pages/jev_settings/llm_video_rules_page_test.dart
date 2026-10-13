import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/features/llm/llm_rules.dart';
import 'package:PiliPlus/pages/jev_settings/llm_video_rules_page.dart';
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

Future<void> _open(WidgetTester tester, LlmVideoRuleStore store) async {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: LlmVideoRulesPage(store: store)));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'create, edit, cancel, toggle, delete and reload a video rule',
    (tester) async {
      final store = LlmVideoRuleStore(box: _MemoryBox());
      await _open(tester, store);
      expect(find.text('还没有视频屏蔽规则。用一句话描述想屏蔽的视频。'), findsOneWidget);
      await _tap(tester, '添加规则');
      await tester.enterText(
        find.byKey(const ValueKey('rule-text')),
        '屏蔽广告推销类视频',
      );
      await _tap(tester, '保存规则');
      var saved = await store.load();
      expect(saved.rules.single.text, '屏蔽广告推销类视频');
      expect(saved.rules.single.enabled, isTrue);
      expect(saved.rules.single.id, startsWith('rule-'));
      await _tap(tester, '编辑');
      await tester.enterText(
        find.byKey(const ValueKey('rule-text')),
        '取消的草稿',
      );
      await _tap(tester, '取消');
      expect((await store.load()).rules.single.text, '屏蔽广告推销类视频');
      await _tap(tester, '编辑');
      await tester.enterText(
        find.byKey(const ValueKey('rule-text')),
        '屏蔽标题党视频',
      );
      await _tap(tester, '保存规则');
      saved = await store.load();
      expect(saved.rules.single.text, '屏蔽标题党视频');
      // 编辑按 id 原位替换，不产生重复条目。
      expect(saved.rules.length, 1);
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      saved = await store.load();
      expect(saved.rules.single.enabled, false);
      await tester.pumpWidget(const SizedBox());
      await _open(tester, store);
      expect(find.text('屏蔽标题党视频'), findsOneWidget);
      await _tap(tester, '删除');
      await _tap(tester, '删除');
      expect((await store.load()).rules, isEmpty);
    },
  );

  testWidgets(
    'invalid drafts and failed writes keep the editor and allow retry',
    (tester) async {
      final box = _MemoryBox();
      final store = LlmVideoRuleStore(box: box);
      await _open(tester, store);
      await _tap(tester, '添加规则');
      await _tap(tester, '保存规则');
      expect(find.byKey(const ValueKey('rule-error')), findsOneWidget);
      expect((await store.load()).rules, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('rule-text')),
        '屏蔽剧透类视频',
      );
      box.failWrites = true;
      await _tap(tester, '保存规则');
      expect(find.text('保存失败，草稿已保留，请重试'), findsOneWidget);
      expect(find.byKey(const ValueKey('rule-text')), findsOneWidget);
      box.failWrites = false;
      await _tap(tester, '保存规则');
      expect((await store.load()).rules.single.text, '屏蔽剧透类视频');
    },
  );

  testWidgets('adding is disabled at the per-surface cap of 20', (
    tester,
  ) async {
    final store = LlmVideoRuleStore(box: _MemoryBox());
    await store.save(
      LlmVideoRuleConfig(
        rules: [
          for (var i = 0; i < LlmVideoRule.maxRulesPerSurface; i++)
            LlmVideoRule(id: 'seed-$i', text: '预置规则 $i'),
        ],
      ),
    );
    await _open(tester, store);
    final add = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '添加规则'),
    );
    expect(add.onPressed, isNull);
    // 已满时仍可编辑与启停存量规则（_tap 命中列表末尾的 seed-19）。
    await _tap(tester, '编辑');
    await tester.enterText(
      find.byKey(const ValueKey('rule-text')),
      '改写后的预置规则',
    );
    await _tap(tester, '保存规则');
    final saved = await store.load();
    expect(saved.rules.length, LlmVideoRule.maxRulesPerSurface);
    expect(
      saved.rules.singleWhere((r) => r.id == 'seed-19').text,
      '改写后的预置规则',
    );
  });
}
