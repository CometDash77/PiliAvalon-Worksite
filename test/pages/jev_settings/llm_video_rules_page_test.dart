import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
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

Future<void> _open(WidgetTester tester, JevRuleStore store) async {
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
  testWidgets('create, edit, cancel, toggle, delete and reload a video rule', (
    tester,
  ) async {
    final store = JevRuleStore(box: _MemoryBox());
    await _open(tester, store);
    expect(find.text('还没有视频屏蔽规则。用一句话描述想屏蔽的视频。'), findsOneWidget);
    await _tap(tester, '添加规则');
    await tester.enterText(
      find.byKey(const ValueKey('rule-text')),
      '屏蔽广告推销类视频',
    );
    await _tap(tester, '保存规则');
    var saved = await store.load();
    expect(saved.videoTextRules.single.text, '屏蔽广告推销类视频');
    expect(saved.videoTextRules.single.enabled, isTrue);
    expect(saved.videoTextRules.single.id, startsWith('rule-'));
    await _tap(tester, '编辑');
    await tester.enterText(find.byKey(const ValueKey('rule-text')), '取消的草稿');
    await _tap(tester, '取消');
    expect((await store.load()).videoTextRules.single.text, '屏蔽广告推销类视频');
    await _tap(tester, '编辑');
    await tester.enterText(find.byKey(const ValueKey('rule-text')), '屏蔽标题党视频');
    await _tap(tester, '保存规则');
    saved = await store.load();
    expect(saved.videoTextRules.single.text, '屏蔽标题党视频');
    // 编辑按 id 原位替换，不产生重复条目。
    expect(saved.videoTextRules.length, 1);
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    saved = await store.load();
    expect(saved.videoTextRules.single.enabled, false);
    await tester.pumpWidget(const SizedBox());
    await _open(tester, store);
    expect(find.text('屏蔽标题党视频'), findsOneWidget);
    await _tap(tester, '删除');
    await _tap(tester, '删除');
    expect((await store.load()).videoTextRules, isEmpty);
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
      expect((await store.load()).videoTextRules, isEmpty);
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
      expect((await store.load()).videoTextRules.single.text, '屏蔽剧透类视频');
    },
  );

  testWidgets('adding is disabled at the per-surface cap of 20', (
    tester,
  ) async {
    final store = JevRuleStore(box: _MemoryBox());
    await store.save(
      JevRuleConfig(
        videoTextRules: [
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
    // 已满时仍可编辑与启停存量规则；20 张卡超出视口，点首屏顶部的第一张。
    await tester.tap(find.text('编辑').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('rule-text')), '改写后的预置规则');
    await _tap(tester, '保存规则');
    final saved = await store.load();
    expect(saved.videoTextRules.length, LlmVideoRule.maxRulesPerSurface);
    expect(
      saved.videoTextRules.singleWhere((r) => r.id == 'seed-0').text,
      '改写后的预置规则',
    );
  });
}
