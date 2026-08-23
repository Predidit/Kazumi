import 'package:flutter/material.dart';

const Duration _kSectionAnimationDuration = Duration(milliseconds: 250);

final ShapeBorder _kSectionShape =
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

TextStyle? _sectionTitleStyle(ThemeData theme) =>
    theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    );

TextStyle? _sectionDescriptionStyle(ThemeData theme) => theme
    .textTheme.bodySmall
    ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

/// Shared tonal shell of the editor section cards.
class _SectionShell extends StatelessWidget {
  const _SectionShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: _kSectionShape,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Rounded tonal card grouping related editor fields, visually aligned with
/// [MaterialBottomSheetSection] and the onboarding cards: a primary-colored
/// icon, a bold title and an optional supporting description above the fields.
class EditorSectionCard extends StatelessWidget {
  const EditorSectionCard({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: _sectionTitleStyle(theme)),
                      if (description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          description!,
                          style: _sectionDescriptionStyle(theme),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              spacing: 16,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsible variant of [EditorSectionCard] sharing the same tonal shell
/// and header styling, for low-frequency groups like the advanced options.
class EditorExpandableSectionCard extends StatelessWidget {
  const EditorExpandableSectionCard({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionShell(
      child: ExpansionTile(
        maintainState: true,
        // Both shapes must drop the default divider border to keep the
        // tonal card seamless when expanded.
        shape: _kSectionShape,
        collapsedShape: _kSectionShape,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: _sectionTitleStyle(theme)),
        subtitle: description == null
            ? null
            : Text(description!, style: _sectionDescriptionStyle(theme)),
        children: children,
      ),
    );
  }
}

/// M3 outlined text field used inside [EditorSectionCard], carrying the card's
/// radius instead of the 4dp baseline.
///
/// Outlined rather than filled: these fields float a label, and only the
/// outline can notch around it. A fill would slice the label along the
/// container's top edge.
class EditorTextField extends StatelessWidget {
  const EditorTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        alignLabelWithHint: maxLines > 1,
        // Radius only: InputDecorator recolors this border per state from the
        // M3 defaults, covering hover and disabled as well.
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Labeled full-width [SegmentedButton] with an optional supporting line that
/// follows the selected value. Replaces the dropdown form fields for the
/// small fixed enums of the editor (mode, method, body type, ...).
class EditorSegmentedField<T> extends StatelessWidget {
  const EditorSegmentedField({
    super.key,
    required this.label,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.description,
  });

  final String label;
  final T value;
  final List<ButtonSegment<T>> segments;
  final ValueChanged<T> onChanged;

  /// Supporting text for the selected value, shown under the button.
  final String Function(T value)? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        SegmentedButton<T>(
          segments: segments,
          selected: {value},
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
        if (description != null) ...[
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: _kSectionAnimationDuration,
            child: Text(
              description!(value),
              key: ValueKey<T>(value),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}

/// Smooth transition for field groups that swap with [activeKey]: the old
/// group fades out while the container height eases to the new group.
class EditorAnimatedSection extends StatelessWidget {
  const EditorAnimatedSection({
    super.key,
    required this.activeKey,
    required this.child,
  });

  final Object activeKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: _kSectionAnimationDuration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: _kSectionAnimationDuration,
        // Default layout centers entries, which makes tall groups jump
        // vertically mid-transition; pin both to the top instead.
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        child: KeyedSubtree(
          key: ValueKey<Object>(activeKey),
          child: child,
        ),
      ),
    );
  }
}

/// Small primary-colored group header inside the advanced options card.
class EditorSubheader extends StatelessWidget {
  const EditorSubheader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
