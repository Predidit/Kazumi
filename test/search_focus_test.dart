import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/search/search_page.dart';

void main() {
  testWidgets('Tab reaches search input then image search action',
      (tester) async {
    final controller = SearchController();
    final searchInputFocusNode = FocusNode(debugLabel: 'search input');
    final imageSearchFocusNode = FocusNode(debugLabel: 'image search');
    addTearDown(controller.dispose);
    addTearDown(searchInputFocusNode.dispose);
    addTearDown(imageSearchFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchEntryBar(
            searchController: controller,
            isFullScreen: false,
            searchInputFocusNode: searchInputFocusNode,
            imageSearchFocusNode: imageSearchFocusNode,
            suggestionsBuilder: (_, __) => const [],
            onSubmitted: (_) {},
            onImageSearch: () {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('图片搜索'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(searchInputFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(imageSearchFocusNode.hasFocus, isTrue);
  });
}
