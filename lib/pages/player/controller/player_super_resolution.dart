enum SuperResolutionMode {
  off(
    storageValue: 1,
    label: '关闭',
    description: '默认禁用超分辨率',
  ),
  efficiency(
    storageValue: 2,
    label: '效率档',
    description: '默认启用基于Anime4K的超分辨率 (效率优先)',
  ),
  quality(
    storageValue: 3,
    label: '质量档',
    description: '默认启用基于Anime4K的超分辨率 (质量优先)',
  );

  const SuperResolutionMode({
    required this.storageValue,
    required this.label,
    required this.description,
  });

  final int storageValue;
  final String label;
  final String description;

  static SuperResolutionMode fromStorageValue(int value) {
    return SuperResolutionMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => SuperResolutionMode.off,
    );
  }
}
