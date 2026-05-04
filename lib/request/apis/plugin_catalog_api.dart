import 'dart:convert';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/clients/github_client.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/modules/plugin/plugin_http_module.dart';

class PluginCatalogApi {
  static final GithubClient _client = GithubClient.instance;

  static Future<List<PluginHTTPItem>> getPluginList() async {
    List<PluginHTTPItem> pluginHTTPItemList = [];
    try {
      final raw = await _client.getText('${ApiEndpoints.pluginShop}index.json');
      final jsonData = json.decode(raw);
      for (dynamic pluginJsonItem in jsonData) {
        try {
          PluginHTTPItem pluginHTTPItem =
              PluginHTTPItem.fromJson(pluginJsonItem);
          pluginHTTPItemList.add(pluginHTTPItem);
        } catch (_) {}
      }
    } catch (e) {
      KazumiLogger().e('Plugin: getPluginList error: ${e.toString()}');
    }
    return pluginHTTPItemList;
  }

  static Future<Plugin?> getPlugin(String name) async {
    Plugin? plugin;
    try {
      final raw = await _client.getText('${ApiEndpoints.pluginShop}$name.json');
      final jsonData = json.decode(raw);
      plugin = Plugin.fromJson(jsonData);
    } catch (e) {
      KazumiLogger().e('Plugin: getPlugin error: ${e.toString()}');
    }
    return plugin;
  }
}
