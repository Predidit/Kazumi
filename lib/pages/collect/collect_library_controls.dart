part of 'collect_library_view.dart';

class _CollectCategories extends StatelessWidget {
  const _CollectCategories({
    super.key,
    required this.controller,
    required this.count,
  });

  final TabController controller;
  final int Function(CollectType?) count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return TabBar(
      key: const PageStorageKey('collect-filter-strip'),
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      dividerHeight: 0,
      indicatorSize: TabBarIndicatorSize.tab,
      indicatorPadding: const EdgeInsets.symmetric(horizontal: 2),
      indicator: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      indicatorAnimation: TabIndicatorAnimation.elastic,
      labelColor: colors.onPrimaryContainer,
      unselectedLabelColor: colors.onSurfaceVariant,
      labelStyle:
          theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      unselectedLabelStyle:
          theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      splashBorderRadius: BorderRadius.circular(24),
      tabs: [
        for (final type in _collectCategories)
          Tab(
            height: 48,
            child: Semantics(
              label: '${type?.label ?? '全部'}，${count(type)} 部',
              excludeSemantics: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(type?.label ?? '全部'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CollectLayoutSwitch extends StatelessWidget {
  const _CollectLayoutSwitch({required this.value, required this.onChanged});

  final CollectLayout value;
  final ValueChanged<CollectLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        for (final layout in [CollectLayout.cards, CollectLayout.list])
          Semantics(
            selected: value == layout,
            inMutuallyExclusiveGroup: true,
            child: IconButton.filledTonal(
              tooltip: '${layout.label}布局',
              isSelected: value == layout,
              onPressed: () => onChanged(layout),
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                visualDensity: VisualDensity.standard,
                backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? colors.secondaryContainer
                        : colors.surfaceContainerLow),
                foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? colors.onSecondaryContainer
                        : colors.onSurfaceVariant),
                shape: WidgetStateProperty.resolveWith((states) =>
                    RoundedRectangleBorder(
                      borderRadius: states.contains(WidgetState.pressed)
                          ? BorderRadius.circular(12)
                          : states.contains(WidgetState.selected)
                              ? BorderRadius.circular(24)
                              : BorderRadiusDirectional.horizontal(
                                  start: Radius.circular(
                                      layout == CollectLayout.cards ? 24 : 8),
                                  end: Radius.circular(
                                      layout == CollectLayout.list ? 24 : 8),
                                ),
                    )),
                animationDuration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
              ),
              icon: Icon(layout == CollectLayout.list
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded),
            ),
          ),
      ],
    );
  }
}

class _CollectSortMenu extends StatelessWidget {
  const _CollectSortMenu({
    required this.value,
    required this.showLabel,
    required this.onChanged,
  });

  final CollectSort value;
  final bool showLabel;
  final ValueChanged<CollectSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      consumeOutsideTap: true,
      menuChildren: [
        for (final sort in CollectSort.values)
          MenuItemButton(
            trailingIcon:
                value == sort ? const Icon(Icons.check_rounded) : null,
            onPressed: () => onChanged(sort),
            child: Text(sort.label),
          ),
      ],
      builder: (context, controller, child) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        return Tooltip(
          message: '排序：${value.label}',
          child: showLabel
              ? TextButton.icon(
                  onPressed: toggle,
                  style: TextButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.sort_rounded, size: 20),
                  label: Text(value.label),
                )
              : IconButton(
                  onPressed: toggle,
                  icon: const Icon(Icons.sort_rounded),
                ),
        );
      },
    );
  }
}
