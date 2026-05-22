class CollectSyncPlan {
  const CollectSyncPlan({
    required this.webDavEnabled,
    required this.webDavCollectiblesEnabled,
    required this.bangumiEnabled,
  });

  final bool webDavEnabled;
  final bool webDavCollectiblesEnabled;
  final bool bangumiEnabled;

  bool get shouldSyncWebDavCollectibles =>
      webDavEnabled && webDavCollectiblesEnabled;

  bool get shouldSyncBangumi => bangumiEnabled;

  bool get canSync => shouldSyncWebDavCollectibles || shouldSyncBangumi;

  bool shouldUploadWebDavAfterBangumi({
    required bool webDavSynced,
    required bool bangumiSynced,
  }) {
    return shouldSyncWebDavCollectibles &&
        shouldSyncBangumi &&
        webDavSynced &&
        bangumiSynced;
  }
}
