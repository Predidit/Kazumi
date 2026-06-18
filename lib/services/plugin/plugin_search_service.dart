import 'dart:async';
import 'dart:convert';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';

class PluginSearchService {
  PluginSearchService({required this.infoController});

  final InfoController infoController;
  final PluginsController pluginsController = Modular.get<PluginsController>();
  StreamController<PluginSearchResponse>? _controller;
  bool _isCancelled = false;

  String _cacheKey(String pluginName) {
    return 'sourceSearchCache:${infoController.bangumiItem.id}:$pluginName';
  }

  PluginSearchResponse? _getCachedResponse(String pluginName) {
    final jsonString = GStorage.getStringSettingByName(_cacheKey(pluginName));
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString);
      if (json is! Map) return null;
      if (json['bangumiId'] != infoController.bangumiItem.id ||
          json['pluginName'] != pluginName) {
        return null;
      }

      final responseJson = json['response'];
      if (responseJson is! Map) return null;

      final response = PluginSearchResponse.fromJson(
        Map<String, dynamic>.from(responseJson),
      );
      if (response.data.isEmpty) return null;
      return response;
    } catch (e) {
      KazumiLogger().w(
        'PluginSearchService: failed to read source cache',
        error: e,
      );
      return null;
    }
  }

  Future<void> _saveCachedResponse(PluginSearchResponse response) async {
    if (response.data.isEmpty) return;

    try {
      final json = {
        'bangumiId': infoController.bangumiItem.id,
        'pluginName': response.pluginName,
        'response': response.toJson(),
      };
      await GStorage.putStringSettingByName(
        _cacheKey(response.pluginName),
        jsonEncode(json),
      );
    } catch (e) {
      KazumiLogger().w(
        'PluginSearchService: failed to save source cache',
        error: e,
      );
    }
  }

  Future<void> _clearCachedResponse(String pluginName) async {
    try {
      await GStorage.deleteSettingByName(_cacheKey(pluginName));
    } catch (e) {
      KazumiLogger().w(
        'PluginSearchService: failed to clear source cache',
        error: e,
      );
    }
  }

  void _removeResponse(String pluginName) {
    for (PluginSearchResponse pluginSearchResponse
        in infoController.pluginSearchResponseList) {
      if (pluginSearchResponse.pluginName == pluginName) {
        infoController.pluginSearchResponseList.remove(pluginSearchResponse);
        break;
      }
    }
  }

  Future<void> querySource(
    String keyword,
    String pluginName, {
    bool research = false,
  }) async {
    _removeResponse(pluginName);

    if (research) {
      await _clearCachedResponse(pluginName);
    } else {
      final cachedResponse = _getCachedResponse(pluginName);
      if (cachedResponse != null) {
        infoController.pluginSearchStatus[pluginName] = 'success';
        infoController.pluginSearchResponseList.add(cachedResponse);
        return;
      }
    }

    if (infoController.pluginSearchStatus.containsKey(pluginName)) {
      infoController.pluginSearchStatus[pluginName] = 'pending';
    }
    for (Plugin plugin in pluginsController.pluginList) {
      if (plugin.name == pluginName) {
        plugin.queryBangumi(keyword, shouldRethrow: true).then((result) async {
          if (_isCancelled) {
            return;
          }

          infoController.pluginSearchStatus[plugin.name] = 'success';
          if (result.data.isNotEmpty) {
            pluginsController.validityTracker.markSearchValid(plugin.name);
            await _saveCachedResponse(result);
          }
          if (_isCancelled) {
            return;
          }
          infoController.pluginSearchResponseList.add(result);
        }).catchError((error) {
          if (_isCancelled) {
            return;
          }

          if (error is CaptchaRequiredException) {
            KazumiLogger().w(
              'PluginSearchService: captcha required for ${error.pluginName}',
            );
            infoController.pluginSearchStatus[error.pluginName] = 'captcha';
          } else if (error is NoResultException) {
            KazumiLogger().i(
              'PluginSearchService: no results for ${error.pluginName}',
            );
            infoController.pluginSearchStatus[error.pluginName] = 'noResult';
          } else {
            final name =
                error is SearchErrorException ? error.pluginName : plugin.name;
            KazumiLogger().w('PluginSearchService: search error for $name');
            infoController.pluginSearchStatus[name] = 'error';
          }
        });
      }
    }
  }

  Future<void> queryAllSource(String keyword) async {
    _controller = StreamController<PluginSearchResponse>();
    infoController.pluginSearchResponseList.clear();

    for (Plugin plugin in pluginsController.pluginList) {
      infoController.pluginSearchStatus[plugin.name] = 'pending';
    }

    int pendingRequestCount = 0;

    for (Plugin plugin in pluginsController.pluginList) {
      if (_isCancelled) return;

      final cachedResponse = _getCachedResponse(plugin.name);
      if (cachedResponse != null) {
        infoController.pluginSearchStatus[plugin.name] = 'success';
        infoController.pluginSearchResponseList.add(cachedResponse);
        continue;
      }

      pendingRequestCount++;
      plugin.queryBangumi(keyword, shouldRethrow: true).then((result) async {
        if (_isCancelled) {
          return;
        }

        infoController.pluginSearchStatus[plugin.name] = 'success';
        if (result.data.isNotEmpty) {
          pluginsController.validityTracker.markSearchValid(plugin.name);
          await _saveCachedResponse(result);
        }
        if (_isCancelled || _controller == null || _controller!.isClosed) {
          return;
        }
        _controller!.add(result);
      }).catchError((error) {
        if (_isCancelled) {
          return;
        }

        if (error is CaptchaRequiredException) {
          KazumiLogger().w(
            'PluginSearchService: captcha required for ${error.pluginName}',
          );
          infoController.pluginSearchStatus[error.pluginName] = 'captcha';
        } else if (error is NoResultException) {
          KazumiLogger().i(
            'PluginSearchService: no results for ${error.pluginName}',
          );
          infoController.pluginSearchStatus[error.pluginName] = 'noResult';
        } else {
          final name =
              error is SearchErrorException ? error.pluginName : plugin.name;
          KazumiLogger().w('PluginSearchService: search error for $name');
          infoController.pluginSearchStatus[name] = 'error';
        }
      }).whenComplete(() {
        pendingRequestCount--;
        if (pendingRequestCount == 0 &&
            _controller != null &&
            !_controller!.isClosed) {
          _controller!.close();
        }
      });
    }

    if (pendingRequestCount == 0 &&
        _controller != null &&
        !_controller!.isClosed) {
      _controller!.close();
    }

    await for (var result in _controller!.stream) {
      if (_isCancelled) break;

      infoController.pluginSearchResponseList.add(result);
    }
  }

  void cancel() {
    _isCancelled = true;
    if (_controller != null && !_controller!.isClosed) {
      _controller!.close();
    }
  }
}
