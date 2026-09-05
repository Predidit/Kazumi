import 'package:material_ui/material_ui.dart';
import 'package:m3e_core/m3e_core.dart';

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
                      style: theme.emphasizedTextTheme.headlineSmall,
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

/// Connects M3E selection to both taps and swipes in a [TabBarView].
class MaterialBottomSheetSegmentedTabs extends StatelessWidget {
  const MaterialBottomSheetSegmentedTabs({
    super.key,
    required this.labels,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  final List<String> labels;
  final TabController? controller;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tabController = controller ?? DefaultTabController.of(context);
    assert(labels.length == tabController.length);
    if (labels.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: AnimatedBuilder(
        animation: tabController.animation!,
        builder: (context, _) => M3EToggleButtonGroup(
          type: M3EButtonGroupType.connected,
          style: M3EButtonStyle.tonal,
          selectedIndex: tabController.animation!.value
              .round()
              .clamp(0, labels.length - 1),
          onSelectedIndexChanged: (index) {
            if (index != null) tabController.animateTo(index);
          },
          actions: [
            for (final label in labels)
              M3EToggleButtonGroupAction(label: Text(label)),
          ],
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
                        style: theme.emphasizedTextTheme.titleMedium,
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
  });

  final String title;
  final List<Widget> children;

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
        M3ESegmentedColumn(
          padding: EdgeInsets.zero,
          children: children,
        ),
      ],
    );
  }
}
