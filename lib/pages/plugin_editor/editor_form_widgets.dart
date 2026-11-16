import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/connected_button_group.dart';
import 'package:kazumi/pages/plugin_editor/rule_management_widgets.dart';

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
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(label, style: theme.textTheme.labelLarge),
      const SizedBox(height: 8),
      Semantics(
        label: label,
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          autocorrect: false,
          enableSuggestions: false,
          style: maxLines > 1
              ? theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')
              : null,
          decoration: ruleInputDecoration(context, hint: hint),
        ),
      ),
      if (helper != null) ...[
        const SizedBox(height: 6),
        Text(helper!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    ]);
  }
}

class EditorChoiceGroup<T> extends StatelessWidget {
  const EditorChoiceGroup({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final List<ButtonSegment<T>> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final wrap = constraints.maxWidth <
            segments.length * MediaQuery.textScalerOf(context).scale(76);
        if (!wrap) {
          return ConnectedButtonGroup<T>(
              segments: segments, selected: value, onSelected: onChanged);
        }
        return Wrap(spacing: 4, runSpacing: 4, children: [
          for (final segment in segments)
            ConnectedButtonGroup<T>(
              expanded: false,
              segments: [segment],
              selected: value,
              onSelected: onChanged,
            ),
        ]);
      });
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
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          EditorChoiceGroup<T>(
              value: value, segments: segments, onChanged: onChanged),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(description!(value),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ],
      );
}

class EditorAnimatedSection extends StatelessWidget {
  const EditorAnimatedSection(
      {super.key, required this.activeKey, required this.child});
  final Object activeKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubicEmphasized,
        alignment: Alignment.topCenter,
        child: KeyedSubtree(key: ValueKey<Object>(activeKey), child: child),
      );
}

class EditorSubheader extends StatelessWidget {
  const EditorSubheader({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Text(label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600)),
      );
}
