enum UpdateDownloadSource {
  github,
  mirror;

  String get label => switch (this) {
    github => 'GitHub 官方源',
    mirror => '镜像源',
  };
}
