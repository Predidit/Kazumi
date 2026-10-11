enum UpdateDownloadSource {
  github,
  mirror;

  static UpdateDownloadSource fromSetting(String value) =>
      values.firstWhere((source) => source.name == value, orElse: () => mirror);

  String get label => switch (this) {
    github => 'GitHub 官方源',
    mirror => '镜像源',
  };

  String get description => switch (this) {
    github => '直接从 GitHub 下载应用更新',
    mirror => '从镜像源下载应用更新',
  };
}
