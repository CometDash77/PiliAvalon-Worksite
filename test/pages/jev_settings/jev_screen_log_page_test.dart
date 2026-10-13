import 'dart:convert';

import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/jev/jev_screen_log.dart';
import 'package:PiliPlus/pages/jev_settings/jev_screen_log_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
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

Future<JevScreenLog> _seededLog(_MemoryBox box) async {
  final log = JevScreenLog(box: box);
  await log.record([
    const JevScreenLogEntry(
      time: 1730000000000,
      kind: JevScreenLogKind.video,
      surface: 'hot',
      title: '被挡住的视频',
      snippet: '游戏',
    ),
    const JevScreenLogEntry(
      time: 1730000001000,
      kind: JevScreenLogKind.comment,
      surface: 'video_comments',
      title: '',
      line: JevScreenLogLine.llm,
      modelId: 'm1',
      failure: 'timeout',
      elapsedMs: 300,
    ),
  ]);
  return log;
}

Future<void> pumpPage(WidgetTester tester, JevScreenLog log) async {
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: FlutterSmartDialog.init(),
      home: JevScreenLogPage(log: log),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(JevSettingsStore.resetCache);

  tearDown(() {
    JevScreenLog.instance = JevScreenLog(box: _MemoryBox());
  });

  testWidgets('sections show llm fields and the bare failure row', (
    tester,
  ) async {
    await pumpPage(tester, await _seededLog(_MemoryBox()));

    expect(find.text('被屏蔽的视频'), findsOneWidget);
    expect(find.text('被屏蔽的评论'), findsOneWidget);
    expect(find.text('被挡住的视频'), findsOneWidget);
    // 空标题的通用线失败行展示占位标题与失败类别。
    expect(find.text('通用线失败'), findsOneWidget);
    expect(find.textContaining('模型:m1'), findsOneWidget);
    expect(find.textContaining('失败:timeout'), findsOneWidget);
    expect(find.textContaining('理由:'), findsNothing);
  });

  testWidgets('export shares a redacted JSON with llm fields', (tester) async {
    final log = await _seededLog(_MemoryBox());
    String? shared;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          shared = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await pumpPage(tester, log);

    expect(find.byTooltip('导出 JSON'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pumpAndSettle();
    // SmartDialog toast 的串行计时器(2s)要烧完,否则退出时仍有挂起 Timer。
    await tester.pump(const Duration(seconds: 3));

    expect(shared, isNotNull);
    final decoded = jsonDecode(shared!) as List<dynamic>;
    expect(decoded, hasLength(2));
    expect(
      decoded.whereType<Map>().any(
            (m) => m['line'] == 'llm' && m['modelId'] == 'm1',
          ),
      isTrue,
    );
    expect(shared!.contains('sk-'), isFalse);
    expect(shared!.contains('Authorization'), isFalse);
  });

  testWidgets('clear empties the view and disables the actions', (
    tester,
  ) async {
    final box = _MemoryBox();
    await pumpPage(tester, await _seededLog(box));

    await tester.tap(find.byTooltip('清空'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '清空'));
    await tester.pumpAndSettle();

    expect(find.textContaining('暂无记录'), findsNWidgets(2));
    expect(JevScreenLog(box: box).load(), isEmpty);
    final exportIcon = find.ancestor(
      of: find.byTooltip('导出 JSON'),
      matching: find.byType(IconButton),
    );
    expect(exportIcon, findsOneWidget);
    expect(tester.widget<IconButton>(exportIcon).onPressed, isNull);
  });
}
