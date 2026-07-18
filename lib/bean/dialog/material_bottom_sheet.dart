import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/scrollable_wrapper.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';

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

class MaterialBottomSheetTabBar extends StatefulWidget {
  const MaterialBottomSheetTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.trailing,
    this.isScrollable = false,
    this.tabAlignment,
  });

  final List<Widget> tabs;
  final TabController? controller;
  final Widget? trailing;
  final bool isScrollable;
  final TabAlignment? tabAlignment;

  @override
  State<MaterialBottomSheetTabBar> createState() =>
      _MaterialBottomSheetTabBarState();
}

class _MaterialBottomSheetTabBarState extends State<MaterialBottomSheetTabBar> {
  TabBarScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    if (widget.isScrollable) {
      _scrollController = TabBarScrollController();
    }
  }

  @override
  void didUpdateWidget(MaterialBottomSheetTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScrollable != oldWidget.isScrollable) {
      _scrollController?.dispose();
      _scrollController = widget.isScrollable ? TabBarScrollController() : null;
    }
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.design;
    Widget tabBar = TabBar(
      controller: widget.controller,
      isScrollable: widget.isScrollable,
      scrollController: _scrollController,
      tabAlignment: widget.tabAlignment,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      splashBorderRadius: BorderRadius.circular(20),
      indicator: ShapeDecoration(
        color: colorScheme.secondaryContainer,
        shape: kazumiSmoothShape(tokens.radiusSurface),
      ),
      labelColor: colorScheme.onSecondaryContainer,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      tabs: widget.tabs,
    );
    if (_scrollController != null) {
      tabBar = ScrollableWrapper(
        scrollController: _scrollController!,
        child: tabBar,
      );
    }

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: colorScheme.surfaceContainerHighest,
        shape: kazumiSmoothShape(tokens.radiusSheet),
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.trailing == null
          ? tabBar
          : Row(
              children: [
                Expanded(child: tabBar),
                SizedBox.square(
                  dimension: 40,
                  child: widget.trailing!,
                ),
              ],
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
    final tokens = context.design;

    return Material(
      color: colorScheme.surfaceContainerLow,
      shape: kazumiSmoothShape(tokens.radiusSheet),
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
    final tokens = context.design;

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
          shape: kazumiSmoothShape(tokens.radiusSheet),
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
