import 'package:flutter/material.dart';

/// workaround for padding check error on Xiaomi HyperOS devices
/// caused by flutter/flutter#161086
/// this is a temporary solution, will be removed in the future
class SafeMediaQueryWrapper extends StatelessWidget {
  final Widget child;
  final double defaultTopPadding;
  final double defaultBottomPadding;

  const SafeMediaQueryWrapper({
    super.key,
    required this.child,
    this.defaultTopPadding = 25,
    this.defaultBottomPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewPadding = mediaQuery.viewPadding;

    final isPaddingCheckError = viewPadding.top < 0 || viewPadding.top > 50;

    if (!isPaddingCheckError) {
      return child;
    }

    return MediaQuery(
      data: mediaQuery.copyWith(
        viewPadding: EdgeInsets.only(
          top: defaultTopPadding,
          bottom: defaultBottomPadding,
          left: viewPadding.left,
          right: viewPadding.right,
        ),
        padding: EdgeInsets.only(
          top: defaultTopPadding,
          bottom: defaultBottomPadding,
          left: mediaQuery.padding.left,
          right: mediaQuery.padding.right,
        ),
      ),
      child: child,
    );
  }
}
