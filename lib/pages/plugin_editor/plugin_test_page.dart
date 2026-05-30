import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' show parse;
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

import '../../modules/roads/road_module.dart';
import '../../plugins/plugins.dart';

const _h8 = SizedBox(height: 8.0);
const _h12 = SizedBox(height: 12.0);

// 简化配色映射：仅三类核心色
enum CoreColorType { error, success, waiting }

extension CoreColorExtension on ThemeData {
  Color getCoreColor(CoreColorType type) {
    switch (type) {
      case CoreColorType.error:
        return colorScheme.error;
      case CoreColorType.success:
        return colorScheme.primary;
      case CoreColorType.waiting:
        return colorScheme.onSurfaceVariant;
    }
  }
}

class PluginTestPage extends StatefulWidget {
  const PluginTestPage({super.key});

  @override
  State<PluginTestPage> createState() => _PluginTestPageState();
}

class _PluginTestPageState extends State<PluginTestPage> {
  late final Plugin plugin;
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final testKeywordController = TextEditingController();
  final htmlScrollController = ScrollController();
  final chapterScrollController = ScrollController();
  final itemHtmlScrollController = ScrollController();

  String searchHtml = "";
  PluginSearchResponse? searchRes;
  List<Road>? chapters;
  bool isTesting = false;
  String errorMsg = "";
  final Map<int, String> _itemHtmlMap = {};
  int? _showItemHtmlIdx;

  bool get _hasSearchHtml => searchHtml.isNotEmpty;

  bool get _hasSearchData => searchRes?.data.isNotEmpty ?? false;

  bool get _hasChapters => chapters?.isNotEmpty ?? false;

  bool get _needChapterParse => plugin.chapterRoads.isNotEmpty;

  CancelToken? _testSearchRequestCancelToken;
  CancelToken? _testRoadsCancelToken;

  @override
  void initState() {
    super.initState();
    plugin = Modular.args.data as Plugin;
    testKeywordController.addListener(
        () => errorMsg.isNotEmpty ? setState(() => errorMsg = "") : null);
  }

  @override
  void dispose() {
    _testSearchRequestCancelToken?.cancel();
    _testRoadsCancelToken?.cancel();
    testKeywordController.dispose();
    htmlScrollController.dispose();
    chapterScrollController.dispose();
    itemHtmlScrollController.dispose();
    super.dispose();
  }

  void onBackPressed() =>
      KazumiDialog.observer.hasKazumiDialog ? KazumiDialog.dismiss() : null;

  void resetState() => setState(() {
        _testSearchRequestCancelToken?.cancel();
        _testSearchRequestCancelToken = null;
        _testRoadsCancelToken?.cancel();
        _testRoadsCancelToken = null;
        searchHtml = "";
        searchRes = null;
        chapters = null;
        errorMsg = "";
        _itemHtmlMap.clear();
        _showItemHtmlIdx = null;
      });

  String _parseItemHtml(int index) {
    if (_itemHtmlMap.containsKey(index)) return _itemHtmlMap[index]!;
    try {
      final node = (parse(searchHtml)
          .documentElement!
          .queryXPath(plugin.searchList)
          .nodes[index]
          .node as Element);
      return _itemHtmlMap[index] = node.outerHtml;
    } catch (e) {
      KazumiLogger()
          .e('PluginTest: failed to parse HTML item ${index + 1}', error: e);
      return "Parse failed: $e";
    }
  }

  void _toggleItemHtml(int index) {
    if (_showItemHtmlIdx == index)
      return setState(() => _showItemHtmlIdx = null);
    setState(() => isTesting = true);
    _parseItemHtml(index);
    setState(() {
      _showItemHtmlIdx = index;
      isTesting = false;
    });
  }

  Future<void> startTest() async {
    final keyword = testKeywordController.text.trim();
    resetState();
    setState(() => isTesting = true);
    try {
      _testSearchRequestCancelToken?.cancel();
      _testSearchRequestCancelToken = CancelToken();
      searchHtml = await plugin.testSearchRequest(keyword,
          shouldRethrow: true, cancelToken: _testSearchRequestCancelToken);
      searchRes = plugin.testQueryBangumi(searchHtml);
      if (_hasSearchData && _needChapterParse) {
        final firstItem = searchRes!.data.first;
        if (firstItem.src.isNotEmpty) {
          _testRoadsCancelToken?.cancel();
          _testRoadsCancelToken = CancelToken();
          chapters = await plugin.querychapterRoads(firstItem.src,
              cancelToken: _testRoadsCancelToken);
        }
      }
    } catch (e, stack) {
      KazumiLogger().e("PluginTest: test failed", error: e, stackTrace: stack);
    } finally {
      if (mounted) setState(() => isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) => !didPop ? onBackPressed() : null,
      child: Scaffold(
        appBar: SysAppBar(
          title: Text('${plugin.name} test'),
          actions: [
            IconButton(
              onPressed: isTesting ? null : startTest,
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: 'Start test',
            ),
            IconButton(
              onPressed: resetState,
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKeywordInput(theme),
                    _h12,
                    _buildErrorWidget(theme),
                    _buildExpansionTile(
                      theme: theme,
                      title: '1. Search request test',
                      subtitle: _getSearchSubtitle(),
                      expanded: false,
                      child: _buildSearchContent(theme),
                    ),
                    _h12,
                    _buildExpansionTile(
                      theme: theme,
                      title: '2. Search parse test',
                      subtitle: _getParseSubtitle(),
                      expanded: false,
                      child: _buildParseContent(theme),
                    ),
                    _h12,
                    _buildExpansionTile(
                      theme: theme,
                      title: '3. Chapter list test',
                      subtitle: _getChapterSubtitle(),
                      expanded: _hasSearchData,
                      child: _buildChapterContent(theme),
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpansionTile({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required bool expanded,
    required Widget child,
  }) {
    return ExpansionTile(
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontSize: 12.0, color: _getSubtitleColor(subtitle, theme))),
      initiallyExpanded: expanded,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      iconColor: theme.getCoreColor(CoreColorType.success),
      collapsedIconColor: theme.getCoreColor(CoreColorType.waiting),
      children: [_h8, child, _h8],
    );
  }

  Widget _buildKeywordInput(ThemeData theme) => TextField(
        controller: testKeywordController,
        decoration: InputDecoration(
          labelText: 'Test keyword',
          border: OutlineInputBorder(
              borderSide:
                  BorderSide(color: theme.getCoreColor(CoreColorType.waiting))),
          focusedBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: theme.getCoreColor(CoreColorType.success))),
          labelStyle:
              TextStyle(color: theme.getCoreColor(CoreColorType.waiting)),
        ),
        enabled: !isTesting,
        onSubmitted: (_) => startTest(),
        style: theme.textTheme.bodyLarge,
      );

  Widget _buildErrorWidget(ThemeData theme) => errorMsg.isEmpty || isTesting
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            border: Border.all(color: theme.getCoreColor(CoreColorType.error)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.error_outline,
                color: theme.getCoreColor(CoreColorType.error), size: 20),
            _h8,
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(errorMsg,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer)),
                    _h8,
                    TextButton(
                      onPressed: startTest,
                      style: TextButton.styleFrom(
                          backgroundColor: theme
                              .getCoreColor(CoreColorType.error)
                              .withValues(alpha: 0.1)),
                      child: Text('Retry test',
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer)),
                    ),
                  ]),
            ),
          ]),
        );

  Widget _buildLoading(ThemeData theme) => Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(
              theme.getCoreColor(CoreColorType.success)),
        ),
      );

  Widget _buildEmpty(String text, ThemeData theme, {bool isError = false}) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isError
                  ? theme.getCoreColor(CoreColorType.error)
                  : theme.getCoreColor(CoreColorType.waiting),
            ),
          ),
        ),
      );

  String _getSearchSubtitle() {
    if (isTesting) return 'Testing...';
    if (!_hasSearchHtml) return 'Test not run';
    return 'HTML length: ${searchHtml.length} chars';
  }

  // 简化副标题颜色逻辑：仅三类
  Color _getSubtitleColor(String subtitle, ThemeData theme) {
    if (subtitle.contains('Testing') ||
        subtitle.contains('Loading') ||
        subtitle.contains('Parsing')) {
      return theme.getCoreColor(CoreColorType.waiting);
    }
    if (subtitle.contains('failed') ||
        subtitle.contains('No available') ||
        subtitle.contains('No valid')) {
      return theme.getCoreColor(CoreColorType.error);
    }
    return theme.getCoreColor(CoreColorType.success);
  }

  Widget _buildSearchContent(ThemeData theme) {
    if (isTesting) return _buildLoading(theme);
    if (!_hasSearchHtml) return _buildEmpty('Tap the “Start test” button at the top to run', theme);
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.getCoreColor(CoreColorType.waiting)),
        color: theme.colorScheme.surface,
      ),
      height: 250,
      child: SingleChildScrollView(
        controller: htmlScrollController,
        physics: const ClampingScrollPhysics(),
        child: SelectableText(
          searchHtml,
          style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
      ),
    );
  }

  String _getParseSubtitle() {
    if (isTesting && _showItemHtmlIdx == null) return 'Parsing...';
    if (!_hasSearchHtml) return 'Parsing not run';
    if (!_hasSearchData) return 'No results parsed';
    return 'Parsed ${searchRes?.data.length ?? 0} results';
  }

  Widget _buildParseContent(ThemeData theme) {
    if (isTesting && _showItemHtmlIdx == null) return _buildLoading(theme);
    if (!_hasSearchHtml) return _buildEmpty('Please complete the search request test first', theme);
    if (!_hasSearchData) return _buildEmpty('No valid search results', theme, isError: true);

    return Column(children: [
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: searchRes!.data.length,
        itemBuilder: (_, i) =>
            _buildSearchItemCard(searchRes!.data[i], i, theme),
      ),
      _h8,
    ]);
  }

  Widget _buildSearchItemCard(SearchItem item, int i, ThemeData theme) {
    final isShowHtml = _showItemHtmlIdx == i;
    final itemHtml = _itemHtmlMap[i] ?? 'Loading...';

    return Column(children: [
      Card(
        margin: const EdgeInsets.only(bottom: 8.0),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Text(
                  '${i + 1}：${item.name}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: isTesting ? null : () => _toggleItemHtml(i),
                icon: Icon(
                  isShowHtml ? Icons.keyboard_arrow_up : Icons.code,
                  size: 18,
                  color: theme.getCoreColor(CoreColorType.success),
                ),
                tooltip: isShowHtml ? 'Hide HTML' : 'View HTML',
              ),
            ]),
            _h8,
            Text('Link: ${item.src}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.getCoreColor(CoreColorType.waiting))),
          ]),
        ),
      ),
      if (isShowHtml)
        Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: theme.getCoreColor(CoreColorType.waiting)),
            color: theme.colorScheme.surface,
          ),
          height: 250,
          child: SingleChildScrollView(
            controller: itemHtmlScrollController,
            physics: const ClampingScrollPhysics(),
            child: SelectableText(
              itemHtml,
              style:
                  theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ),
    ]);
  }

  String _getChapterSubtitle() {
    if (isTesting) return 'Loading...';
    if (!_hasSearchData) return 'No valid search results';
    if (!_needChapterParse) return 'No chapter parsing needed';
    if (chapters == null) return 'No chapter data retrieved';
    return 'Retrieved ${chapters?.length ?? 0} playlists';
  }

  Widget _buildChapterContent(ThemeData theme) {
    if (!_needChapterParse) return _buildEmpty('No chapter rule provided', theme);
    if (isTesting) return _buildLoading(theme);
    if (!_hasSearchData) return _buildEmpty('Please parse a valid result first', theme);
    if (chapters == null) return _buildEmpty('No chapter data retrieved', theme, isError: true);
    if (!_hasChapters) return _buildEmpty('No available chapters', theme, isError: true);

    return Container(
      padding: const EdgeInsets.all(8.0),
      height: 280,
      child: ListView.builder(
        controller: chapterScrollController,
        itemCount: chapters?.length ?? 0,
        itemBuilder: (_, i) => _buildChapterCard(chapters![i], i, theme),
      ),
    );
  }

  Widget _buildChapterCard(Road road, int i, ThemeData theme) => Card(
        margin: const EdgeInsets.only(bottom: 8.0),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Playlist ${i + 1}: ${road.name}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                _h8,
                Text('Chapter count: ${road.data.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.getCoreColor(CoreColorType.waiting))),
                _h8,
                SizedBox(
                  width: double.infinity,
                  height: 120,
                  child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...road.identifier.asMap().entries.map((e) => Text(
                                '${e.key + 1}. ${e.value}',
                                style: theme.textTheme.bodySmall,
                              )),
                        ]),
                  ),
                ),
              ]),
        ),
      );
}
