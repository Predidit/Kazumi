import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GamepadActivateIntent extends Intent {
  const GamepadActivateIntent();
}

class GamepadNavigateIntent extends Intent {
  const GamepadNavigateIntent(this.direction);

  final TraversalDirection direction;
}

class GamepadBackIntent extends Intent {
  const GamepadBackIntent();
}

class GamepadSecondaryActionIntent extends Intent {
  const GamepadSecondaryActionIntent();
}

class GamepadContextActionIntent extends Intent {
  const GamepadContextActionIntent();
}

class GamepadPreviousSectionIntent extends Intent {
  const GamepadPreviousSectionIntent();
}

class GamepadNextSectionIntent extends Intent {
  const GamepadNextSectionIntent();
}

class GamepadPreviousSecondarySectionIntent extends Intent {
  const GamepadPreviousSecondarySectionIntent();
}

class GamepadNextSecondarySectionIntent extends Intent {
  const GamepadNextSecondarySectionIntent();
}

class GamepadMenuIntent extends Intent {
  const GamepadMenuIntent();
}

class GamepadViewIntent extends Intent {
  const GamepadViewIntent();
}

class GamepadLeftStickClickIntent extends Intent {
  const GamepadLeftStickClickIntent();
}

class GamepadRightStickClickIntent extends Intent {
  const GamepadRightStickClickIntent();
}

/// Flutter's offstage routes can retain nodes; only navigate visible routes.
bool isGamepadFocusUsable(FocusNode node) {
  final context = node.context;
  if (context == null ||
      !node.canRequestFocus ||
      node is FocusScopeNode ||
      node.skipTraversal) {
    return false;
  }
  bool visible = ModalRoute.of(context)?.isCurrent ?? true;
  context.visitAncestorElements((element) {
    if (element.widget is Offstage && (element.widget as Offstage).offstage) {
      visible = false;
    }
    return visible;
  });
  for (final ancestor in node.ancestors) {
    final ancestorContext = ancestor.context;
    if (ancestorContext != null &&
        ModalRoute.of(ancestorContext)?.isCurrent == false) {
      return false;
    }
  }
  return visible;
}

bool focusFirstGamepadControl(FocusNode scope) {
  final remembered = scope is FocusScopeNode ? scope.focusedChild : null;
  if (remembered != null && isGamepadFocusUsable(remembered)) {
    remembered.requestFocus();
    return true;
  }
  for (final node in scope.traversalDescendants) {
    if (isGamepadFocusUsable(node)) {
      node.requestFocus();
      return true;
    }
  }
  return false;
}

/// Whether the current primary focus is inside an editable text field.
///
/// Directional traversal must not be swallowed by text-editing shortcuts or a
/// focused text field becomes a dead end for the joystick.
bool primaryFocusIsEditable() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  if (context.widget is EditableText) return true;
  if (context.findAncestorWidgetOfExactType<EditableText>() != null) {
    return true;
  }
  if (context is! Element) return false;
  bool found = false;
  void visit(Element element) {
    if (found) return;
    if (element is StatefulElement && element.state is EditableTextState) {
      found = true;
      return;
    }
    element.visitChildren(visit);
  }

  context.visitChildren(visit);
  return found;
}

/// Reuse the focused control's arrow action (slider, text field, etc.) without
/// synthesizing key events or accidentally invoking default focus traversal.
bool invokeGamepadControlDirection(TraversalDirection direction) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  // Text fields own the arrow keys for cursor movement; let the caller fall
  // back to focus traversal so the stick can always leave the field.
  if (primaryFocusIsEditable()) return false;
  final key = switch (direction) {
    TraversalDirection.up => LogicalKeyboardKey.arrowUp,
    TraversalDirection.down => LogicalKeyboardKey.arrowDown,
    TraversalDirection.left => LogicalKeyboardKey.arrowLeft,
    TraversalDirection.right => LogicalKeyboardKey.arrowRight,
  };
  bool handled = false;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is! Shortcuts) return true;
    for (final entry in widget.shortcuts.entries) {
      final activator = entry.key;
      final matches = activator is SingleActivator &&
          activator.trigger == key &&
          !activator.control &&
          !activator.shift &&
          !activator.alt &&
          !activator.meta;
      if (!matches) continue;
      final intent = entry.value;
      if (intent is DirectionalFocusIntent) return false;
      final action = Actions.maybeFind<Intent>(context, intent: intent);
      if (action != null && action.isEnabled(intent)) {
        Actions.invoke(context, intent);
        handled = true;
      }
      return false;
    }
    return true;
  });
  return handled;
}
