import 'package:flutter/material.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';
import 'package:kazumi/design_system/kazumi_surfaces.dart';

/// Rounded tonal card for a rule entry, shared by the rule manage page,
/// the rule shop page and the onboarding rule step.
class RuleCard extends StatelessWidget {
  const RuleCard({
    super.key,
    required this.title,
    this.tags = const [],
    this.caption,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  final String title;
  final List<Widget> tags;

  /// Plain text shown after [tags], e.g. the last update date.
  final String? caption;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KazumiInteractiveSurface(
        color: selected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerLow,
        selected: selected,
        onTap: onTap,
        onLongPress: onLongPress,
        semanticLabel: title,
        child: ListTile(
          mouseCursor: onTap != null || onLongPress != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          selected: selected,
          title: Text(title, style: textTheme.titleMedium),
          subtitle: tags.isEmpty && caption == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...tags,
                      if (caption != null)
                        Text(
                          caption!,
                          style: textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
          trailing: trailing,
        ),
      ),
    );
  }
}

/// Fixed-width tonal action button for [RuleCard] trailing slots, so the
/// button edge stays aligned across rows regardless of label length
/// (e.g. 安装 / 更新 / 已安装). Pass null [onPressed] for the disabled state.
class RuleCardActionButton extends StatelessWidget {
  const RuleCardActionButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: FilledButton.tonal(
        onPressed: onPressed,
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Small tonal label used inside [RuleCard], e.g. version or captcha tags.
class RuleTag extends StatelessWidget {
  const RuleTag({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: ShapeDecoration(
        color: background,
        shape: kazumiSmoothShape(999),
      ),
      child: Text(
        label,
        style:
            Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
