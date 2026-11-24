import 'package:flutter/material.dart';

import 'package:kazumi/bean/widget/split_list_row.dart';

/// Standalone tappable M3E card that opens a picker sheet.
class SplitListSelectorCard extends StatelessWidget {
  const SplitListSelectorCard({
    super.key,
    required this.leading,
    required this.title,
    required this.semanticsLabel,
    required this.onTap,
    this.subtitle,
    this.titleMaxLines = 2,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final String semanticsLabel;
  final VoidCallback onTap;
  final int titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final subtitleText = subtitle;

    final subtitleWidget = subtitleText == null || subtitleText.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Tooltip(
              message: subtitleText,
              child: Text(
                subtitleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          );

    return Semantics(
      button: true,
      label: semanticsLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: SplitListRow(
        first: true,
        last: true,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: colors.onPrimaryContainer,
                      size: 18,
                    ),
                    child: DefaultTextStyle.merge(
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      child: leading,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (disableAnimations)
                      subtitleWidget
                    else
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topLeft,
                        child: subtitleWidget,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.unfold_more_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selectable segmented list row with a leading badge, title, optional
/// subtitle, and optional trailing indicator or selected checkmark.
class SplitListOptionRow extends StatelessWidget {
  const SplitListOptionRow({
    super.key,
    required this.badge,
    required this.title,
    required this.semanticsLabel,
    required this.onTap,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.first = false,
    this.last = false,
    this.selected = false,
    this.showSelectedCheck = false,
  });

  final String badge;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final String semanticsLabel;
  final VoidCallback onTap;
  final bool first;
  final bool last;
  final bool selected;
  final bool showSelectedCheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final subtitleText = subtitle;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: semanticsLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: SplitListRow(
        first: first,
        last: last,
        selected: selected,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Builder(
              builder: (context) => Row(
                children: [
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.primary
                          : colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(selected ? 20 : 10),
                    ),
                    child: Center(
                      child: Text(
                        badge,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: selected ? colors.onPrimary : colors.primary,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: SplitListRow.contentColorOf(
                              context,
                              colors.onSurface,
                            ),
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        if (subtitleText != null &&
                            subtitleText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitleText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: SplitListRow.contentColorOf(
                                context,
                                subtitleColor ?? colors.onSurfaceVariant,
                              ),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ] else if (showSelectedCheck && selected) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: colors.onSecondaryContainer,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
