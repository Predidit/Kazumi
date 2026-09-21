part of 'collect_library_view.dart';

const _collectCategories = <CollectType?>[
  null,
  CollectType.watching,
  CollectType.planToWatch,
  CollectType.watched,
  CollectType.onHold,
  CollectType.abandoned,
];

class _CollectCategoryPager extends StatefulWidget {
  const _CollectCategoryPager({
    required this.selectedIndex,
    required this.onChanged,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_CollectCategoryPager> createState() => _CollectCategoryPagerState();
}

class _CollectCategoryPagerState extends State<_CollectCategoryPager> {
  late final _controller = PageController(
    initialPage: widget.selectedIndex,
    keepPage: false,
  );

  @override
  void didUpdateWidget(covariant _CollectCategoryPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex &&
        _controller.hasClients &&
        _controller.page?.round() != widget.selectedIndex) {
      // Tab taps jump; swipe callbacks keep the current animation.
      _controller.jumpToPage(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
        key: const ValueKey('collect-category-pages'),
        controller: _controller,
        onPageChanged: widget.onChanged,
        itemCount: widget.itemCount,
        itemBuilder: widget.itemBuilder,
        scrollBehavior:
            ScrollConfiguration.of(context).copyWith(scrollbars: false),
      );
}

class _CollectCategories extends StatefulWidget {
  const _CollectCategories({
    required this.selected,
    required this.count,
    required this.onSelected,
  });

  final CollectType? selected;
  final int Function(CollectType?) count;
  final ValueChanged<CollectType?> onSelected;

  @override
  State<_CollectCategories> createState() => _CollectCategoriesState();
}

class _CollectCategoriesState extends State<_CollectCategories> {
  final _controller = ScrollController(keepScrollOffset: false);
  final _keys = {for (final type in _collectCategories) type: GlobalKey()};

  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(covariant _CollectCategories oldWidget) {
    super.didUpdateWidget(oldWidget);
    _revealSelected();
  }

  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final target = _keys[widget.selected]?.currentContext?.findRenderObject();
      if (target == null) return;
      // Scroll only the tabs, never the enclosing collection viewport.
      _controller.position.ensureVisible(
        target,
        alignment: 0.5,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubicEmphasized,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SingleChildScrollView(
      key: const ValueKey('collect-filter-strip'),
      controller: _controller,
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 4,
        children: [
          for (final type in _collectCategories)
            Semantics(
              key: _keys[type],
              selected: type == widget.selected,
              inMutuallyExclusiveGroup: true,
              button: true,
              label: '${type?.label ?? '全部'}，${widget.count(type)} 部',
              excludeSemantics: true,
              onTap: () => widget.onSelected(type),
              child: TextButton(
                key: ValueKey('collect-filter-${type?.value ?? 'all'}'),
                onPressed: () => widget.onSelected(type),
                style: TextButton.styleFrom(
                  minimumSize: const Size(64, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: type == widget.selected
                      ? colors.primaryContainer
                      : Colors.transparent,
                  foregroundColor: type == widget.selected
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                  textStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: type == widget.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                child: Text(type?.label ?? '全部'),
              ),
            ),
        ],
      ),
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
