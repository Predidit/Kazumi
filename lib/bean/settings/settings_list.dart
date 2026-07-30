import 'package:flutter/material.dart';

enum _TileKind { plain, toggle, radio }

const double _outerRadius = 24;
const double _innerRadius = 4;
const double _rowGap = 4;

class SettingsList extends StatelessWidget {
  const SettingsList({super.key, required this.sections, this.maxWidth = 1000});

  final List<Widget> sections;

  /// Defaulted here so a page that says nothing still matches the others.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: sections.length,
      itemBuilder: (context, index) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: sections[index],
        ),
      ),
    );
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.tiles,
    this.title,
    this.bottomInfo,
    this.margin,
  });

  final List<Widget> tiles;
  final Widget? title;
  final Widget? bottomInfo;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: margin ?? const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DefaultTextStyle.merge(
                style:
                    textTheme.titleSmall?.copyWith(color: colorScheme.primary),
                child: title!,
              ),
            ),
          SettingsSplitGroup(children: tiles),
          if (bottomInfo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DefaultTextStyle.merge(
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                child: bottomInfo!,
              ),
            ),
        ],
      ),
    );
  }
}

/// Rows laid out as an M3 split list: large corners at the group's two ends,
/// small ones in between, and a pressed row morphing out of the group. That
/// morph is what separates the rows, in place of a divider.
class SettingsSplitGroup extends StatelessWidget {
  const SettingsSplitGroup({super.key, required this.children});

  final List<Widget> children;

  /// Hand to a row's [InkWell.onHighlightChanged] to drive the morph. Null
  /// outside a group, which leaves the row's shape static.
  static ValueChanged<bool>? pressReporterOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SplitRowScope>()
        ?.onPressChanged;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: _rowGap),
          _SplitRow(
            first: i == 0,
            last: i == children.length - 1,
            child: children[i],
          ),
        ],
      ],
    );
  }
}

class _SplitRow extends StatefulWidget {
  const _SplitRow({
    required this.first,
    required this.last,
    required this.child,
  });

  final bool first;
  final bool last;
  final Widget child;

  @override
  State<_SplitRow> createState() => _SplitRowState();
}

class _SplitRowState extends State<_SplitRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final top = widget.first || _pressed ? _outerRadius : _innerRadius;
    final bottom = widget.last || _pressed ? _outerRadius : _innerRadius;
    return Material(
      // Material animates its own shape, so the morph needs no controller.
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(top),
          bottom: Radius.circular(bottom),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _SplitRowScope(
        onPressChanged: (pressed) => setState(() => _pressed = pressed),
        child: widget.child,
      ),
    );
  }
}

class _SplitRowScope extends InheritedWidget {
  const _SplitRowScope({required this.onPressChanged, required super.child});

  final ValueChanged<bool> onPressChanged;

  // The callback always reaches the same state, so a rebuilt scope never
  // obsoletes the one a row already holds.
  @override
  bool updateShouldNotify(_SplitRowScope oldWidget) => false;
}

/// A [SettingsSection] whose tiles form a single radio group, so arrow keys
/// traverse the options and screen readers announce them as one set.
class SettingsRadioSection<T> extends StatelessWidget {
  const SettingsRadioSection({
    super.key,
    required this.groupValue,
    required this.onChanged,
    required this.tiles,
    this.title,
  });

  final T? groupValue;
  final ValueChanged<T?> onChanged;
  final List<Widget> tiles;
  final Widget? title;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<T>(
      groupValue: groupValue,
      onChanged: onChanged,
      child: SettingsSection(title: title, tiles: tiles),
    );
  }
}

class SettingsTile<T> extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.leading,
    this.description,
    this.trailing,
    this.value,
    this.onPressed,
    this.enabled = true,
  })  : _kind = _TileKind.plain,
        onToggle = null,
        initialValue = null,
        radioValue = null;

  /// Tapping the row toggles too, in which case [onToggle] receives null.
  const SettingsTile.switchTile({
    super.key,
    required this.title,
    required this.initialValue,
    required this.onToggle,
    this.leading,
    this.description,
    this.enabled = true,
  })  : _kind = _TileKind.toggle,
        trailing = null,
        value = null,
        onPressed = null,
        radioValue = null;

  /// Selection and change handling come from the enclosing
  /// [SettingsRadioSection], so the whole option list is one radio group.
  const SettingsTile.radioTile({
    super.key,
    required this.title,
    required T this.radioValue,
    this.leading,
    this.description,
    this.enabled = true,
  })  : _kind = _TileKind.radio,
        trailing = null,
        value = null,
        onPressed = null,
        onToggle = null,
        initialValue = null;

  final Widget title;

  /// Flat, not a tonal badge — the badge marks a row opening a whole category.
  final IconData? leading;
  final Widget? description;
  final Widget? trailing;
  final Widget? value;
  final void Function(BuildContext context)? onPressed;
  final void Function(bool? value)? onToggle;
  final bool? initialValue;
  final T? radioValue;
  final bool enabled;
  final _TileKind _kind;

  VoidCallback? _tapHandler(BuildContext context) {
    if (!enabled) {
      return null;
    }
    switch (_kind) {
      case _TileKind.plain:
        return onPressed == null ? null : () => onPressed!(context);
      case _TileKind.toggle:
        return onToggle == null ? null : () => onToggle!(null);
      case _TileKind.radio:
        final registry = RadioGroup.maybeOf<T>(context);
        return registry == null ? null : () => registry.onChanged(radioValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final disabled = colorScheme.onSurface.withValues(alpha: 0.38);
    final foreground = enabled ? colorScheme.onSurface : disabled;
    final secondary = enabled ? colorScheme.onSurfaceVariant : disabled;

    return InkWell(
      onTap: _tapHandler(context),
      onHighlightChanged: SettingsSplitGroup.pressReporterOf(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Row(
            children: [
              if (leading != null) ...[
                Icon(leading, size: 24, color: secondary),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(
                      style: textTheme.bodyLarge?.copyWith(color: foreground),
                      child: title,
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      DefaultTextStyle.merge(
                        style: textTheme.bodySmall?.copyWith(color: secondary),
                        child: description!,
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 12),
                DefaultTextStyle.merge(
                  style: textTheme.bodyMedium?.copyWith(color: secondary),
                  child: value!,
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                IconTheme.merge(
                  data: IconThemeData(color: secondary),
                  child: trailing!,
                ),
              ],
              if (_kind == _TileKind.toggle) ...[
                const SizedBox(width: 12),
                Switch(
                  value: initialValue ?? false,
                  onChanged: enabled ? onToggle : null,
                ),
              ],
              if (_kind == _TileKind.radio) ...[
                const SizedBox(width: 12),
                Radio<T>(value: radioValue as T, enabled: enabled),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
