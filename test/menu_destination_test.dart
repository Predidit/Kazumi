import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/menu/menu.dart';

void main() {
  test('底栏图标在选中前后使用不同样式', () {
    for (final destination in bottomMenuDestinations) {
      final icon = destination.icon as Icon;
      final selectedIcon = destination.selectedIcon as Icon;

      expect(
        icon.icon,
        isNot(selectedIcon.icon),
        reason: '${destination.label} 应使用不同的未选中与选中图标',
      );
    }

    final settings = bottomMenuDestinations.last;
    expect((settings.icon as Icon).icon, Icons.settings_outlined);
    expect((settings.selectedIcon as Icon).icon, Icons.settings);
  });
}
