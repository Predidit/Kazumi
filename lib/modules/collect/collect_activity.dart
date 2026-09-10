class CollectActivity {
  CollectActivity({
    required Set<int> pendingIds,
    required this.isSyncing,
    required this.hasPending,
  }) : pendingIds = Set.unmodifiable(pendingIds);

  final Set<int> pendingIds;
  final bool isSyncing;
  final bool hasPending;

  bool blocks(int id) => isSyncing || pendingIds.contains(id);
}
