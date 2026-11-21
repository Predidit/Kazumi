import 'dart:convert';

import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/utils/constants.dart'
    show mpvAnime4KShaders, mpvAnime4KShadersLite;

enum Upscaler {
  anime4k('Anime4K', '修复动画线条'),
  cunny('CuNNy 2×', '画面宽高均超过片源的 1.3 倍时运行');

  const Upscaler(this.label, this.description);
  final String label;
  final String description;

  static Upscaler fromName(String name) => name == cunny.name ? cunny : anime4k;

  static List<Upscaler> available({required bool computeShaders}) => [
    anime4k,
    if (computeShaders) cunny,
  ];

  List<SuperResolutionMode> get tiers => this == cunny
      ? SuperResolutionMode.active
      : const [SuperResolutionMode.efficiency, SuperResolutionMode.quality];

  SuperResolutionMode supportedTier(SuperResolutionMode tier) =>
      this == anime4k && tier == SuperResolutionMode.balanced
      ? SuperResolutionMode.efficiency
      : tier;

  String tierDescription(SuperResolutionMode tier) {
    if (this == anime4k) return tier.description;
    return switch (tier) {
      SuperResolutionMode.off => tier.description,
      SuperResolutionMode.efficiency => 'fast SOFT，渲染负载最低',
      SuperResolutionMode.balanced => '3×12 SOFT，兼顾线条与播放流畅度',
      SuperResolutionMode.quality => '4×16 SOFT，保留更多细线',
    };
  }

  List<String> shadersFor(SuperResolutionMode tier) {
    if (tier == SuperResolutionMode.off) return const [];
    if (this == anime4k) {
      return tier == SuperResolutionMode.quality
          ? mpvAnime4KShaders
          : mpvAnime4KShadersLite;
    }
    return switch (tier) {
      SuperResolutionMode.efficiency => const ['CuNNy-fast-SOFT.glsl'],
      SuperResolutionMode.balanced => const ['CuNNy-3x12-SOFT.glsl'],
      SuperResolutionMode.quality => const ['CuNNy-4x16-SOFT.glsl'],
      SuperResolutionMode.off => const [],
    };
  }
}

enum UpscalingOutputLimit {
  automatic(null),
  small(960),
  hd(1280),
  fullHd(1920),
  quadHd(2560),
  ultraHd(3840),
  cinema4k(4096);

  const UpscalingOutputLimit(this.pixels);
  final int? pixels;
  String get label => pixels == null ? '自动' : '$pixels 像素';

  static UpscalingOutputLimit decode(String setting) {
    if (setting.isNotEmpty) {
      try {
        final options = jsonDecode(setting);
        if (options is Map) {
          return values
                  .where((v) => v.name == options['outputLimit'])
                  .firstOrNull ??
              automatic;
        }
      } on FormatException {
        return automatic;
      }
    }
    return automatic;
  }

  String encode() => jsonEncode({'outputLimit': name});
}
