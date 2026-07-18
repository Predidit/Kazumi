import 'package:flutter/material.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';

/// A Windows-friendly settings list with bounded width and shared spacing.
class SettingsList extends StatelessWidget {
  const SettingsList({
    super.key,
    required this.sections,
    this.shrinkWrap = false,
    this.maxWidth,
    this.physics,
    this.contentPadding,
  });

  final bool shrinkWrap;
  final double? maxWidth;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? contentPadding;
  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: physics,
      shrinkWrap: shrinkWrap,
      itemCount: sections.length,
      padding: contentPadding ?? const EdgeInsets.fromLTRB(20, 12, 20, 28),
      itemBuilder: (context, index) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? KazumiDesignTokens.readableContentWidth,
          ),
          child: sections[index],
        ),
      ),
    );
  }
}

/// A tonal section used by all leaf settings pages.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.tiles,
    this.margin,
    this.title,
    this.bottomInfo,
  });

  final List<Widget> tiles;
  final EdgeInsetsDirectional? margin;
  final Widget? title;
  final Widget? bottomInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tokens = context.design;
    final radius = BorderRadius.circular(tokens.radiusSurface);
    final section = DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.transparent,
        shape: kazumiSmoothShape(tokens.radiusSurface),
        shadows: [
          BoxShadow(
            color: tokens.subtleShadow,
            blurRadius: 18,
            spreadRadius: -12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRSuperellipse(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.surfaceContainerLow,
            shape: kazumiSmoothShape(
              tokens.radiusSurface,
              side: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final tile in tiles)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: tile,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: margin ?? const EdgeInsetsDirectional.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 10),
              child: DefaultTextStyle(
                style: theme.textTheme.titleSmall!.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
                child: title!,
              ),
            ),
          section,
          if (bottomInfo != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(6, 10, 6, 0),
              child: DefaultTextStyle(
                style: theme.textTheme.bodySmall!.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                child: bottomInfo!,
              ),
            ),
        ],
      ),
    );
  }
}

enum _SettingsTileType { simple, navigation, toggle, checkbox, radio }

/// Compatibility-shaped settings tile backed by the Kazumi interaction model.
///
/// Keeping the familiar constructors lets feature pages preserve their state
/// and storage behavior while sharing one keyboard, hover, focus and disabled
/// implementation.
class SettingsTile<T> extends StatefulWidget {
  const SettingsTile({
    super.key,
    this.leading,
    this.trailing,
    required this.title,
    this.description,
    this.onPressed,
    this.enabled = true,
  })  : _type = _SettingsTileType.simple,
        onToggle = null,
        onChanged = null,
        value = null,
        initialValue = null,
        radioValue = null,
        groupValue = null;

  const SettingsTile.navigation({
    super.key,
    this.leading,
    this.trailing,
    this.value,
    required this.title,
    this.description,
    this.onPressed,
    this.enabled = true,
  })  : _type = _SettingsTileType.navigation,
        onToggle = null,
        onChanged = null,
        initialValue = null,
        radioValue = null,
        groupValue = null;

  const SettingsTile.switchTile({
    super.key,
    required this.initialValue,
    required this.onToggle,
    this.leading,
    this.trailing,
    required this.title,
    this.description,
    this.enabled = true,
  })  : _type = _SettingsTileType.toggle,
        onPressed = null,
        onChanged = null,
        value = null,
        radioValue = null,
        groupValue = null;

  const SettingsTile.checkboxTile({
    super.key,
    required this.initialValue,
    required this.onToggle,
    this.leading,
    this.trailing,
    required this.title,
    this.description,
    this.enabled = true,
  })  : _type = _SettingsTileType.checkbox,
        onPressed = null,
        onChanged = null,
        value = null,
        radioValue = null,
        groupValue = null;

  const SettingsTile.radioTile({
    super.key,
    required T this.radioValue,
    required this.groupValue,
    required this.onChanged,
    this.leading,
    this.trailing,
    required this.title,
    this.description,
    this.enabled = true,
  })  : _type = _SettingsTileType.radio,
        onPressed = null,
        onToggle = null,
        value = null,
        initialValue = null;

  final Widget? leading;
  final Widget? trailing;
  final Widget title;
  final Widget? description;
  final void Function(BuildContext)? onPressed;
  final ValueChanged<bool?>? onToggle;
  final ValueChanged<T?>? onChanged;
  final Widget? value;
  final bool? initialValue;
  final T? radioValue;
  final T? groupValue;
  final bool enabled;
  final _SettingsTileType _type;

  bool get _selected =>
      _type == _SettingsTileType.radio && radioValue == groupValue;

  bool get _actionable {
    return switch (_type) {
      _SettingsTileType.simple ||
      _SettingsTileType.navigation =>
        onPressed != null,
      _SettingsTileType.toggle ||
      _SettingsTileType.checkbox =>
        onToggle != null,
      _SettingsTileType.radio => onChanged != null,
    };
  }

  @override
  State<SettingsTile<T>> createState() => _SettingsTileState<T>();
}

class _SettingsTileState<T> extends State<SettingsTile<T>> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  void _activate() {
    if (!widget.enabled) return;
    switch (widget._type) {
      case _SettingsTileType.simple:
      case _SettingsTileType.navigation:
        widget.onPressed?.call(context);
      case _SettingsTileType.toggle:
      case _SettingsTileType.checkbox:
        widget.onToggle?.call(null);
      case _SettingsTileType.radio:
        widget.onChanged?.call(widget.radioValue);
    }
  }

  Widget _trailing(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final widgets = <Widget>[];
    if (widget.trailing != null) widgets.add(widget.trailing!);

    switch (widget._type) {
      case _SettingsTileType.toggle:
        widgets.add(
          ExcludeFocus(
            child: ExcludeSemantics(
              child: Switch(
                value: widget.initialValue ?? false,
                onChanged: widget.enabled ? widget.onToggle : null,
              ),
            ),
          ),
        );
      case _SettingsTileType.checkbox:
        widgets.add(
          ExcludeFocus(
            child: ExcludeSemantics(
              child: Checkbox(
                tristate: true,
                value: widget.initialValue,
                onChanged: widget.enabled ? widget.onToggle : null,
              ),
            ),
          ),
        );
      case _SettingsTileType.radio:
        widgets.add(
          ExcludeSemantics(
            child: Icon(
              widget._selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: widget._selected ? colors.primary : colors.outline,
            ),
          ),
        );
      case _SettingsTileType.navigation:
        if (widget.value != null) widgets.add(widget.value!);
        if (widget.onPressed != null) {
          widgets.add(
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: colors.onSurfaceVariant,
            ),
          );
        }
      case _SettingsTileType.simple:
        break;
    }

    if (widgets.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < widgets.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          widgets[index],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tokens = context.design;
    final actionable = widget.enabled && widget._actionable;
    final overlay = _pressed
        ? tokens.pressedOverlay
        : widget._selected
            ? tokens.selectedOverlay
            : _hovered
                ? tokens.hoverOverlay
                : Colors.transparent;
    final shape = kazumiSmoothShape(
      tokens.radiusControl,
      side: BorderSide(
        color: _focused ? tokens.focusRing : Colors.transparent,
        width: _focused ? 2 : 1,
      ),
    );

    final tile = Semantics(
      enabled: widget.enabled,
      button: (widget._type == _SettingsTileType.simple ||
              widget._type == _SettingsTileType.navigation) &&
          widget._actionable,
      toggled:
          widget._type == _SettingsTileType.toggle ? widget.initialValue : null,
      checked: widget._type == _SettingsTileType.checkbox ||
              widget._type == _SettingsTileType.radio
          ? (widget._type == _SettingsTileType.radio
              ? widget._selected
              : widget.initialValue)
          : null,
      inMutuallyExclusiveGroup: widget._type == _SettingsTileType.radio,
      child: AnimatedContainer(
        duration: context.motion(KazumiDesignTokens.motionFast),
        curve: KazumiDesignTokens.standardCurve,
        decoration: ShapeDecoration(
          color: overlay,
          shape: shape,
          shadows: actionable && (_hovered || _focused)
              ? [
                  BoxShadow(
                    color: tokens.accentGlow,
                    blurRadius: 18,
                    spreadRadius: -12,
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: shape,
            mouseCursor: actionable
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            canRequestFocus: actionable,
            onHover:
                actionable ? (value) => setState(() => _hovered = value) : null,
            onFocusChange:
                actionable ? (value) => setState(() => _focused = value) : null,
            onHighlightChanged:
                actionable ? (value) => setState(() => _pressed = value) : null,
            onTap: actionable ? _activate : null,
            child: Opacity(
              opacity: widget.enabled ? 1 : tokens.disabledOpacity,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 60),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      if (widget.leading != null) ...[
                        IconTheme.merge(
                          data: IconThemeData(color: colors.onSurfaceVariant),
                          child: widget.leading!,
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DefaultTextStyle(
                              style: theme.textTheme.titleSmall!.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              child: widget.title,
                            ),
                            if (widget.description != null) ...[
                              const SizedBox(height: 3),
                              DefaultTextStyle(
                                style: theme.textTheme.bodySmall!.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                                child: widget.description!,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      DefaultTextStyle(
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        child: _trailing(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final mergesControlSemantics = widget._type == _SettingsTileType.toggle ||
        widget._type == _SettingsTileType.checkbox ||
        widget._type == _SettingsTileType.radio;
    return mergesControlSemantics ? MergeSemantics(child: tile) : tile;
  }
}
