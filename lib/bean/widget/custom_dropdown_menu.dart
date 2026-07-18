import 'package:flutter/material.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';
import 'package:kazumi/design_system/kazumi_surfaces.dart';

/// A custom dropdown menu widget that provides smooth animations without flickering.
///
/// This widget was created to solve the visual flickering issue in Flutter's built-in
/// [PopupMenuButton] where menu items are rendered before the animation completes,
/// causing an uncoordinated visual effect.
class CustomDropdownMenu extends StatelessWidget {
  final Offset offset;
  final Size buttonSize;
  final Animation<double> animation;
  final List<String> items;
  final String Function(String) itemBuilder;
  final String? selectedItem;
  final double? maxHeight;

  /// Minimum width constraint for the menu. Defaults to 140.
  /// Note: If [maxWidth] is less than [minWidth], [minWidth] will be used as both min and max.
  final double? minWidth;

  /// Maximum width constraint for the menu. Defaults to 200.
  /// Note: If this value is less than [minWidth], it will be adjusted to equal [minWidth].
  final double? maxWidth;
  final double gap;

  const CustomDropdownMenu({
    super.key,
    required this.offset,
    required this.buttonSize,
    required this.animation,
    required this.items,
    required this.itemBuilder,
    this.selectedItem,
    this.maxHeight,
    this.minWidth,
    this.maxWidth,
    this.gap = 4,
  });

  @override
  Widget build(BuildContext context) {
    // Ensure width constraints are valid (minWidth <= maxWidth)
    final computedMinWidth = minWidth ?? 140;
    final computedMaxWidth = maxWidth ?? 200;
    final media = MediaQuery.of(context);
    final availableWidth = (media.size.width - media.padding.horizontal - 16)
        .clamp(0.0, double.infinity)
        .toDouble();
    final availableHeight = (media.size.height - media.padding.vertical - 16)
        .clamp(0.0, double.infinity)
        .toDouble();
    final normalizedMinWidth =
        computedMinWidth.clamp(0.0, availableWidth).toDouble();
    final normalizedMaxWidth = (computedMaxWidth < computedMinWidth
            ? computedMinWidth
            : computedMaxWidth)
        .clamp(normalizedMinWidth, availableWidth)
        .toDouble();
    final resolvedMaxHeight =
        (maxHeight ?? 350).clamp(0.0, availableHeight).toDouble();
    final radius = BorderRadius.circular(context.design.radiusCompact);

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          CustomSingleChildLayout(
            delegate: _DropdownMenuLayoutDelegate(
              anchorOffset: offset,
              buttonSize: buttonSize,
              gap: gap,
              safePadding: media.padding,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: resolvedMaxHeight,
                minWidth: normalizedMinWidth,
                maxWidth: normalizedMaxWidth,
              ),
              child: KazumiGlassSurface(
                borderRadius: radius,
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final curvedValue = context.reduceMotion
                        ? 1.0
                        : KazumiDesignTokens.standardCurve
                            .transform(animation.value);
                    return IgnorePointer(
                      ignoring: curvedValue < 0.95,
                      child: Opacity(
                        opacity: curvedValue,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - curvedValue)),
                          child: Transform.scale(
                            scale: 0.985 + (0.015 * curvedValue),
                            alignment: Alignment.topCenter,
                            child: child,
                          ),
                        ),
                      ),
                    );
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final itemValue = items[index];
                      final displayText = itemBuilder(itemValue);
                      final isSelected = itemValue == selectedItem;
                      return MergeSemantics(
                        child: Semantics(
                          selected: isSelected,
                          child: MenuItemButton(
                            onPressed: () => Navigator.pop(context, itemValue),
                            trailingIcon: isSelected
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 20,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                            style: ButtonStyle(
                              alignment: Alignment.centerLeft,
                              minimumSize: const WidgetStatePropertyAll(
                                Size(0, 48),
                              ),
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              backgroundColor: isSelected
                                  ? WidgetStatePropertyAll(
                                      context.design.selectedOverlay,
                                    )
                                  : null,
                            ),
                            child: Text(displayText),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownMenuLayoutDelegate extends SingleChildLayoutDelegate {
  const _DropdownMenuLayoutDelegate({
    required this.anchorOffset,
    required this.buttonSize,
    required this.gap,
    required this.safePadding,
  });

  final Offset anchorOffset;
  final Size buttonSize;
  final double gap;
  final EdgeInsets safePadding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final minX = safePadding.left + 8;
    final maxX = size.width - safePadding.right - childSize.width - 8;
    final x = anchorOffset.dx.clamp(minX, maxX < minX ? minX : maxX).toDouble();

    final minY = safePadding.top + 8;
    final maxY = size.height - safePadding.bottom - childSize.height - 8;
    final below = anchorOffset.dy + buttonSize.height + gap;
    final above = anchorOffset.dy - gap - childSize.height;
    final preferredY = below <= maxY ? below : above;
    final y = preferredY.clamp(minY, maxY < minY ? minY : maxY).toDouble();
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _DropdownMenuLayoutDelegate oldDelegate) {
    return anchorOffset != oldDelegate.anchorOffset ||
        buttonSize != oldDelegate.buttonSize ||
        gap != oldDelegate.gap ||
        safePadding != oldDelegate.safePadding;
  }
}
