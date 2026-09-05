import 'package:material_ui/material_ui.dart';
import 'package:m3e_core/m3e_core.dart';

enum _TileKind { plain, toggle, radio }

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

/// Retains settings callbacks while M3E owns the row shapes and motion.
class SettingsSplitGroup extends StatelessWidget {
  const SettingsSplitGroup({
    super.key,
    required this.children,
    this.outerRadius = 24,
  });

  final List<Widget> children;
  final double outerRadius;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++)
          Builder(builder: (context) {
            final tile = children[i];
            final onTap = switch (tile) {
              SettingsTile() => tile._tapHandler(context),
              SettingsCategoryTile() => tile.onTap,
              _ => null,
            };
            return M3ESegmentedItem(
              key: tile.key,
              index: i,
              position: calculateSegmentedItemPosition(i, children.length),
              outerRadius: outerRadius,
              innerRadius: 4,
              padding: EdgeInsets.zero,
              onTap: onTap == null ? null : (_) => onTap(),
              child: switch (tile) {
                SettingsTile() => tile._buildContent(context),
                SettingsCategoryTile() => tile._buildContent(context),
                _ => tile,
              },
            );
          }),
      ],
    );
  }
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

/// A row that opens a whole category rather than changing one value: the
/// tonal icon badge marks that step down, which is why [SettingsTile] keeps a
/// flat icon. Drop it in a [SettingsSplitGroup] like any other row.
class SettingsCategoryTile extends StatelessWidget {
  const SettingsCategoryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  Widget _buildContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return M3EListItem(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: colors.secondaryContainer,
        foregroundColor: colors.onSecondaryContainer,
        child: Icon(icon, size: 18),
      ),
      headline: Text(title),
      supportingText: Text(description),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: _buildContent(context),
      );
}

/// A settings label and value above the package slider.
class SettingsSliderTile extends StatelessWidget {
  const SettingsSliderTile({
    super.key,
    required this.title,
    required this.value,
    required this.valueLabel,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.leading,
    this.description,
  });

  final Widget title;
  final IconData? leading;
  final Widget? description;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        M3EListItem(
          leading: leading == null ? null : Icon(leading),
          headline: title,
          supportingText: description,
          trailing: Text(
            valueLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: M3ESlider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
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

  Widget _buildContent(BuildContext context) {
    final controls = <Widget>[
      if (value != null) value!,
      if (trailing != null) trailing!,
      if (_kind == _TileKind.toggle)
        Switch(
          value: initialValue ?? false,
          onChanged: enabled ? onToggle : null,
        ),
      if (_kind == _TileKind.radio)
        Radio<T>(value: radioValue as T, enabled: enabled),
    ];
    return M3EListItem(
      enabled: enabled,
      leading: leading == null ? null : Icon(leading),
      headline: title,
      // Settings explanations may span several lines, especially with large text.
      supportingText: description == null
          ? null
          : DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: enabled
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).disabledColor,
                  ),
              overflow: TextOverflow.visible,
              child: description!,
            ),
      trailing: controls.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: controls,
            ),
    );
  }

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: _tapHandler(context),
        child: _buildContent(context),
      );
}
