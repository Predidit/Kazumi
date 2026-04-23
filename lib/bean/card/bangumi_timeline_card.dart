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
    final colorScheme = theme.colorScheme;
    const double borderRadius = 16;
    const double horizontalPadding = 12;
    const double verticalPadding = 10;
    final double contentHeight = cardHeight > verticalPadding * 2
        ? cardHeight - (verticalPadding * 2)
        : cardHeight;
    final double imageWidth = contentHeight * 0.7;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap ??
            () {
              Modular.to.pushNamed('/info/', arguments: bangumiItem);
            },
        child: SizedBox(
          height: cardHeight,
          width: cardWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildImage(
                  context,
                  bangumiItem.images['large'] ?? '',
                  imageWidth,
                  contentHeight,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildInfo(context, textScaler, isDesktop, isTablet),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildImage(
      BuildContext context, String imageUrl, double width, double height) {
    final borderRadius = BorderRadius.circular(12);
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
    final title =
        bangumiItem.nameCn.isNotEmpty ? bangumiItem.nameCn : bangumiItem.name;
    final supportingText = bangumiItem.info.trim().isNotEmpty
        ? bangumiItem.info.trim()
        : bangumiItem.summary.trim();
    final bool useWideLayout = isDesktop || isTablet;
    final int supportingLines = useWideLayout ? 3 : 2;
    final nameStyle = theme.textTheme.titleSmall?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final subStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: nameStyle,
          maxLines: useWideLayout ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          textScaler:
              textScaler.clamp(maxScaleFactor: useWideLayout ? 1.2 : 1.1),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: supportingText.isNotEmpty ? 6 : 0),
            child: supportingText.isNotEmpty
                ? Text(
                    supportingText,
                    style: subStyle,
                    maxLines: supportingLines,
                    overflow: TextOverflow.ellipsis,
                    textScaler: textScaler.clamp(maxScaleFactor: 1.0),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 8),
        buildFooter(context),
      ],
    );
  }

  Widget buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metricStyle = theme.textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final showScore = showRating ? bangumiItem.ratingScore > 0 : true;
    final showRank = showRating ? bangumiItem.rank > 0 : true;
    final showVotes = showRating ? bangumiItem.votes > 0 : true;
    final rankText = showRating ? '#${bangumiItem.rank}' : '#***';
    final votesText = showRating ? bangumiItem.votes.toString() : '***';

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (showScore)
          buildMetric(
            context,
            icon: Icons.star_rounded,
            iconColor: colorScheme.primary,
            label:
                showRating ? bangumiItem.ratingScore.toStringAsFixed(1) : '***',
            textStyle: metricStyle,
          ),
        if (showRank)
          buildMetric(
            context,
            icon: Icons.leaderboard_outlined,
            iconColor: colorScheme.secondary,
            label: rankText,
            textStyle: metricStyle,
          ),
        if (showVotes)
          buildMetric(
            context,
            icon: Icons.how_to_vote_outlined,
            iconColor: colorScheme.onSurfaceVariant,
            label: votesText,
            textStyle: metricStyle,
          ),
      ],
    );
  }

  Widget buildMetric(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required TextStyle? textStyle,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 4),
        Text(label, style: textStyle),
      ],
    );
  }
}
