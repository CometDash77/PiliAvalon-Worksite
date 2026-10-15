import 'dart:async';

import 'package:PiliPlus/pages/video/reply/widgets/filtered_comments_continuation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'an all-hidden page offers the next page and prevents duplicate loads',
    (tester) async {
      var page = 1;
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilteredCommentsContinuation(
              onLoadMore: () async {
                page++;
                await pending.future;
              },
            ),
          ),
        ),
      );
      expect(find.text('加载下一页'), findsOneWidget);
      await tester.tap(find.text('加载下一页'));
      await tester.pump();
      expect(page, 2);
      expect(find.text('加载中…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('加载下一页'), findsOneWidget);
    },
  );
}
