import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/info/source_sheet.dart';
import 'package:kazumi/pages/video/video_playback_args.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/plugin/plugin_search_service.dart';
import 'package:kazumi/services/plugin/rule_engine_models.dart'
    show ChapterErrorException, RuleCancelToken;

class AutoSourcePage extends StatefulWidget {
  const AutoSourcePage({super.key, required this.infoController});

  final InfoController infoController;

  @override
  State<AutoSourcePage> createState() => _AutoSourcePageState();
}

class _AutoSourceCandidate {
  const _AutoSourceCandidate({required this.plugin, required this.result});

  final Plugin plugin;
  final SearchItem result;
}

class _AutoSourcePageState extends State<AutoSourcePage> {
  final PluginsController _pluginsController = inject<PluginsController>();
  late final List<Plugin> _orderedPlugins;
  late final PluginSearchService _searchService;
  late final String _keyword;
  final RuleCancelToken _chapterCancelToken = RuleCancelToken();
  final Set<String> _attemptedCandidates = <String>{};

  bool _selectionScheduled = false;
  bool _selectionStarted = false;
  bool _failed = false;
  String _status = '正在搜索可用来源…';

  @override
  void initState() {
    super.initState();
    final item = widget.infoController.bangumiItem;
    _keyword = item.nameCn.isEmpty ? item.name : item.nameCn;
    _orderedPlugins = List<Plugin>.of(_pluginsController.pluginList);
    _searchService = PluginSearchService(
      infoController: widget.infoController,
      pluginsController: _pluginsController,
    );
    unawaited(_searchService.queryAllSource(_keyword));
  }

  @override
  void dispose() {
    _searchService.cancel();
    _chapterCancelToken.cancel();
    super.dispose();
  }

  PluginSearchResponse? _responseFor(String pluginName) {
    for (final response in widget.infoController.pluginSearchResponseList) {
      if (response.pluginName == pluginName) return response;
    }
    return null;
  }

  bool _allSearchesFinished() {
    for (final plugin in _orderedPlugins) {
      final status = widget.infoController.pluginSearchStatus[plugin.name];
      if (status == null || status == PluginSearchStatus.pending) {
        return false;
      }
      if (status == PluginSearchStatus.success &&
          _responseFor(plugin.name) == null) {
        return false;
      }
    }
    return true;
  }

  String _candidateKey(Plugin plugin, SearchItem result) =>
      '${plugin.name}\u0000${result.src}';

  List<_AutoSourceCandidate> _candidates() {
    final candidates = <_AutoSourceCandidate>[];
    for (final plugin in _orderedPlugins) {
      final status = widget.infoController.pluginSearchStatus[plugin.name];
      if (status == null || status == PluginSearchStatus.pending) break;
      if (status != PluginSearchStatus.success) continue;
      final response = _responseFor(plugin.name);
      if (response == null || response.data.isEmpty) continue;
      for (final result in response.data) {
        if (_attemptedCandidates.contains(_candidateKey(plugin, result))) {
          continue;
        }
        candidates.add(_AutoSourceCandidate(plugin: plugin, result: result));
      }
    }
    return candidates;
  }

  void _scheduleSelection() {
    if (_failed || _selectionStarted || _selectionScheduled) return;
    final candidates = _candidates();
    if (candidates.isEmpty && !_allSearchesFinished()) {
      return;
    }
    _selectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectionStarted) return;
      _selectionStarted = true;
      unawaited(_selectSource(candidates));
    });
  }

  Future<void> _selectSource(List<_AutoSourceCandidate> candidates) async {
    if (candidates.isEmpty) {
      setState(() {
        _failed = true;
        _status = '没有找到可用来源';
      });
      return;
    }

    setState(() => _status = '正在自动选择最佳站点');
    for (final candidate in candidates) {
      if (!mounted) return;
      _attemptedCandidates.add(
        _candidateKey(candidate.plugin, candidate.result),
      );
      setState(() => _status = '正在连接 ${candidate.plugin.name}…');
      try {
        final roads = await candidate.plugin.queryChapterRoads(
          candidate.result.src,
          cancelToken: _chapterCancelToken,
        );
        if (roads.isEmpty) {
          throw ChapterErrorException(candidate.plugin.name);
        }
        if (!mounted) return;
        unawaited(
          context.replace(
            '/video/',
            arguments: OnlineVideoPlaybackArgs(
              bangumiItem: widget.infoController.bangumiItem,
              plugin: candidate.plugin,
              title: candidate.result.name,
              src: candidate.result.src,
              roads: roads,
            ),
          ),
        );
        return;
      } catch (error, stackTrace) {
        KazumiLogger().w(
          'AutoSourcePage: failed to open ${candidate.plugin.name}',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    _selectionStarted = false;
    _selectionScheduled = false;
    if (!mounted) return;
    final remainingCandidates = _candidates();
    if (remainingCandidates.isNotEmpty) {
      setState(() => _status = '当前来源不可用，正在尝试其他来源…');
      _scheduleSelection();
    } else if (_allSearchesFinished()) {
      setState(() {
        _failed = true;
        _status = '没有来源可以播放这个番剧';
      });
    } else {
      setState(() => _status = '当前来源不可用，正在等待其他来源…');
    }
  }

  Future<void> _openManualSelection() async {
    if (!mounted) return;
    await showAdaptiveBottomSheet<void>(
      context: context,
      maxHeightFactor: 0.88,
      builder: (_) => SourceSheet(
        infoController: widget.infoController,
        onPlaybackSelected: (args) {
          unawaited(context.replace('/video/', arguments: args));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (context) {
      _scheduleSelection();
      return Scaffold(
        appBar: AppBar(
          title: const Text('自动选择来源'),
          leading: BackButton(onPressed: () => context.pop()),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _failed
                      ? Icons.error_outline_rounded
                      : Icons.auto_awesome_rounded,
                  size: 56,
                  color: _failed
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  '正在自动选择最佳站点',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _status,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!_failed) ...[
                  const SizedBox(height: 24),
                  const LoadingIndicator(),
                ] else ...[
                  const SizedBox(height: 24),
                  FilledButton.tonal(
                    onPressed: _openManualSelection,
                    child: const Text('手动选择来源'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
