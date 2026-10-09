import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/menu_focus_bridge.dart';

void main() {
  late MenuFocusBridge bridge;
  late List<FocusNode> menuNodes;
  late List<FocusNode> contentNodes;

  setUp(() {
    bridge = MenuFocusBridge();
    // 搜索按钮 + 4 个目的地
    menuNodes = List.generate(5, (i) => FocusNode(debugLabel: 'menu $i'));
    contentNodes = List.generate(4, (i) => FocusNode(debugLabel: 'card $i'));
  });

  tearDown(() {
    bridge.dispose();
    for (final node in [...menuNodes, ...contentNodes]) {
      node.dispose();
    }
  });

  Widget button(FocusNode node) => SizedBox(
    width: 80,
    height: 80,
    child: TextButton(
      focusNode: node,
      onPressed: () {},
      child: const SizedBox.shrink(),
    ),
  );

  // 和主界面一样：左边一列导航按钮，右边是嵌套 Navigator 里的页面
  Future<void> pumpShell(WidgetTester tester, {required int selectedIndex}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Focus(
                focusNode: bridge.menuNode,
                onKeyEvent: (_, event) => bridge.handleMenuKey(
                  event,
                  toContent: TraversalDirection.right,
                ),
                child: Column(children: menuNodes.map(button).toList()),
              ),
              Expanded(
                child: Focus(
                  focusNode: bridge.contentNode,
                  onKeyEvent: (_, event) => bridge.handleContentKey(
                    event,
                    toMenu: TraversalDirection.left,
                    selectedIndex: selectedIndex,
                    destinationCount: 4,
                  ),
                  child: Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: 160,
                          child: Wrap(
                            children: contentNodes.map(button).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('内容区走到左边缘后，左键把焦点交给当前选中的导航项', (tester) async {
    await pumpShell(tester, selectedIndex: 2);
    contentNodes[1].requestFocus();
    await tester.pump();

    // 同一行左边还有卡片，先在内容区里移动
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(contentNodes[0].hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    // menuNodes[0] 是搜索按钮，第 2 个目的地是 menuNodes[3]
    expect(menuNodes[3].hasPrimaryFocus, isTrue);
  });

  testWidgets('从导航栏按右键回到离开时的那个控件', (tester) async {
    await pumpShell(tester, selectedIndex: 0);
    contentNodes[2].requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(menuNodes[1].hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(menuNodes[2].hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(contentNodes[2].hasPrimaryFocus, isTrue);
  });

  testWidgets('没有记录时，右键进入离导航项最近的控件', (tester) async {
    await pumpShell(tester, selectedIndex: 0);
    menuNodes[0].requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(contentNodes[0].hasPrimaryFocus, isTrue);
  });

  testWidgets('在导航栏上切换页面后，焦点留在导航栏', (tester) async {
    await pumpShell(tester, selectedIndex: 0);
    menuNodes[2].requestFocus();
    await tester.pump();

    bridge.keepMenuFocus();
    // 模拟新页面入栈后把焦点抢走
    contentNodes[0].requestFocus();
    await tester.pump();
    await tester.pump();
    expect(menuNodes[2].hasPrimaryFocus, isTrue);
  });

  testWidgets('离开时的控件已经被销毁时，右键不报错并进入最近的控件', (tester) async {
    final showFirst = ValueNotifier(true);
    addTearDown(showFirst.dispose);
    final stale = FocusNode(debugLabel: 'stale');
    addTearDown(stale.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Focus(
                focusNode: bridge.menuNode,
                onKeyEvent: (_, event) => bridge.handleMenuKey(
                  event,
                  toContent: TraversalDirection.right,
                ),
                child: button(menuNodes[0]),
              ),
              Expanded(
                child: Focus(
                  focusNode: bridge.contentNode,
                  onKeyEvent: (_, event) => bridge.handleContentKey(
                    event,
                    toMenu: TraversalDirection.left,
                  ),
                  child: Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => Align(
                        alignment: Alignment.topLeft,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: showFirst,
                          builder: (_, first, _) =>
                              button(first ? stale : contentNodes[0]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    stale.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(menuNodes[0].hasPrimaryFocus, isTrue);

    // 换页：离开时的那个控件被移出了组件树
    showFirst.value = false;
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(contentNodes[0].hasPrimaryFocus, isTrue);
  });

  testWidgets('输入框里的左键留给光标，不抢焦点', (tester) async {
    final fieldNode = FocusNode();
    addTearDown(fieldNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Focus(focusNode: bridge.menuNode, child: button(menuNodes[0])),
              Expanded(
                child: Focus(
                  focusNode: bridge.contentNode,
                  onKeyEvent: (_, event) => bridge.handleContentKey(
                    event,
                    toMenu: TraversalDirection.left,
                    selectedIndex: 0,
                    destinationCount: 1,
                  ),
                  child: Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) =>
                          Material(child: TextField(focusNode: fieldNode)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    fieldNode.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(fieldNode.hasPrimaryFocus, isTrue);
  });
}
