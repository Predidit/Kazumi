// 记录规则有效性状态
// 目前仅追踪搜索有效性：在本次启动后，规则是否成功返回过搜索结果
class PluginValidityTracker {
  // 记录搜索有效的规则集合
  final Set<String> _searchValidPlugins = {};

  // 标记规则搜索有效（成功返回过搜索结果）
  void markSearchValid(String pluginName) {
    _searchValidPlugins.add(pluginName);
  }

  // 检查规则搜索是否有效（是否成功返回过搜索结果）
  bool isSearchValid(String pluginName) {
    return _searchValidPlugins.contains(pluginName);
  }
}
