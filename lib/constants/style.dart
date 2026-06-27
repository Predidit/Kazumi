import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class StyleString {
  static const double cardSpace = 8;
  static const double safeSpace = 12;
  static BorderRadius mdRadius = BorderRadius.circular(10);
  static const Radius imgRadius = Radius.circular(12);
  static const double aspectRatio = 16 / 10;
}

const String customAppFontFamily = "MI_Sans_Regular";

/// Opts into the newer Material progress indicator appearance while Flutter
/// still exposes the compatibility flag.
/// ignore: deprecated_member_use
const ProgressIndicatorThemeData progressIndicatorTheme2024 =
    ProgressIndicatorThemeData(year2023: false);

/// Opts into the newer Material slider appearance while Flutter still exposes
/// the compatibility flag.
/// ignore: deprecated_member_use
const SliderThemeData sliderTheme2024 = SliderThemeData(
  year2023: false,
  showValueIndicator: ShowValueIndicator.onDrag,
);

/// Flutter-managed platform transitions. Route-level Modular transitions should
/// avoid overriding these unless the native page transition is intentionally bypassed.
const PageTransitionsTheme pageTransitionsTheme2024 = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
  },
);

/// Layout breakpoint according to google:
/// https://developer.android.com/develop/ui/compose/layouts/adaptive/use-window-size-classes.
///
/// **It's only a suggestion since not every device meet the breakpoint requirement.
/// You need to build layout with some more judgements.**
///
/// Some example device(portrait) width x height:
///
/// * iPhone SE3: 375 x 667
/// * iPhone 16: 393 x 852
/// * iPad Pro 11-inch: 834 x 1210
/// * HW MATE60 Pro: 387.7 x 836.9
/// * OHOS in floating window: 387.7 x 631.7 or 218.1
class LayoutBreakpoint {
  static const Map<String, double> compact = {'width': 600, 'height': 480};
  static const Map<String, double> medium = {'width': 840, 'height': 900};
}
