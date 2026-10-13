import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/pages/jev_settings/jev_live_filter_log_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _MemoryBox implements JevSettingsBox {
  final Map<String, Object?> values = {};
  @override
  Object? get(String key, {Object? defaultValue}) =>
      values[key] ?? defaultValue;
  @override
  Future<void> put(String key, Object? value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  JevFilterLog makeLog(JevSettingsBox box) => JevFilterLog(
    box: box,
    storageKey: '${JevSettingsStore.namespace}.live_filter_log.v1',
    capacity: 500,
  );

  testWidgets('renders entries with numbers, rule question and reason', (
    tester,
  ) async {
    final box = _MemoryBox();
    await makeLog(box).record([
      const JevFilterLogEntry(
        time: 1730000000000,
        surface: 'live',
        title: '卖惨直播间',
        snippet: '求关注点个小红心',
        tags: ['虚拟主播'],
        noul: 0.97,
        threshold: 0.95,
        ruleId: 'keep-1',
        reason: '未命中任何保留规则（存在保留规则时需命中至少一条才展示）',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: JevLiveFilterLogPage(log: makeLog(box))),
    );
    await tester.pumpAndSettle();

    expect(find.text('卖惨直播间'), findsOneWidget);
    expect(find.textContaining('noul=0.97'), findsOneWidget);
    expect(find.textContaining('阈值=0.95'), findsOneWidget);
    // 数值缺失时如实说明,不编造。
    expect(find.textContaining('原因：未命中任何保留规则'), findsOneWidget);
    expect(find.textContaining('重启后保留最新 500 条'), findsOneWidget);
  });

  testWidgets('missing numbers say so honestly instead of fabricating', (
    tester,
  ) async {
    final box = _MemoryBox();
    await makeLog(box).record([
      const JevFilterLogEntry(
        time: 1730000000000,
        surface: 'live',
        title: '缓存命中的直播间',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: JevLiveFilterLogPage(log: makeLog(box))),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('本次数值未记录'), findsOneWidget);
    expect(find.textContaining('内置阈值筛除'), findsOneWidget);
  });

  testWidgets('empty state explains itself and disables clear', (tester) async {
    final box = _MemoryBox();
    await tester.pumpWidget(
      MaterialApp(home: JevLiveFilterLogPage(log: makeLog(box))),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('暂无真实直播筛除记录'), findsOneWidget);
    final clear = tester.widget<IconButton>(
      find.ancestor(of: find.byTooltip('清空'), matching: find.byType(IconButton)),
    );
    expect(clear.onPressed, isNull);
  });

  testWidgets('clear button wipes records after confirmation', (tester) async {
    final box = _MemoryBox();
    final log = makeLog(box);
    await log.record([
      const JevFilterLogEntry(
        time: 1730000000000,
        surface: 'live',
        title: '待清空直播间',
      ),
    ]);

    await tester.pumpWidget(MaterialApp(home: JevLiveFilterLogPage(log: log)));
    await tester.pumpAndSettle();
    expect(find.text('待清空直播间'), findsOneWidget);

    await tester.tap(find.byTooltip('清空'));
    await tester.pumpAndSettle();
    expect(find.text('清空直播筛除记录'), findsOneWidget);

    await tester.tap(find.text('清空').last);
    await tester.pumpAndSettle();

    expect(log.load(), isEmpty);
    expect(find.textContaining('暂无真实直播筛除记录'), findsOneWidget);
  });
}
