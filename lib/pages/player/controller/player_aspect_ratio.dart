import 'package:flutter/material.dart';

enum PlayerAspectRatio {
  automatic(
    storageValue: 1,
    label: '自动',
    fit: BoxFit.contain,
  ),
  crop(
    storageValue: 2,
    label: '裁切填充',
    fit: BoxFit.cover,
  ),
  stretch(
    storageValue: 3,
    label: '拉伸填充',
    fit: BoxFit.fill,
  ),
  ratio4x3(
    storageValue: 4,
    label: '4:3',
    fit: BoxFit.fill,
    frameAspectRatio: 4 / 3,
  );

  const PlayerAspectRatio({
    required this.storageValue,
    required this.label,
    required this.fit,
    this.frameAspectRatio,
  });

  final int storageValue;
  final String label;
  final BoxFit fit;
  final double? frameAspectRatio;

  static PlayerAspectRatio fromStorageValue(int value) {
    return PlayerAspectRatio.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => PlayerAspectRatio.automatic,
    );
  }
}
