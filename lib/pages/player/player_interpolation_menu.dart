import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/services/enhancement/frame_interpolation.dart';

/// Both layouts expose the same three operating budgets.
List<Widget> interpolationMenuItems({
  required InterpolationMode activeTier,
  required void Function(InterpolationMode) onSelect,
}) => [
  for (final tier in InterpolationMode.values)
    KazumiMenuItem(
      label: tier == InterpolationMode.off
          ? tier.label
          : '${FrameInterpolation.modelLabel} · ${tier.label}',
      selected: activeTier == tier,
      onPressed: () => onSelect(tier),
    ),
];
