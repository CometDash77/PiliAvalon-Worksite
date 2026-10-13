import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/pages/jev_settings/jev_filter_log_section.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

class _MemoryBox implements JevSettingsBox {
  final Map<String, Object?> values = <String, Object?>{};

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

JevFilterLogEntry entry(
  String title, {
  double? noul = 0.95,
  double? confidence,
  double? threshold = 0.95,
  String? ruleId,
  int? time,
}) => JevFilterLogEntry(
  time: time ?? DateTime.now().millisecondsSinceEpoch,
  surface: JevSurface.hot.id,
  title: title,
  tags: const ['游戏'],
  noul: noul,
  confidence: confidence,
  threshold: threshold,
  ruleId: ruleId,
);

Future<void> pumpSection(WidgetTester tester, JevFilterLog log) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(children: [JevFilterLogSection(log: log)]),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => JevFilterLog.revision.value = 0);

  testWidgets('空状态如实说明', (tester) async {
    await pumpSection(tester, JevFilterLog(box: _MemoryBox()));

    expect(find.text('暂无真实过滤记录'), findsOneWidget);
    expect(find.textContaining('连接验证与测试不会写入'), findsOneWidget);
  });

  testWidgets('记录展示场景/主题/判定数值与回退原因', (tester) async {
    final log = JevFilterLog(box: _MemoryBox());
    await log.record([entry('视频A')]);

    await pumpSection(tester, log);

    expect(find.text('视频A'), findsOneWidget);
    expect(find.textContaining('热门'), findsOneWidget);
    expect(find.textContaining('主题：游戏'), findsOneWidget);
    expect(find.textContaining('noul=0.95'), findsOneWidget);
    expect(find.textContaining('阈值=0.95'), findsOneWidget);
    expect(find.textContaining('达到筛除阈值；上游未提供具体原因'), findsOneWidget);
  });

  testWidgets('规则命中展示规则标识与置信度', (tester) async {
    final log = JevFilterLog(box: _MemoryBox());
    await log.record([
      entry('视频B', noul: null, confidence: 0.96, ruleId: 'r1'),
    ]);

    await pumpSection(tester, log);

    expect(find.textContaining('命中规则「r1」'), findsOneWidget);
    expect(find.textContaining('置信度=0.96'), findsOneWidget);
    expect(find.textContaining('noul='), findsNothing);
  });

  testWidgets('数值缺失时说明缺失,不编造', (tester) async {
    final log = JevFilterLog(box: _MemoryBox());
    await log.record([
      entry('视频C', noul: null, confidence: null, threshold: null),
    ]);

    await pumpSection(tester, log);

    expect(find.textContaining('本次数值未记录（命中本地判定缓存）'), findsOneWidget);
  });

  testWidgets('超过 5 条只渲染最新 5 条', (tester) async {
    final log = JevFilterLog(box: _MemoryBox());
    await log.record([for (var i = 1; i <= 6; i++) entry('t$i')]);

    await pumpSection(tester, log);

    expect(find.text('t6'), findsOneWidget);
    expect(find.text('t1'), findsNothing);
  });

  testWidgets('新记录写入后经 revision 自动刷新', (tester) async {
    final log = JevFilterLog(box: _MemoryBox());
    await pumpSection(tester, log);
    expect(find.text('暂无真实过滤记录'), findsOneWidget);

    await log.record([entry('新记录')]);
    await tester.pump();

    expect(find.text('新记录'), findsOneWidget);
    expect(find.text('暂无真实过滤记录'), findsNothing);
  });
}