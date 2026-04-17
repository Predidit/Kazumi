/// 同步模式枚举
/// 
/// 用于标识bgm首次同步的模式
enum InitialSyncMode {
  oneWayExists(0, '一方拥有就同步'),

  bangumiPriority(1, 'bangumi优先'),

  localPriority(2, '本地优先'),
  
  bothRequired(3, '双方都必须有才同步');

  const InitialSyncMode(this.value, this.label);
  final int value;
  final String label;

  static InitialSyncMode fromInt(int value) {
    return values.firstWhere((element) => element.value == value);
  }
}