enum CollectSyncStep { webDav, bangumi, upload }

enum CollectSyncStatus { waiting, running, succeeded, failed, skipped }

class CollectSyncUpdate {
  const CollectSyncUpdate(this.step, this.status,
      {this.message, this.progress});

  final CollectSyncStep step;
  final CollectSyncStatus status;
  final String? message;
  final double? progress;
}

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

  List<CollectSyncStep> get steps => [
        if (shouldSyncWebDavCollectibles) CollectSyncStep.webDav,
        if (shouldSyncBangumi) CollectSyncStep.bangumi,
        if (shouldSyncWebDavCollectibles && shouldSyncBangumi)
          CollectSyncStep.upload,
      ];

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
