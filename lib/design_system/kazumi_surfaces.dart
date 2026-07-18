import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';

class KazumiAppBackdrop extends StatelessWidget {
  const KazumiAppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = context.design;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    if (highContrast) {
      return ColoredBox(color: colors.surface, child: child);
    }

    return ColoredBox(
      color: colors.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.94, -0.9),
                    radius: 1.18,
                    colors: [tokens.accentGlow, Colors.transparent],
                    stops: const [0, 1],
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.92, 0.96),
                    radius: 1.12,
                    colors: [tokens.secondaryGlow, Colors.transparent],
                    stops: const [0, 1],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class KazumiIconBadge extends StatelessWidget {
  const KazumiIconBadge({
    super.key,
    required this.icon,
    this.semanticLabel,
    this.size = 38,
    this.iconSize = 21,
    this.selected = false,
  });

  final IconData icon;
  final String? semanticLabel;
  final double size;
  final double iconSize;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = context.design;
    final fill = selected
        ? colors.primary
        : Color.alphaBlend(tokens.hoverOverlay, colors.primaryContainer);
    final foreground = selected ? colors.onPrimary : colors.onPrimaryContainer;
    final badge = SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: fill,
          shape: kazumiSmoothShape(tokens.radiusControl),
          shadows: [
            BoxShadow(
              color: tokens.accentGlow,
              blurRadius: 18,
              spreadRadius: -9,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, size: iconSize, color: foreground),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: badge);
    return Semantics(label: semanticLabel, image: true, child: badge);
  }
}

/// A simulated liquid-glass island for controls painted over video.
///
/// This deliberately avoids [BackdropFilter]: sampling a MediaKit or WebView
/// texture can be expensive or unstable on Windows GPUs. The layered tint,
/// sheen, border and restrained glow provide depth without touching the video
/// render surface.
class KazumiPlayerChrome extends StatelessWidget {
  const KazumiPlayerChrome({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = context.design;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final radius = borderRadius ?? BorderRadius.circular(tokens.radiusSurface);
    final fill = Colors.black.withValues(alpha: highContrast ? 0.9 : 0.54);
    final shape = RoundedSuperellipseBorder(
      borderRadius: radius,
      side: BorderSide(
        color:
            highContrast ? Colors.white : Colors.white.withValues(alpha: 0.2),
        width: highContrast ? 1.5 : 1,
      ),
    );
    Widget surface = ClipRSuperellipse(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: highContrast ? fill : null,
          gradient: highContrast
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.1),
                      fill,
                    ),
                    fill,
                    Color.alphaBlend(
                      colors.primary.withValues(alpha: 0.14),
                      fill,
                    ),
                  ],
                  stops: const [0, 0.6, 1],
                ),
          shape: shape,
        ),
        child:
            padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );
    surface = DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.transparent,
        shape: RoundedSuperellipseBorder(borderRadius: radius),
        shadows: [
          BoxShadow(
            color: colors.primary.withValues(alpha: highContrast ? 0 : 0.18),
            blurRadius: 26,
            spreadRadius: -14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 22,
            spreadRadius: -10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: surface,
    );
    surface = RepaintBoundary(child: surface);
    if (margin != null) surface = Padding(padding: margin!, child: surface);
    return surface;
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
    final colorAllowsBlur = color == null || color!.a < 1;
    final shouldBlur = enableBlur && !highContrast && colorAllowsBlur;
    final fill =
        color ?? (shouldBlur ? tokens.glassTint : colors.surfaceContainerHigh);
    final shape = RoundedSuperellipseBorder(
      borderRadius: radius,
      side: BorderSide(
        color:
            borderColor ?? (highContrast ? colors.outline : tokens.glassBorder),
        width: highContrast ? 1.5 : 1,
      ),
    );
    final decoration = ShapeDecoration(
      color: highContrast ? fill : null,
      gradient: highContrast
          ? null
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(tokens.surfaceHighlight, fill),
                fill,
                Color.alphaBlend(tokens.secondaryGlow, fill),
              ],
              stops: const [0, 0.58, 1],
            ),
      shape: shape,
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
    surface = ClipRSuperellipse(
      borderRadius: radius,
      clipBehavior: clipBehavior,
      child: surface,
    );
    if (shadow) {
      surface = DecoratedBox(
        decoration: ShapeDecoration(
          color: Colors.transparent,
          shape: RoundedSuperellipseBorder(borderRadius: radius),
          shadows: [
            BoxShadow(
              color: tokens.accentGlow,
              blurRadius: 30,
              spreadRadius: -14,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: tokens.subtleShadow,
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: surface,
      );
    }
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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = context.design;
    final radius =
        widget.borderRadius ?? BorderRadius.circular(tokens.radiusCompact);
    final hasAction = widget.onTap != null || widget.onLongPress != null;
    final interactive = widget.enabled && hasAction;
    final keyboardInteractive = widget.enabled && widget.onTap != null;
    final base = widget.color ?? colors.surfaceContainerLow;
    final fill = Color.alphaBlend(
      _pressed
          ? tokens.pressedOverlay
          : widget.selected
              ? tokens.selectedOverlay
              : _hovered
                  ? tokens.hoverOverlay
                  : Colors.transparent,
      base,
    );
    final shape = RoundedSuperellipseBorder(
      borderRadius: radius,
      side: BorderSide(
        color: _focused
            ? tokens.focusRing
            : colors.outlineVariant.withValues(alpha: 0.34),
        width: _focused ? 2 : 1,
      ),
    );
    final glowActive = interactive && (_hovered || _focused || widget.selected);

    return Semantics(
      button: hasAction,
      enabled: widget.enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: AnimatedContainer(
        duration: context.motion(KazumiDesignTokens.motionFast),
        curve: KazumiDesignTokens.standardCurve,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: fill,
          shape: shape,
          shadows: glowActive
              ? [
                  BoxShadow(
                    color: tokens.accentGlow,
                    blurRadius: 22,
                    spreadRadius: -11,
                    offset: const Offset(0, 4),
                  ),
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
            canRequestFocus: keyboardInteractive,
            customBorder: shape,
            onHover: interactive
                ? (value) => setState(() => _hovered = value)
                : null,
            onFocusChange: interactive
                ? (value) => setState(() => _focused = value)
                : null,
            onHighlightChanged: interactive
                ? (value) => setState(() => _pressed = value)
                : null,
            onTap: widget.enabled ? widget.onTap : null,
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
            shape: kazumiSmoothShape(
              tokens.radiusSurface,
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
