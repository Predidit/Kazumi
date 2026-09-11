import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

class StateIconBadge extends StatelessWidget {
  const StateIconBadge({
    super.key,
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: ClipPath(
          clipper: const _StateShapeClipper(),
          child: ColoredBox(
            color: backgroundColor,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, size: iconSize, color: foregroundColor),
            ),
          ),
        ),
      );
}

class _StateShapeClipper extends CustomClipper<Path> {
  const _StateShapeClipper();

  static final _path = MaterialShapes.cookie4Sided.toPath();

  @override
  Path getClip(Size size) => _path
      .transform(Matrix4.diagonal3Values(size.width, size.height, 1).storage);

  @override
  bool shouldReclip(_StateShapeClipper oldClipper) => false;
}

class StateActionButton extends StatelessWidget {
  const StateActionButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.reserveText,
  }) : _tonal = false;

  const StateActionButton.tonal({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.reserveText,
  }) : _tonal = true;

  final VoidCallback? onPressed;
  final String text;
  final IconData? icon;

  /// Reserves label space for a longer status without changing button size.
  final String? reserveText;
  final bool _tonal;

  static ButtonStyle styleOf(BuildContext context) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
      shape: WidgetStateProperty.resolveWith((states) => RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
                states.contains(WidgetState.pressed) ? 16 : 28),
          )),
      animationDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = _tonal ? FilledButton.tonalIcon : FilledButton.icon;
    final label = Text(text, textAlign: TextAlign.center);
    return button(
      onPressed: onPressed,
      style: styleOf(context),
      icon: icon == null ? null : Icon(icon, size: 20),
      label: reserveText == null
          ? label
          : Stack(
              alignment: Alignment.center,
              children: [
                Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainState: true,
                  maintainAnimation: true,
                  child: Text(reserveText!, textAlign: TextAlign.center),
                ),
                label,
              ],
            ),
    );
  }
}
