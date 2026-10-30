import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/duo_action.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/bean/widget/kazumi_menu_presentation.dart';

/// Reuses an existing stateful menu's entries and callbacks without adding
/// platform dependencies to that control or inspecting its widget tree.
class DuoMenuOwner extends StatelessWidget {
  const DuoMenuOwner({
    super.key,
    required this.label,
    required this.icon,
    this.selectionIcons,
    required this.child,
  });

  final String label;
  final IconData icon;
  final List<IconData>? selectionIcons;
  final Widget child;

  @override
  Widget build(BuildContext context) => KazumiMenuPresentation(
    builder: (context, entries, enabled) {
      if (entries.any((item) => item is! KazumiMenuItem)) return null;
      final items = entries.cast<KazumiMenuItem>();
      final selectedIndex = items.indexWhere((item) => item.selected == true);
      final selected = items.where((item) => item.selected == true).firstOrNull;
      return DuoActionBinding(
        action: DuoAction(
          label: selected?.label ?? label,
          icon:
              selectedIndex >= 0 &&
                  selectedIndex < (selectionIcons?.length ?? 0)
              ? selectionIcons![selectedIndex]
              : icon,
          menu: enabled
              ? [
                  for (final item in items)
                    DuoAction(
                      label: item.label,
                      icon: item.leadingIcon is Icon
                          ? (item.leadingIcon as Icon).icon
                          : null,
                      onPressed: item.onPressed,
                      selected: item.selected == true,
                      destructive: item.destructive,
                    ),
                ]
              : const [],
        ),
        child: const SizedBox.shrink(),
      );
    },
    child: child,
  );
}
