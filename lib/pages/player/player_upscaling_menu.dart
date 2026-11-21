import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/services/enhancement/upscaling.dart';

/// Shared by the wide player's button and the compact player's overflow menu.
List<Widget> upscalingMenuItems({
  required bool supportsComputeShaders,
  required Upscaler? activeModel,
  required SuperResolutionMode activeTier,
  required void Function(SuperResolutionMode, {Upscaler? upscaler}) onSelect,
}) => [
  KazumiMenuItem(
    label: '关闭',
    selected: activeTier == SuperResolutionMode.off,
    onPressed: () => onSelect(SuperResolutionMode.off),
  ),
  for (final model in Upscaler.available(
    computeShaders: supportsComputeShaders,
  ))
    SubmenuButton(
      menuChildren: [
        for (final tier in model.tiers)
          KazumiMenuItem(
            label: tier.label,
            selected: activeModel == model && activeTier == tier,
            onPressed: () => onSelect(tier, upscaler: model),
          ),
      ],
      leadingIcon: activeModel == model && activeTier != SuperResolutionMode.off
          ? const Icon(Icons.check_rounded)
          : null,
      child: Text(model.label),
    ),
];
