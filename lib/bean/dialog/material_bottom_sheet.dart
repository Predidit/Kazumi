import 'package:flutter/material.dart';

const double materialBottomSheetRadius = 24;
const EdgeInsets materialBottomSheetContentPadding =
    EdgeInsets.fromLTRB(16, 16, 16, 24);

class MaterialBottomSheetHeader extends StatelessWidget {
  const MaterialBottomSheetHeader({
    super.key,
    required this.title,
    this.description,
    this.onClose,
    this.footer,
    this.trailing,
  });

  final String title;
  final String? description;
  final VoidCallback? onClose;
  final Widget? footer;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ] else if (onClose != null) ...[
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: onClose,
                  tooltip: '关闭',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 16),
            footer!,
          ],
        ],
      ),
    );
  }
}

// Verbatim ConnectedButtonGroupSmallTokens: ContainerHeight, BetweenSpace,
// InnerCornerCornerSize, PressedInnerCornerCornerSize. Rounding these to the
// app's usual radius vocabulary breaks the group's proportions.

const double _connectedGroupHeight = 40;
const double _connectedGroupGap = 2;
const double _connectedInnerCorner = 8;
const double _connectedPressedInnerCorner = 4;

/// Material 3 Expressive connected button group driving a [TabBarView].
///
/// Outer edges stay `CornerFull`; only the corners facing a sibling move,
/// opening out on selection and tightening under a press. Driven off the
/// [TabController] animation so a drag carries the shape and colour with it.
class MaterialBottomSheetSegmentedTabs extends StatelessWidget {
  const MaterialBottomSheetSegmentedTabs({
    super.key,
    required this.labels,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  final List<String> labels;

  /// Falls back to the enclosing [DefaultTabController].
  final TabController? controller;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tabController = controller ?? DefaultTabController.of(context);

    return Padding(
      padding: padding,
      child: SizedBox(
        height: _connectedGroupHeight,
        child: AnimatedBuilder(
          animation: tabController.animation!,
          builder: (context, _) {
            final position = tabController.animation!.value;
            return Row(
              children: [
                for (var index = 0; index < labels.length; index++) ...[
                  if (index != 0) const SizedBox(width: _connectedGroupGap),
                  Expanded(
                    child: _ConnectedSegment(
                      label: labels[index],
                      selection: (1 - (position - index).abs()).clamp(0.0, 1.0),
                      isLeading: index == 0,
                      isTrailing: index == labels.length - 1,
                      onTap: () => tabController.animateTo(index),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConnectedSegment extends StatefulWidget {
  const _ConnectedSegment({
    required this.label,
    required this.selection,
    required this.isLeading,
    required this.isTrailing,
    required this.onTap,
  });

  final String label;
  final double selection;
  final bool isLeading;
  final bool isTrailing;
  final VoidCallback onTap;

  @override
  State<_ConnectedSegment> createState() => _ConnectedSegmentState();
}

class _ConnectedSegmentState extends State<_ConnectedSegment> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selection = widget.selection;
    const outerCorner = _connectedGroupHeight / 2;
    const outerRadius = Radius.circular(outerCorner);

    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selection > 0.5,
      // Only the press is tweened. Selection already tracks the tab
      // controller, and tweening it too would lag a drag.
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _pressed ? 1 : 0),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (context, press, child) {
          // A press only bites on a segment that is not already selected.
          var inner = _connectedInnerCorner +
              (outerCorner - _connectedInnerCorner) * selection;
          inner += (_connectedPressedInnerCorner - inner) *
              press *
              (1 - selection);
          final animated = Radius.circular(inner);
          return Material(
            // ToggleButtonDefaults fills the selected segment with `primary`,
            // too heavy for a sheet this only navigates. `secondaryContainer`
            // is the navigation active-indicator role.
            color: Color.lerp(
              colorScheme.surfaceContainer,
              colorScheme.secondaryContainer,
              selection,
            ),
            borderRadius: BorderRadiusDirectional.only(
              topStart: widget.isLeading ? outerRadius : animated,
              bottomStart: widget.isLeading ? outerRadius : animated,
              topEnd: widget.isTrailing ? outerRadius : animated,
              bottomEnd: widget.isTrailing ? outerRadius : animated,
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          );
        },
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: Center(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Color.lerp(
                  colorScheme.onSurfaceVariant,
                  colorScheme.onSecondaryContainer,
                  selection,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MaterialBottomSheetSection extends StatelessWidget {
  const MaterialBottomSheetSection({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.icon,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
  });

  final String title;
  final String? description;
  final IconData? icon;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(materialBottomSheetRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: colorScheme.primary),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class MaterialBottomSheetGroup extends StatelessWidget {
  const MaterialBottomSheetGroup({
    super.key,
    required this.title,
    required this.children,
    this.dividerIndent = 72,
  });

  final String title;
  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Material(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(materialBottomSheetRadius),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
                  Divider(
                    height: 1,
                    indent: dividerIndent,
                    color: colorScheme.outlineVariant,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
