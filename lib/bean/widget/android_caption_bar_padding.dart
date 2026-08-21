import 'package:flutter/material.dart';
import 'package:kazumi/services/platform/android_caption_bar.dart';

class AndroidCaptionBarTopPadding extends StatelessWidget {
  const AndroidCaptionBarTopPadding({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    AndroidCaptionBar.ensureInitialized();
    return ValueListenableBuilder<double>(
      valueListenable: AndroidCaptionBar.topInset,
      child: child,
      builder: (context, topInset, child) {
        return Padding(
          padding: EdgeInsets.only(
            top: topInset / MediaQuery.devicePixelRatioOf(context),
          ),
          child: child!,
        );
      },
    );
  }
}
