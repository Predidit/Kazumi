import 'package:flutter/material.dart';

extension ImageExtension on num {
  int? cacheSize(BuildContext context) {
    final value = toDouble();
    if (!value.isFinite || value <= 0) {
      return null;
    }

    final scaled = value * MediaQuery.of(context).devicePixelRatio;
    if (!scaled.isFinite || scaled <= 0) {
      return null;
    }

    final result = scaled.round();
    return result > 0 ? result : null;
  }
}
