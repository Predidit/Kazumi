import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobx/mobx.dart' show reaction, ReactionDisposer;
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/info/source_alias_dialog.dart';
import 'package:kazumi/pages/info/source_captcha_flow.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/split_list_row.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/pages/video/video_playback_args.dart';
import 'package:kazumi/services/plugin/rule_engine_models.dart'
    show RuleCancelToken;
import 'package:url_launcher/url_launcher.dart';
import 'package:kazumi/services/plugin/plugin_search_service.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/utils/device.dart';

class SourceSheet extends StatefulWidget {
  const SourceSheet({
    super.key,
    required this.infoController,
  });

  final InfoController infoController;

  @override
  State<SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends State<SourceSheet> {
  final CollectController _collectController = inject<CollectController>();
  final PluginsController _pluginsController = inject<PluginsController>();

  late final String _keyword;
  late final PluginSearchService _searchService;
  late final SourceCaptchaFlow _captchaFlow;

  String? _expandedSource;
  ReactionDisposer? _autoExpandDisposer;

  @override
  void initState() {
    super.initState();
    _keyword = widget.infoController.bangumiItem.nameCn == ''
        ? widget.infoController.bangumiItem.name
        : widget.infoController.bangumiItem.nameCn;
    _searchService = PluginSearchService(
      infoController: widget.infoController,
      pluginsController: _pluginsController,
    );
    _searchService.queryAllSource(_keyword);
    _captchaFlow = SourceCaptchaFlow(
      onVerified: _showVerifiedResult,
      onCancelled: (plugin) => _querySource(_keyword, plugin.name),
    );
    // One shot: whichever source reports results first opens, and from then on
    // the open card only moves when tapped.
    _autoExpandDisposer = reaction<String?>(
      (_) => _firstSourceWithResults(),
      (name) {
        if (name == null) return;
        setState(() => _expandedSource = name);
        _stopAutoExpand();
      },
    );
  }

  @override
  void dispose() {
    _stopAutoExpand();
    _searchService.cancel();
    _captchaFlow.dispose();
    super.dispose();
  }

  void _stopAutoExpand() {
    _autoExpandDisposer?.call();
    _autoExpandDisposer = null;
  }

  /// Callbacks can outlive the sheet — a countdown ending after it closes, a
  /// dialog dismissed behind it — and a cancelled service still clears the
  /// page's results on its way to doing nothing.
  void _querySource(String keyword, String pluginName) {
    if (!mounted) return;
    _searchService.querySource(keyword, pluginName);
  }

  void _showVerifiedResult(Plugin plugin, String pageHtml) {
    if (_searchService.applyHarvestedSearchResult(plugin.name, pageHtml)) {
      KazumiDialog.showToast(message: '验证成功');
      return;
    }
    // Counting down before re-querying keeps the retry from tripping the rate
    // limit the verification just cleared.
    KazumiDialog.showTimedSuccessDialog(
      title: '验证成功',
      message: '即将重新检索',
      onComplete: () => _querySource(_keyword, plugin.name),
    );
  }

  /// A plugin can publish more than one response: an alias search adds to what
  /// the first pass found.
  List<SearchItem> _resultsFor(String pluginName) {
    final results = <SearchItem>[];
    for (final response in widget.infoController.pluginSearchResponseList) {
      if (response.pluginName == pluginName) {
        results.addAll(response.data);
      }
    }
    return results;
  }

  String? _firstSourceWithResults() {
    for (final plugin in _pluginsController.pluginList) {
      if (_resultsFor(plugin.name).isNotEmpty) return plugin.name;
    }
    return null;
  }

  void _toggleSource(String pluginName) {
    setState(() {
      _expandedSource = _expandedSource == pluginName ? null : pluginName;
    });
    _stopAutoExpand();
  }

  void _openInBrowser(Plugin plugin) {
    final targetUrl = plugin.usesApiSearch
        ? plugin.baseUrl
        : plugin.searchURL.replaceFirst(
            '@keyword',
            Uri.encodeQueryComponent(_keyword),
          );
    launchUrl(Uri.parse(targetUrl), mode: LaunchMode.externalApplication);
  }

  Future<void> _openSearchItem(Plugin plugin, SearchItem searchItem) async {
    final cancelToken = RuleCancelToken();
    KazumiDialog.showLoading(
      msg: '获取中',
      barrierDismissible: isDesktop(),
      onDismiss: cancelToken.cancel,
    );
    try {
      final roads = await plugin.queryChapterRoads(
        searchItem.src,
        cancelToken: cancelToken,
      );
      if (roads.isEmpty) {
        throw ChapterErrorException(plugin.name);
      }
      KazumiDialog.dismiss();
      if (!mounted) return;
      context.pushNamed(
        '/video/',
        arguments: OnlineVideoPlaybackArgs(
          bangumiItem: widget.infoController.bangumiItem,
          plugin: plugin,
          title: searchItem.name,
          src: searchItem.src,
          roads: roads,
        ),
      );
    } catch (_) {
      KazumiLogger().w("PluginSearchService: failed to query video playlist");
      KazumiDialog.dismiss();
    }
  }

  /// Searching under an alias also saves it for the next visit.
  void _searchAlias(String pluginName, String alias) {
    if (!widget.infoController.bangumiItem.alias.contains(alias)) {
      widget.infoController.bangumiItem.alias.add(alias);
      _collectController.updateLocalCollect(widget.infoController.bangumiItem);
    }
    _querySource(alias, pluginName);
  }

  void _showAliasPicker(String pluginName) {
    if (widget.infoController.bangumiItem.alias.isEmpty) {
      KazumiDialog.showToast(message: '无可用别名，试试手动检索');
      return;
    }
    showAliasPickerDialog(
      aliases: widget.infoController.bangumiItem.alias,
      onAliasSelected: (alias) {
        KazumiDialog.dismiss();
        _querySource(alias, pluginName);
      },
      onAliasesChanged: () => _collectController
          .updateLocalCollect(widget.infoController.bangumiItem),
    );
  }

  void _showCustomKeyword(String pluginName) => showCustomKeywordDialog(
        onSubmit: (keyword) => _searchAlias(pluginName, keyword),
      );

  /// One source, collapsed to a row until opened. The header sits a surface
  /// step above its result rows — and shifts to `secondaryContainer` while
  /// open — so a rule never reads as one of the titles it returned.
  Widget _buildSourceCard(Plugin plugin, List<SearchItem> results, bool open) {
    final searching = widget.infoController.pluginSearchStatus[plugin.name] ==
        PluginSearchStatus.pending;
    final colorScheme = Theme.of(context).colorScheme;

    final body = <({Widget child, VoidCallback? onTap})>[];
    if (open && !searching) {
      if (results.isEmpty) {
        body.add((child: _buildActionsRow(plugin), onTap: null));
      } else {
        for (final result in results) {
          body.add((
            child: _buildResultRow(result),
            onTap: () => _openSearchItem(plugin, result),
          ));
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedSize(
        duration: splitListMotionDuration,
        curve: splitListMotionCurve,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SplitListRow(
              color: open
                  ? colorScheme.secondaryContainer
                  : colorScheme.surfaceContainer,
              topRadius: splitListOuterRadius,
              bottomRadius:
                  body.isEmpty ? splitListOuterRadius : splitListInnerRadius,
              onTap: () => _toggleSource(plugin.name),
              child: _buildSourceHeader(plugin, results, searching, open),
            ),
            for (var i = 0; i < body.length; i++) ...[
              const SizedBox(height: splitListRowGap),
              SplitListRow(
                bottomRadius: i == body.length - 1
                    ? splitListOuterRadius
                    : splitListInnerRadius,
                onTap: body[i].onTap,
                child: body[i].child,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Status rides in trailing text rather than a leading icon: rows whose
  /// siblings lack one end up with misaligned names.
  ({String text, Color? color}) _sourceSummary(
      Plugin plugin, List<SearchItem> results, bool searching) {
    if (searching) return (text: '检索中', color: null);
    if (results.isNotEmpty) return (text: '${results.length} 条', color: null);
    final error = Theme.of(context).colorScheme.error;
    return switch (widget.infoController.pluginSearchStatus[plugin.name]) {
      PluginSearchStatus.error => (text: '检索失败', color: error),
      PluginSearchStatus.captcha => (text: '需要验证', color: error),
      _ => (text: '无结果', color: null),
    };
  }

  Widget _buildSourceHeader(
      Plugin plugin, List<SearchItem> results, bool searching, bool open) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final summary = _sourceSummary(plugin, results, searching);
    final onColor = open ? colorScheme.onSecondaryContainer : null;
    // Buttons under a result list get hit by thumbs reaching for the last row,
    // so a source with results keeps its actions up here instead.
    final hasMenu = open && !searching && results.isNotEmpty;
    return Padding(
      // Both branches land on 56dp, matching a result row: the menu's
      // IconButton is 48dp on its own.
      padding: hasMenu
          ? const EdgeInsets.fromLTRB(18, 4, 14, 4)
          : const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              plugin.name,
              style: theme.textTheme.titleSmall?.copyWith(color: onColor),
            ),
          ),
          Text(
            summary.text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: summary.color ?? onColor ?? colorScheme.onSurfaceVariant,
            ),
          ),
          if (searching) ...[
            const SizedBox(width: 10),
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ] else ...[
            if (hasMenu)
              PopupMenuButton<VoidCallback>(
                tooltip: '${plugin.name} 的更多操作',
                icon: Icon(Icons.more_vert_rounded, size: 20, color: onColor),
                onSelected: (action) => action(),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: () => _showAliasPicker(plugin.name),
                    child: const Text('别名检索'),
                  ),
                  PopupMenuItem(
                    value: () => _showCustomKeyword(plugin.name),
                    child: const Text('手动检索'),
                  ),
                  PopupMenuItem(
                    value: () => _openInBrowser(plugin),
                    child: const Text('在浏览器中打开'),
                  ),
                ],
              )
            else
              const SizedBox(width: 10),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: splitListMotionDuration,
              curve: splitListMotionCurve,
              child: Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: onColor ?? colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultRow(SearchItem searchItem) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
      child: Row(
        children: [
          Expanded(
            child: Text(searchItem.name, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.play_arrow_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow(Plugin plugin) {
    final theme = Theme.of(context);
    final actions = <Widget>[];
    final String hint;
    switch (widget.infoController.pluginSearchStatus[plugin.name]) {
      case PluginSearchStatus.captcha:
        hint = '这个源要求先完成验证';
        actions.add(
            _primaryAction('进行验证', () => _captchaFlow.start(plugin, _keyword)));
        actions.add(_action('重试', () => _retry(plugin)));
      case PluginSearchStatus.error:
        hint = '这个源没能返回结果';
        actions.add(_primaryAction('重试', () => _retry(plugin)));
      default:
        hint = '换个关键词再试试';
        actions
            .add(_primaryAction('别名检索', () => _showAliasPicker(plugin.name)));
        actions.add(_action('手动检索', () => _showCustomKeyword(plugin.name)));
    }
    actions.add(_action('浏览器打开', () => _openInBrowser(plugin)));

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Wrap(spacing: 8, runSpacing: 4, children: actions),
        ],
      ),
    );
  }

  void _retry(Plugin plugin) => _querySource(_keyword, plugin.name);

  Widget _primaryAction(String label, VoidCallback onPressed) =>
      FilledButton.tonal(onPressed: onPressed, child: Text(label));

  Widget _action(String label, VoidCallback onPressed) =>
      TextButton(onPressed: onPressed, child: Text(label));

  /// Always plugin order, never ranked by what came back: a source can fill
  /// up long after the search settles — a captcha source does once verified
  /// — and ranking would slide the card someone just acted on out from
  /// under them.
  List<Widget> _buildSourceCards() {
    final cards = <Widget>[];
    for (final plugin in _pluginsController.pluginList) {
      cards.add(_buildSourceCard(
        plugin,
        _resultsFor(plugin.name),
        _expandedSource == plugin.name,
      ));
    }
    cards.add(const SafeArea(top: false, child: SizedBox(height: 12)));
    return cards;
  }

  String _progressDescription() {
    final plugins = _pluginsController.pluginList;
    final done = plugins
        .where((plugin) =>
            widget.infoController.pluginSearchStatus[plugin.name] !=
            PluginSearchStatus.pending)
        .length;
    final found = plugins.fold<int>(
        0, (sum, plugin) => sum + _resultsFor(plugin.name).length);
    if (done < plugins.length) {
      return '「$_keyword」· 检索中 $done/${plugins.length}';
    }
    return '「$_keyword」· $found 条结果';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Observer(
        builder: (context) {
          // Must be read here, not behind a nested Builder: mobx only tracks
          // reads made while the Observer's own builder runs.
          final cards = _buildSourceCards();
          return Column(
            children: [
              MaterialBottomSheetHeader(
                title: '选择播放源',
                description: _progressDescription(),
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: cards.length,
                  itemBuilder: (context, index) => cards[index],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
