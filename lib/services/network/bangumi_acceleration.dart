import 'package:kazumi/services/network/acceleration_mode.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/bangumi_mirror_credentials.dart';

enum BangumiAcceleration implements AccelerationMode {
  direct,
  ech,
  mirror;

  static bool get mirrorAvailable =>
      (bangumiMirrorCredentials['id'] ?? '').trim().isNotEmpty &&
      (bangumiMirrorCredentials['value'] ?? '').trim().isNotEmpty;

  static BangumiAcceleration get current {
    final configured = values.asNameMap()[GStorage.getSetting(
      SettingsKeys.bangumiAcceleration,
    )];
    final mode =
        configured ??
        (GStorage.getSetting(SettingsKeys.enableBangumiProxy)
            ? mirror
            : direct);
    return mode == mirror && !mirrorAvailable ? direct : mode;
  }

  @override
  String get label => switch (this) {
    direct => '直连',
    ech => 'ECH',
    mirror => '镜像',
  };

  @override
  String get description => switch (this) {
    direct => '访问官方接口',
    ech => '启用加密握手',
    mirror => '镜像接口（默认）',
  };
}
