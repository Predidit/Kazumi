enum BangumiSyncPriority {
  localFirst(0, '本地优先'),
  bangumiFirst(1, 'Bangumi优先');

  const BangumiSyncPriority(this.value, this.label);

  final int value;
  final String label;

  static BangumiSyncPriority fromValue(int value) {
    return BangumiSyncPriority.values.firstWhere(
      (item) => item.value == value,
      orElse: () => BangumiSyncPriority.localFirst,
    );
  }
}
