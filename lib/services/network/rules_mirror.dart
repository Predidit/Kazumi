import 'package:kazumi/services/network/acceleration_mode.dart';
import 'package:kazumi/services/storage/storage.dart';

enum RulesMirror implements AccelerationMode {
  ghProxy,
  ghfast,
  gitcode,
  direct;

  static RulesMirror get current =>
      values.asNameMap()[GStorage.getSetting(SettingsKeys.rulesMirror)] ??
      (GStorage.getSetting(SettingsKeys.enableGitProxy) ? ghProxy : direct);

  @override
  String get label => switch (this) {
    ghProxy => 'gh-proxy',
    ghfast => 'ghfast',
    gitcode => 'GitCode',
    direct => '直连',
  };

  @override
  String get description => switch (this) {
    ghProxy => '默认镜像',
    ghfast => '备用镜像',
    gitcode => '国内镜像',
    direct => '访问 GitHub',
  };
}
