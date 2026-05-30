enum BangumiSyncPriority {
  localFirst(0, 'Local first'),
  bangumiFirst(1, 'Bangumi first');

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
