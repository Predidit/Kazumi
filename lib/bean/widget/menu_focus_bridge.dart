import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 让方向键 / 遥控器 D-pad 能在导航栏和页面内容之间来回移动焦点。
///
/// 页面内容放在嵌套 Navigator 里，每个路由都有自己的 FocusScope，而 Flutter 的
/// 方向键焦点遍历不会越过当前 FocusScope，所以焦点一旦进了内容区就再也回不到导航栏。
/// 这里在内容区走到边缘时把焦点手动交给导航栏，反方向同理。
class MenuFocusBridge {
  final FocusNode menuNode = FocusNode(
    debugLabel: 'MenuFocusBridge.menu',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final FocusNode contentNode = FocusNode(
    debugLabel: 'MenuFocusBridge.content',
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// 离开内容区时的焦点，回来时优先还原到它
  FocusNode? _lastContentFocus;

  void dispose() {
    menuNode.dispose();
    contentNode.dispose();
  }

  /// 在导航栏上按确认切换页面前调用。新路由入栈时会把焦点抢进自己的 FocusScope，
  /// 这里等它抢完再把焦点还给刚才按下的导航项，否则接着按上下键就跑到页面里去了。
  void keepMenuFocus() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || !focus.ancestors.contains(menuNode)) return;
    var remainingFrames = 3;
    void restore(Duration _) {
      if (focus.context == null || !focus.canRequestFocus) return;
      if (!focus.hasPrimaryFocus) focus.requestFocus();
      if (--remainingFrames > 0) {
        WidgetsBinding.instance.addPostFrameCallback(restore);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback(restore);
  }

  static TraversalDirection? _directionOf(KeyEvent event) {
    if (event is KeyUpEvent) return null;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) return TraversalDirection.left;
    if (key == LogicalKeyboardKey.arrowRight) return TraversalDirection.right;
    if (key == LogicalKeyboardKey.arrowUp) return TraversalDirection.up;
    if (key == LogicalKeyboardKey.arrowDown) return TraversalDirection.down;
    return null;
  }

  static bool _isUsable(FocusNode node) {
    if (node is FocusScopeNode || node.context == null) return false;
    final rect = node.rect;
    return node.canRequestFocus && rect.isFinite && !rect.isEmpty;
  }

  static FocusNode? _nearest(Iterable<FocusNode> nodes, Offset origin) {
    FocusNode? nearest;
    var nearestDistance = double.infinity;
    for (final node in nodes) {
      final distance = (node.rect.center - origin).distanceSquared;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = node;
      }
    }
    return nearest;
  }

  /// 内容区的按键处理：[toMenu] 方向上已经没有可去的控件时，把焦点交给导航栏。
  ///
  /// 给了 [selectedIndex] 和 [destinationCount] 就落到当前选中的目的地上，
  /// 否则落到离当前焦点最近的那一项。
  KeyEventResult handleContentKey(
    KeyEvent event, {
    required TraversalDirection toMenu,
    int? selectedIndex,
    int? destinationCount,
  }) {
    if (_directionOf(event) != toMenu) return KeyEventResult.ignored;
    final focus = FocusManager.instance.primaryFocus;
    final focusContext = focus?.context;
    if (focus == null || focusContext == null) return KeyEventResult.ignored;
    // 输入框里的方向键要留给光标
    if (focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    if (focus.focusInDirection(toMenu)) return KeyEventResult.handled;

    final targets = menuNode.traversalDescendants.where(_isUsable).toList();
    if (targets.isEmpty) return KeyEventResult.ignored;
    final FocusNode target;
    if (selectedIndex != null && destinationCount != null) {
      final horizontal =
          toMenu == TraversalDirection.left ||
          toMenu == TraversalDirection.right;
      targets.sort(
        (a, b) => horizontal
            ? a.rect.top.compareTo(b.rect.top)
            : a.rect.left.compareTo(b.rect.left),
      );
      // 目的地排在最后（侧边栏顶部还有一个搜索按钮）
      target =
          targets[(targets.length - destinationCount + selectedIndex).clamp(
            0,
            targets.length - 1,
          )];
    } else {
      target = _nearest(targets, focus.rect.center)!;
    }
    _lastContentFocus = focus;
    target.requestFocus();
    return KeyEventResult.handled;
  }

  /// 导航栏的按键处理：按 [toContent] 方向时把焦点送回内容区。
  KeyEventResult handleMenuKey(
    KeyEvent event, {
    required TraversalDirection toContent,
  }) {
    if (_directionOf(event) != toContent) return KeyEventResult.ignored;
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return KeyEventResult.ignored;

    final last = _lastContentFocus;
    _lastContentFocus = null;
    if (last != null &&
        _isUsable(last) &&
        last.ancestors.contains(contentNode)) {
      last.requestFocus();
      return KeyEventResult.handled;
    }

    final nearest = _nearest(
      contentNode.traversalDescendants.where(_isUsable),
      focus.rect.center,
    );
    if (nearest == null) return KeyEventResult.ignored;
    nearest.requestFocus();
    return KeyEventResult.handled;
  }
}
