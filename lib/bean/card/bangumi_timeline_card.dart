import 'package:flutter/material.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

class BangumiTimelineCard extends StatelessWidget {
  const BangumiTimelineCard({
    super.key,
    required this.bangumiItem,
    required this.showRating,
    required this.onTap,
    this.isWatching = false,
    this.compact = false,
  });

  final BangumiItem bangumiItem;
  final bool showRating;
  final bool isWatching;
  final bool compact;
  final VoidCallback onTap;

  static final _episodePattern =
      RegExp(r'^\s*([1-9]\d*)\s*[话話集](?=\s*(?:[/／]|$))');

  static double heightFor(TextScaler scaler, {bool compact = false}) =>
      (compact ? 48 : 64) +
      scaler.scale(22) * 2 +
      scaler.scale(18) +
      scaler.scale(20);

  String _supportingText(String title) {
    // Calendar subjects provide episodes in `info`, but no separate air date.
    final episodes = _episodePattern.firstMatch(bangumiItem.info);
    final metadata = <String>[
      if (episodes != null) '${episodes.group(1)} 话',
      ...(bangumiItem.metaTags.isNotEmpty
              ? bangumiItem.metaTags
              : bangumiItem.tags.map((tag) => tag.name))
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toSet(),
    ];
    if (metadata.isNotEmpty) return metadata.take(3).join(' · ');
    final originalName = bangumiItem.name.trim();
    return originalName != title ? originalName : '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final translatedName = bangumiItem.nameCn.trim();
    final title =
        translatedName.isNotEmpty ? translatedName : bangumiItem.name.trim();
    final supportingText = _supportingText(title);
    final radius = BorderRadius.all(Radius.circular(compact ? 20 : 24));

    return Semantics(
      button: true,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height:
                heightFor(MediaQuery.textScalerOf(context), compact: compact),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCover(context),
                  SizedBox(width: compact ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                            height: 1.375,
                          ),
                        ),
                        const Spacer(),
                        if (supportingText.isNotEmpty) ...[
                          Text(
                            supportingText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            if (showRating)
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildRating(context),
                                ),
                              )
                            else
                              const Spacer(),
                            if (isWatching) ...[
                              if (showRating) const SizedBox(width: 8),
                              Tooltip(
                                message: '正在追',
                                child: Icon(Icons.bookmark_rounded,
                                    size: 20,
                                    color: colors.primary,
                                    semanticLabel: '正在追'),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right_rounded,
                                size: 20, color: colors.onSurfaceVariant),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final imageUrl = bangumiItem.images['large'] ?? '';
    final width = compact ? 68.0 : 80.0;
    final height = compact ? 96.0 : 112.0;
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: imageUrl.isEmpty
          ? ColoredBox(
              color: colors.surfaceContainerHighest,
              child: SizedBox(
                width: width,
                height: height,
                child:
                    Icon(Icons.movie_outlined, color: colors.onSurfaceVariant),
              ),
            )
          : NetworkImgLayer(src: imageUrl, width: width, height: height),
    );
    return ExcludeSemantics(
      child: Hero(
        tag: bangumiItem.id,
        transitionOnUserGestures: true,
        child: cover,
      ),
    );
  }

  Widget _buildRating(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (bangumiItem.ratingScore <= 0) {
      return Text('暂无评分',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: colors.onSurfaceVariant));
    }
    final score = bangumiItem.ratingScore.toStringAsFixed(1);
    return Semantics(
      label: '评分 $score',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded,
                size: 14, color: colors.onSecondaryContainer),
            const SizedBox(width: 4),
            Flexible(
              child: Text(score,
                  maxLines: 1,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
