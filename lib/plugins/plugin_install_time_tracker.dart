// 记录规则安装时间
// 使用文件修改时间作为规则的安装时间
class PluginInstallTimeTracker {
  // 记录规则安装时间的映射
  final Map<String, int> _installTimes = {};

  // 设置规则的安装时间
  void setInstallTime(String pluginName, int timestamp) {
    _installTimes[pluginName] = timestamp;
  }

  // 获取规则的安装时间，如果不存在返回0
  int getInstallTime(String pluginName) {
    return _installTimes[pluginName] ?? 0;
  }
}
