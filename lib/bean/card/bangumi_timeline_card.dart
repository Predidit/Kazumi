import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';

/// 时间线番剧卡片
class BangumiTimelineCard extends StatelessWidget {
  const BangumiTimelineCard({
    super.key,
    required this.bangumiItem,
    required this.showRating,
    this.onTap,
    this.cardHeight = 120,
    this.cardWidth,
    this.enableHero = true,
  });

  final BangumiItem bangumiItem;
  final bool showRating;
  final VoidCallback? onTap;
  final bool enableHero;
  final double cardHeight;
  final double? cardWidth;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Utils.isDesktop();
    final isTablet = Utils.isTablet();
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final double imageWidth = cardHeight * 0.7;
    final double borderRadius = 18;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap ??
            () {
              Modular.to.pushNamed('/info/', arguments: bangumiItem);
            },
        child: SizedBox(
          height: cardHeight,
          width: cardWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildImage(context, bangumiItem.images['large'] ?? '', imageWidth, cardHeight),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  child: buildInfo(context, textScaler, isDesktop, isTablet),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildImage(BuildContext context, String imageUrl, double width, double height) {
    final borderRadius = BorderRadius.circular(16);
    Widget img = NetworkImgLayer(
      src: imageUrl,
      width: width,
      height: height,
    );
    if (enableHero) {
      img = Hero(
        tag: bangumiItem.id,
        transitionOnUserGestures: true,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: img,
        ),
      );
    } else {
      img = ClipRRect(
        borderRadius: borderRadius,
        child: img,
      );
    }
    return img;
  }

  Widget buildInfo(BuildContext context, TextScaler textScaler, bool isDesktop,
      bool isTablet) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nameStyle =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    final subStyle = theme.textTheme.bodySmall
        ?.copyWith(color: colorScheme.onSurfaceVariant);
    final infoStyle =
        theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500);
    final maxLines = isDesktop ? 2 : 1;
    final double spacing = isDesktop ? 8 : 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Text(
          bangumiItem.nameCn.isNotEmpty ? bangumiItem.nameCn : bangumiItem.name,
          style: nameStyle,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textScaler: textScaler.clamp(maxScaleFactor: 1.1),
        ),
        SizedBox(height: spacing),
        // 简介
        if (bangumiItem.summary.isNotEmpty || bangumiItem.info.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha((255 * 0.10).round()),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  bangumiItem.info.isNotEmpty
                      ? bangumiItem.info
                      : bangumiItem.summary,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textScaler: textScaler.clamp(maxScaleFactor: 1.0),
                ),
              ),
            ),
          ),
        const Spacer(),
        Row(
          children: [
            if (showRating ? bangumiItem.ratingScore > 0 : true)
              Row(
                children: [
                  Icon(Icons.star_rounded,
                      size: 15, color: colorScheme.primary),
                  const SizedBox(width: 2),
                  Text(
                      showRating
                          ? bangumiItem.ratingScore.toStringAsFixed(1)
                          : '***',
                      style: infoStyle),
                ],
              ),
            if (showRating ? bangumiItem.rank > 0 : true)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: [
                    Icon(Icons.leaderboard,
                        size: 15, color: colorScheme.tertiary),
                    const SizedBox(width: 2),
                    Text(
                        showRating ? 'Rank ${bangumiItem.rank}' : 'Rank ***',
                        style: infoStyle),
                  ],
                ),
              ),
            const Spacer(),
            if (showRating ? bangumiItem.votes > 0 : true)
              Text(
                  showRating ? '评分人数: ${bangumiItem.votes}' : '评分人数: ***',
                  style: subStyle),
          ],
        ),
      ],
    );
  }
}
