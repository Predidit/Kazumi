import 'package:flutter/material.dart';

const Duration _kSectionAnimationDuration = Duration(milliseconds: 250);

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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

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
        // Pin both transition entries to the top to prevent vertical jumps.
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
