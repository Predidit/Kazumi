import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';

class KazumiAppBackdrop extends StatelessWidget {
  const KazumiAppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              colors.primary.withValues(alpha: 0.045),
              colors.surface,
            ),
            colors.surface,
            Color.alphaBlend(
              colors.tertiary.withValues(alpha: 0.035),
              colors.surface,
            ),
          ],
          stops: const [0, 0.52, 1],
        ),
      ),
      child: child,
    );
  }
}

/// A bounded translucent surface for navigation and transient overlays.
///
/// High-contrast mode automatically falls back to an opaque tonal surface.
/// MediaKit and WebView callers should leave [enableBlur] false.
class KazumiGlassSurface extends StatelessWidget {
  const KazumiGlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.enableBlur = true,
    this.blurSigma,
    this.color,
    this.borderColor,
    this.shadow = true,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool enableBlur;
  final double? blurSigma;
  final Color? color;
  final Color? borderColor;
  final bool shadow;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tokens = context.design;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final radius = borderRadius ?? BorderRadius.circular(tokens.radiusSurface);
    final shouldBlur = enableBlur && !highContrast;
    final fill =
        color ?? (shouldBlur ? tokens.glassTint : colors.surfaceContainerHigh);
    final decoration = BoxDecoration(
      color: fill,
      borderRadius: radius,
      border: Border.all(
        color:
            borderColor ?? (highContrast ? colors.outline : tokens.glassBorder),
        width: highContrast ? 1.5 : 1,
      ),
      gradient: highContrast
          ? null
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(tokens.surfaceHighlight, fill),
                fill,
              ],
              stops: const [0, 0.62],
            ),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: tokens.subtleShadow,
                blurRadius: 24,
                spreadRadius: -8,
                offset: const Offset(0, 10),
              ),
            ]
          : null,
    );

    Widget surface = DecoratedBox(
      decoration: decoration,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
    if (shouldBlur) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurSigma ?? tokens.blurNavigation,
          sigmaY: blurSigma ?? tokens.blurNavigation,
        ),
        child: surface,
      );
    }
    surface = ClipRRect(
      borderRadius: radius,
      clipBehavior: clipBehavior,
      child: surface,
    );
    surface = RepaintBoundary(child: surface);
    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
    }
    return surface;
  }
}

class KazumiInteractiveSurface extends StatefulWidget {
  const KazumiInteractiveSurface({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.enabled = true,
    this.autofocus = false,
    this.borderRadius,
    this.color,
    this.padding,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool enabled;
  final bool autofocus;
  final BorderRadius? borderRadius;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;

  @override
  State<KazumiInteractiveSurface> createState() =>
      _KazumiInteractiveSurfaceState();
}

class _KazumiInteractiveSurfaceState extends State<KazumiInteractiveSurface> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = context.design;
    final radius =
        widget.borderRadius ?? BorderRadius.circular(tokens.radiusCompact);
    final interactive = widget.enabled && widget.onTap != null;
    final base = widget.color ?? colors.surfaceContainerLow;
    final fill = Color.alphaBlend(
      widget.selected
          ? tokens.selectedOverlay
          : _hovered
              ? tokens.hoverOverlay
              : Colors.transparent,
      base,
    );

    return Semantics(
      button: interactive,
      enabled: widget.enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: AnimatedContainer(
        duration: context.motion(KazumiDesignTokens.motionFast),
        curve: KazumiDesignTokens.standardCurve,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: radius,
          border: Border.all(
            color: _focused
                ? tokens.focusRing
                : colors.outlineVariant.withValues(alpha: 0.34),
            width: _focused ? 2 : 1,
          ),
          boxShadow: _hovered && interactive
              ? [
                  BoxShadow(
                    color: tokens.subtleShadow,
                    blurRadius: 18,
                    spreadRadius: -8,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            autofocus: widget.autofocus,
            canRequestFocus: interactive,
            borderRadius: radius,
            onHover: interactive
                ? (value) => setState(() => _hovered = value)
                : null,
            onFocusChange: interactive
                ? (value) => setState(() => _focused = value)
                : null,
            onTap: interactive ? widget.onTap : null,
            onLongPress: widget.enabled ? widget.onLongPress : null,
            child: Opacity(
              opacity: widget.enabled ? 1 : tokens.disabledOpacity,
              child: widget.padding == null
                  ? widget.child
                  : Padding(padding: widget.padding!, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class KazumiPageBody extends StatelessWidget {
  const KazumiPageBody({
    super.key,
    required this.child,
    this.maxWidth = KazumiDesignTokens.readableContentWidth,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 28),
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

enum KazumiStateKind { loading, empty, error, info, success }

class KazumiStatePanel extends StatelessWidget {
  const KazumiStatePanel({
    super.key,
    required this.kind,
    required this.title,
    this.message,
    this.actions = const [],
    this.compact = false,
  });

  final KazumiStateKind kind;
  final String title;
  final String? message;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tokens = context.design;
    final (icon, iconColor) = switch (kind) {
      KazumiStateKind.loading => (Icons.autorenew_rounded, colors.primary),
      KazumiStateKind.empty => (Icons.inbox_outlined, colors.onSurfaceVariant),
      KazumiStateKind.error => (Icons.error_outline_rounded, colors.error),
      KazumiStateKind.info => (Icons.info_outline_rounded, colors.primary),
      KazumiStateKind.success => (
          Icons.check_circle_outline_rounded,
          colors.primary
        ),
    };

    final panel = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kind == KazumiStateKind.loading)
              SizedBox.square(
                dimension: compact ? 28 : 36,
                child: const CircularProgressIndicator(),
              )
            else
              Container(
                width: compact ? 48 : 64,
                height: compact ? 48 : 64,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(tokens.radiusCompact),
                ),
                child: Icon(icon, color: iconColor, size: compact ? 26 : 32),
              ),
            SizedBox(height: compact ? 12 : 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (message != null && message!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (actions.isNotEmpty) ...[
              SizedBox(height: compact ? 14 : 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );

    return Semantics(
      liveRegion:
          kind == KazumiStateKind.loading || kind == KazumiStateKind.error,
      child: Center(
        child: SingleChildScrollView(
          primary: false,
          child: panel,
        ),
      ),
    );
  }
}

class KazumiSettingsSection extends StatelessWidget {
  const KazumiSettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.description,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tokens = context.design;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Material(
            color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radiusSurface),
              side: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.34),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index != children.length - 1)
                    Divider(
                      indent: 64,
                      endIndent: 12,
                      color: colors.outlineVariant.withValues(alpha: 0.38),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class KazumiSettingsTile extends StatelessWidget {
  const KazumiSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.selected = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      selected: selected,
      minVerticalPadding: 10,
      leading: leading,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing ??
          (onTap == null
              ? null
              : const Icon(Icons.chevron_right_rounded, size: 22)),
      onTap: enabled ? onTap : null,
    );
  }
}
