import 'package:flutter_modular/flutter_modular.dart';
import 'package:material_ui/material_ui.dart';

/// Modular's [TransitionType.material] builds a `package:flutter/material`
/// [MaterialPage], whose route resolves its animation from the legacy [Theme] —
/// which no longer exists above the navigator after the `material_ui` migration,
/// so the route would silently fall back to the framework defaults instead of
/// `pageTransitionsTheme2024`.
///
/// This page is the same thing built from `package:material_ui`, so the app's
/// own [PageTransitionsTheme] keeps driving every default route transition.
class MaterialUiTransition extends PageTransition {
  const MaterialUiTransition();

  @override
  Page<void> buildPage(LocalKey key, Widget child) =>
      MaterialPage<void>(key: key, child: child);
}
