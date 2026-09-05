part of 'collect_library_view.dart';

IconData _collectTypeIcon(CollectType type) => switch (type) {
      CollectType.none => Icons.delete_outline_rounded,
      CollectType.watching => Icons.play_circle_outline_rounded,
      CollectType.planToWatch => Icons.bookmark_border_rounded,
      CollectType.onHold => Icons.pause_circle_outline_rounded,
      CollectType.watched => Icons.task_alt_rounded,
      CollectType.abandoned => Icons.remove_circle_outline_rounded,
    };

class _CollectLibraryCard extends StatelessWidget {
  const _CollectLibraryCard({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onChangeType,
    required this.enabled,
  });

  final CollectedBangumi entry;
  final VoidCallback onOpen;
  final ValueChanged<CollectType> onChangeType;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final item = entry.bangumiItem;
    final title = CollectLibraryQuery.titleOf(entry);
    final type = CollectType.fromValue(entry.type);
    final airDate = DateTime.tryParse(item.airDate);
    final metadata = [
      if (airDate != null) '${airDate.year} 年',
      if (item.ratingScore > 0) '${item.ratingScore.toStringAsFixed(1)} 分',
    ];

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: NetworkImgLayer(
                    src: item.images['large'] ?? item.images['common'] ?? '',
                    width: 80,
                    height: 120,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 124),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                      if (metadata.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            metadata.join('  ·  '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Icon(_collectTypeIcon(type),
                              size: 16, color: colors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              type.label,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ),
                          MenuAnchor(
                            consumeOutsideTap: true,
                            style: MenuStyle(
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            menuChildren: [
                              for (final status in CollectType.values
                                  .where((type) => type.isCollected))
                                MenuItemButton(
                                  leadingIcon: Icon(_collectTypeIcon(status)),
                                  trailingIcon: status == type
                                      ? const Icon(Icons.check_rounded)
                                      : null,
                                  onPressed: !enabled || status == type
                                      ? null
                                      : () => onChangeType(status),
                                  child: Text(status.label),
                                ),
                              const Divider(),
                              MenuItemButton(
                                leadingIcon: Icon(
                                    _collectTypeIcon(CollectType.none),
                                    color: colors.error),
                                onPressed: enabled
                                    ? () => onChangeType(CollectType.none)
                                    : null,
                                child: Text('取消收藏',
                                    style: TextStyle(color: colors.error)),
                              ),
                            ],
                            builder: (context, controller, child) => IconButton(
                              tooltip: '管理《$title》',
                              constraints: const BoxConstraints(
                                  minWidth: 48, minHeight: 48),
                              onPressed: enabled
                                  ? () => controller.isOpen
                                      ? controller.close()
                                      : controller.open()
                                  : null,
                              icon: const Icon(Icons.more_horiz_rounded),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
