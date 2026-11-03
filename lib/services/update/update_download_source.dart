enum UpdateDownloadSource {
  github,
  mirror;

  String get label => switch (this) {
    github => 'GitHub',
    mirror => '镜像',
  };
}
