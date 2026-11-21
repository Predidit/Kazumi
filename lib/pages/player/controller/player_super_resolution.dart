enum SuperResolutionMode {
  off(storageValue: 1, label: '关闭', description: '使用原始画面，不运行超分模型'),
  efficiency(storageValue: 2, label: '效率档', description: '优先降低渲染负载'),
  quality(storageValue: 3, label: '质量档', description: '保留更多细节，适合较大画面'),
  balanced(storageValue: 4, label: '均衡档', description: '兼顾画面细节与渲染负载');

  static const active = [efficiency, balanced, quality];

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
