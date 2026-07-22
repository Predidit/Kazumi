import 'dart:io';

import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/proxy_utils.dart';
import 'package:kazumi/services/network/system_proxy_service.dart';
import 'package:kazumi/services/platform/platform_environment_service.dart';
import 'package:kazumi/services/player/playback_configurator_contract.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/media.dart';
import 'package:media_kit/media_kit.dart';

PlaybackConfigurator createPlaybackConfigurator({
  required String Function() shaderDirectoryPath,
}) {
  return NativePlaybackConfigurator(
    shaderDirectoryPath: shaderDirectoryPath,
  );
}

/// Preserves the existing mpv, proxy, Android renderer and shader behavior on
/// native platforms while keeping those APIs out of shared Web compilation.
class NativePlaybackConfigurator implements PlaybackConfigurator {
  NativePlaybackConfigurator({
    required String Function() shaderDirectoryPath,
  }) : _shaderDirectoryPath = shaderDirectoryPath;

  final String Function() _shaderDirectoryPath;

  @override
  Map<String, String> mediaHttpHeaders(
    Map<String, String> requestedHeaders,
  ) {
    return Map<String, String>.unmodifiable(requestedHeaders);
  }

  @override
  bool resolveAutoPlay(bool configuredAutoPlay) => configuredAutoPlay;

  @override
  bool get usePlayerVolume =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  bool requiresExplicitInitialSeek(String mediaUrl) => false;

  @override
  Future<PlaybackPlatformConfiguration?> configurePlayer(
    Player player,
    PlaybackPlatformOptions options, {
    required bool Function() isCurrent,
  }) async {
    final platform = player.platform;
    if (platform is! NativePlayer) {
      throw StateError('Expected media_kit NativePlayer on a native platform');
    }

    await platform.setProperty(
      'demuxer-cache-dir',
      await getPlayerTempPath(),
    );
    if (!isCurrent()) return null;

    await platform.setProperty('af', 'scaletempo2=max-speed=8');
    if (!isCurrent()) return null;

    if (Platform.isAndroid) {
      await platform.setProperty('volume-max', '100');
      if (!isCurrent()) return null;
      await platform.setProperty(
        'ao',
        options.androidEnableOpenSLES ? 'opensles' : 'audiotrack',
      );
      if (!isCurrent()) return null;
    }

    final bool proxyEnable = GStorage.getSetting(SettingsKeys.proxyEnable);
    if (proxyEnable) {
      final String proxyUrl = GStorage.getSetting(SettingsKeys.proxyUrl);
      final formattedProxy = ProxyUtils.getFormattedProxyUrl(proxyUrl);
      if (formattedProxy != null) {
        await platform.setProperty('http-proxy', formattedProxy);
        if (!isCurrent()) return null;
        KazumiLogger().i('Player: HTTP 浠ｇ悊璁剧疆鎴愬姛 $formattedProxy');
      }
    } else if (SystemProxyService.isActive) {
      final proxy = SystemProxyService.proxyFor('https');
      if (proxy != null) {
        final formattedProxy = 'http://${proxy.$1}:${proxy.$2}';
        await platform.setProperty('http-proxy', formattedProxy);
        if (!isCurrent()) return null;
        KazumiLogger().i('Player: 璺熼殢绯荤粺浠ｇ悊 $formattedProxy');
      }
    }

    String? videoRenderer;
    if (Platform.isAndroid) {
      final String androidVideoRenderer =
          GStorage.getSetting(SettingsKeys.androidVideoRenderer);
      if (androidVideoRenderer == 'auto') {
        final androidSdkVersion =
            await PlatformEnvironmentService.getAndroidSdkVersion();
        if (!isCurrent()) return null;
        videoRenderer = androidSdkVersion >= 34 ? 'gpu-next' : 'gpu';
      } else {
        videoRenderer = androidVideoRenderer;
      }
    }

    final usesEmbeddedMediaCodec = videoRenderer == 'mediacodec_embed';
    return PlaybackPlatformConfiguration(
      videoRenderer: videoRenderer,
      hardwareAccelerationEnabled:
          usesEmbeddedMediaCodec || options.hardwareAccelerationEnabled,
      hardwareDecoder:
          usesEmbeddedMediaCodec ? 'mediacodec' : options.hardwareDecoder,
      superResolutionMode: usesEmbeddedMediaCodec
          ? SuperResolutionMode.off
          : options.superResolutionMode,
    );
  }

  @override
  Future<SuperResolutionMode?> applySuperResolution(
    Player player,
    SuperResolutionMode mode, {
    required bool Function() isCurrent,
  }) async {
    final platform = player.platform;
    if (platform is! NativePlayer) {
      throw StateError('Expected media_kit NativePlayer on a native platform');
    }
    await platform.waitForPlayerInitialization;
    await platform.waitForVideoControllerInitializationIfAttached;
    if (!isCurrent()) return null;

    switch (mode) {
      case SuperResolutionMode.efficiency:
        await platform.command([
          'change-list',
          'glsl-shaders',
          'set',
          buildShadersAbsolutePath(
            _shaderDirectoryPath(),
            mpvAnime4KShadersLite,
          ),
        ]);
      case SuperResolutionMode.quality:
        await platform.command([
          'change-list',
          'glsl-shaders',
          'set',
          buildShadersAbsolutePath(
            _shaderDirectoryPath(),
            mpvAnime4KShaders,
          ),
        ]);
      case SuperResolutionMode.off:
        await platform.command(['change-list', 'glsl-shaders', 'clr', '']);
    }
    return isCurrent() ? mode : null;
  }
}
