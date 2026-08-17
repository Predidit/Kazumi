import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/expandable_selectable_text.dart';

void main() {
  Widget buildSubject(String text, {double width = 320}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: ExpandableSelectableText(text: text),
          ),
        ),
      ),
    );
  }

  testWidgets('short text stays selectable without expansion controls', (
    tester,
  ) async {
    const summary = '简短简介';

    await tester.pumpWidget(buildSubject(summary));
    await tester.pump();

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.text('加载更多'), findsNothing);
    expect(find.text('加载更少'), findsNothing);
    expect(tester.widget<Text>(find.text(summary)).maxLines, 7);
  });

  testWidgets('long text can expand and collapse after its display layout', (
    tester,
  ) async {
    final summary = List.filled(16, '这是一段需要折叠的番剧简介。').join();

    await tester.pumpWidget(buildSubject(summary, width: 220));
    await tester.pump();

    expect(find.text('加载更多'), findsOneWidget);
    expect(tester.widget<Text>(find.text(summary)).maxLines, 7);

    await tester.tap(find.text('加载更多'));
    await tester.pump();

    expect(find.text('加载更少'), findsOneWidget);
    expect(tester.widget<Text>(find.text(summary)).maxLines, isNull);

    await tester.tap(find.text('加载更少'));
    await tester.pump();

    expect(find.text('加载更多'), findsOneWidget);
    expect(tester.widget<Text>(find.text(summary)).maxLines, 7);
  });

  testWidgets('expansion control follows the actual available width', (
    tester,
  ) async {
    final summary = List.filled(8, '番剧简介内容。').join();

    await tester.pumpWidget(buildSubject(summary, width: 100));
    await tester.pump();
    expect(find.text('加载更多'), findsOneWidget);

    await tester.pumpWidget(buildSubject(summary, width: 700));
    await tester.pump();
    expect(find.text('加载更多'), findsNothing);
  });
}
