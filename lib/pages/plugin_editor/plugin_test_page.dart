import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/pages/plugin_editor/rule_management_widgets.dart';
import 'package:kazumi/plugins/api_rule_config.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/services/logging/logger.dart';

const _h8 = SizedBox(height: 8.0);
const _h12 = SizedBox(height: 12.0);

class PluginTestPage extends StatefulWidget {
  const PluginTestPage({
    super.key,
    required this.plugin,
  });

  final Plugin plugin;

  @override
  State<PluginTestPage> createState() => _PluginTestPageState();
}

class _PluginTestPageState extends State<PluginTestPage> {
  late final Plugin plugin;
  final testKeywordController = TextEditingController();
  final searchRawScrollController = ScrollController();
  final chapterScrollController = ScrollController();
  final fragmentScrollController = ScrollController();

  String searchRaw = "";
  String chapterRaw = "";
  PluginSearchResponse? searchRes;
  List<Road>? chapters;
  bool isTesting = false;
  bool _hasRun = false;
  int _runId = 0;
  String errorMsg = "";
  List<String> searchDiagnostics = [];
  List<String> chapterDiagnostics = [];
  final Map<int, String> _itemFragmentMap = {};
  int? _shownFragmentIndex;

  bool get _hasSearchRaw => searchRaw.isNotEmpty;

  bool get _hasSearchData => searchRes?.data.isNotEmpty ?? false;

  bool get _hasChapters => chapters?.isNotEmpty ?? false;

  bool get _needChapterParse =>
      plugin.chapterMode == RuleMode.api || plugin.chapterRoads.isNotEmpty;

  CancelToken? _testCancelToken;

  @override
  void initState() {
    super.initState();
    plugin = widget.plugin;
    testKeywordController.addListener(
        () => errorMsg.isNotEmpty ? setState(() => errorMsg = "") : null);
  }

  @override
  void dispose() {
    _testCancelToken?.cancel();
    testKeywordController.dispose();
    searchRawScrollController.dispose();
    chapterScrollController.dispose();
    fragmentScrollController.dispose();
    super.dispose();
  }

  void _resetState() => setState(() {
        _runId++;
        isTesting = false;
        _hasRun = false;
        _testCancelToken?.cancel();
        _testCancelToken = null;
        searchRaw = "";
        chapterRaw = "";
        searchRes = null;
        chapters = null;
        errorMsg = "";
        searchDiagnostics = [];
        chapterDiagnostics = [];
        _itemFragmentMap.clear();
        _shownFragmentIndex = null;
      });

  void _toggleFragment(int index) => setState(
      () => _shownFragmentIndex = _shownFragmentIndex == index ? null : index);

  Future<void> _startTest() async {
    if (isTesting) return;
    final keyword = testKeywordController.text.trim();
    if (keyword.isEmpty) {
      setState(() => errorMsg = '请输入一个番剧名称作为测试关键词。');
      return;
    }
    _resetState();
    // Ignore late responses when cancellation is not honored.
    final runId = _runId;
    final cancelToken = _testCancelToken = CancelToken();
    setState(() {
      isTesting = true;
      _hasRun = true;
    });
    try {
      final searchTrace =
          await plugin.traceSearch(keyword, cancelToken: cancelToken);
      if (!mounted || runId != _runId) return;
      setState(() {
        searchRaw = searchTrace.rawResponse;
        searchRes = searchTrace.response;
        searchDiagnostics = searchTrace.diagnostics;
        _itemFragmentMap.addAll(searchTrace.matchedFragments.asMap());
      });
      if (_hasSearchData && _needChapterParse) {
        final firstItem = searchRes!.data.first;
        if (firstItem.src.isNotEmpty) {
          final chapterTrace = await plugin.traceChapters(firstItem.src,
              cancelToken: cancelToken);
          if (!mounted || runId != _runId) return;
          setState(() {
            chapterRaw = chapterTrace.rawResponse;
            chapters = chapterTrace.roads;
            chapterDiagnostics = chapterTrace.diagnostics;
          });
        }
      }
    } catch (error, stack) {
      if (!mounted || runId != _runId) return;
      KazumiLogger()
          .e('PluginTest: test failed', error: error, stackTrace: stack);
      setState(() => errorMsg = error.toString());
    } finally {
      if (mounted && runId == _runId) setState(() => isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsDetailScaffold(
      title: const Text('规则测试'),
      actions: [
        IconButton(
          onPressed: _resetState,
          icon: const Icon(Icons.restart_alt_rounded),
          tooltip: '重置测试',
        ),
        const SizedBox(width: 8),
      ],
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RulePageIntro(
                    title: plugin.name,
                    description: '一次测试，检查搜索请求、结果解析和播放线路。',
                    icon: Icons.science_outlined,
                  ),
                  const SizedBox(height: 20),
                  RuleSection(
                    title: '试着搜索一部番剧',
                    description: '选集测试会使用第一条搜索结果。',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildKeywordInput(),
                        const SizedBox(height: 16),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(132, 48)),
                            onPressed: isTesting ? _resetState : _startTest,
                            icon: Icon(isTesting
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded),
                            label: Text(isTesting ? '停止测试' : '开始测试'),
                          ),
                        ),
                        if (isTesting) ...[
                          const SizedBox(height: 16),
                          const LinearProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                  if (errorMsg.isNotEmpty && !isTesting) ...[
                    const SizedBox(height: 16),
                    _buildErrorWidget(theme),
                  ],
                  const SizedBox(height: 20),
                  _buildExpansionTile(
                      theme: theme,
                      number: 1,
                      title: '搜索请求',
                      subtitle: _getSearchSubtitle(),
                      completed: _hasSearchRaw,
                      expanded: false,
                      child: _buildSearchContent(theme)),
                  _h12,
                  _buildExpansionTile(
                      theme: theme,
                      number: 2,
                      title: '结果解析',
                      subtitle: _getParseSubtitle(),
                      completed: _hasSearchData,
                      expanded: _hasSearchData,
                      child: _buildParseContent(theme)),
                  _h12,
                  _buildExpansionTile(
                      theme: theme,
                      number: 3,
                      title: '播放线路',
                      subtitle: _getChapterSubtitle(),
                      completed: _hasChapters,
                      expanded: _hasChapters,
                      child: _buildChapterContent(theme)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpansionTile({
    required ThemeData theme,
    required int number,
    required String title,
    required String subtitle,
    required bool completed,
    required bool expanded,
    required Widget child,
  }) {
    final colors = theme.colorScheme;
    final failed = _hasRun &&
        !isTesting &&
        !completed &&
        switch (number) {
          1 => true,
          2 => _hasSearchRaw,
          _ => _hasSearchData && _needChapterParse,
        };
    final foreground = completed
        ? colors.onTertiaryContainer
        : failed
            ? colors.onErrorContainer
            : colors.onSurfaceVariant;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('$number-$_hasRun-$completed'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: completed
                  ? colors.tertiaryContainer
                  : failed
                      ? colors.errorContainer
                      : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(completed ? 20 : 12)),
          child: Center(
              child: completed
                  ? Icon(Icons.check_rounded, color: foreground)
                  : failed
                      ? Icon(Icons.error_outline_rounded, color: foreground)
                      : Text('$number',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: foreground))),
        ),
        title: Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant)),
        initiallyExpanded: expanded,
        shape: const Border(),
        collapsedShape: const Border(),
        children: [child],
      ),
    );
  }

  Widget _buildKeywordInput() => TextField(
        controller: testKeywordController,
        decoration: ruleInputDecoration(context,
            label: '测试关键词',
            hint: '输入番剧名称',
            prefix: const Icon(Icons.search_rounded)),
        enabled: !isTesting,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _startTest(),
      );

  Widget _buildErrorWidget(ThemeData theme) => Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(errorMsg,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onErrorContainer)),
              _h8,
              TextButton(
                onPressed: _startTest,
                style: TextButton.styleFrom(
                    backgroundColor:
                        theme.colorScheme.error.withValues(alpha: 0.1)),
                child: Text('重试测试',
                    style:
                        TextStyle(color: theme.colorScheme.onErrorContainer)),
              ),
            ]),
          ),
        ]),
      );

  Widget _buildLoading(ThemeData theme) => Center(
        child: LoadingIndicator(
          color: theme.colorScheme.primary,
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
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );

  String _getSearchSubtitle() {
    if (isTesting && !_hasSearchRaw) return '正在请求站点…';
    if (!_hasSearchRaw) return _hasRun ? '没有收到响应' : '等待开始';
    return '${plugin.searchMode == RuleMode.api ? 'JSON' : 'HTML'}长度：${searchRaw.length} 字符';
  }

  Widget _codePanel(String raw, ThemeData theme,
      {ScrollController? controller}) {
    return Container(
      decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 4, top: 4),
            child: Row(children: [
              Expanded(child: Text('响应内容', style: theme.textTheme.labelLarge)),
              IconButton(
                  tooltip: '复制响应内容',
                  onPressed: () async {
                    try {
                      await Clipboard.setData(ClipboardData(text: raw));
                      if (mounted) {
                        KazumiDialog.showToast(
                            context: context, message: '已复制响应内容');
                      }
                    } catch (_) {
                      if (mounted) {
                        KazumiDialog.showToast(
                            context: context, message: '复制失败，请重试');
                      }
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18)),
            ]),
          ),
          SizedBox(
            height: 220,
            child: Scrollbar(
              controller: controller,
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: SelectableText(raw,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontFamily: 'monospace')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchContent(ThemeData theme) {
    if (isTesting && !_hasSearchRaw) return _buildLoading(theme);
    if (!_hasSearchRaw) return _buildEmpty('输入关键词后，点击「开始测试」。', theme);
    return _codePanel(
        _formattedRaw(searchRaw, isJson: plugin.searchMode == RuleMode.api),
        theme,
        controller: searchRawScrollController);
  }

  String _getParseSubtitle() {
    if (isTesting && !_hasSearchRaw) return '等待搜索响应';
    if (!_hasSearchRaw) return _hasRun ? '等待有效响应' : '等待开始';
    if (!_hasSearchData) return '未解析到结果';
    final skipped =
        searchDiagnostics.isEmpty ? '' : '，跳过 ${searchDiagnostics.length} 条';
    return '解析到 ${searchRes?.data.length ?? 0} 条结果$skipped';
  }

  Widget _buildParseContent(ThemeData theme) {
    if (isTesting && !_hasSearchRaw) return _buildLoading(theme);
    if (!_hasSearchRaw) return _buildEmpty('请先完成搜索请求测试', theme);
    if (!_hasSearchData) return _buildEmpty('未解析到搜索结果', theme, isError: true);

    return Column(children: [
      _buildDiagnosticsWidget(searchDiagnostics, theme),
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

  Widget _buildDiagnosticsWidget(List<String> diagnostics, ThemeData theme) {
    if (diagnostics.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.warning_amber_outlined,
                color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 8.0),
            Expanded(
                child: Text('部分节点被跳过（${diagnostics.length}）',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500))),
          ]),
          _h8,
          ...diagnostics.map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: SelectableText(message,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onErrorContainer)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchItemCard(SearchItem item, int i, ThemeData theme) {
    final isShowingFragment = _shownFragmentIndex == i;
    final fragment = _itemFragmentMap[i] ?? '无匹配片段';

    return Column(children: [
      Card(
        margin: const EdgeInsets.only(bottom: 8.0),
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                onPressed: isTesting ? null : () => _toggleFragment(i),
                icon: Icon(
                  isShowingFragment ? Icons.keyboard_arrow_up : Icons.code,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                tooltip: isShowingFragment ? '隐藏匹配片段' : '查看匹配片段',
              ),
            ]),
            _h8,
            Text('链接：${item.src}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
      if (isShowingFragment)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child:
              _codePanel(fragment, theme, controller: fragmentScrollController),
        ),
    ]);
  }

  String _getChapterSubtitle() {
    if (!_hasRun) return '等待开始';
    if (isTesting) return _hasSearchData ? '正在获取播放线路…' : '等待搜索结果';
    if (!_hasSearchData) return '等待有效搜索结果';
    if (!_needChapterParse) return '无需解析章节';
    if (chapters == null) return '未获取章节数据';
    final skipped =
        chapterDiagnostics.isEmpty ? '' : '，跳过 ${chapterDiagnostics.length} 条';
    return '获取到 ${chapters?.length ?? 0} 个播放线路$skipped';
  }

  Widget _buildChapterContent(ThemeData theme) {
    if (!_needChapterParse) return _buildEmpty('未填写章节规则', theme);
    if (isTesting) return _buildLoading(theme);
    if (!_hasSearchData) return _buildEmpty('请先解析到有效结果', theme);
    if (chapters == null) return _buildEmpty('未获取章节数据', theme, isError: true);
    if (!_hasChapters) return _buildEmpty('无可用章节', theme, isError: true);

    return Column(
      children: [
        _buildDiagnosticsWidget(chapterDiagnostics, theme),
        if (chapterRaw.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _codePanel(
                _formattedRaw(chapterRaw,
                    isJson: plugin.chapterMode == RuleMode.api),
                theme),
          ),
        Container(
          padding: const EdgeInsets.all(8.0),
          height: 280,
          child: ListView.builder(
            controller: chapterScrollController,
            itemCount: chapters?.length ?? 0,
            itemBuilder: (_, i) => _buildChapterCard(chapters![i], i, theme),
          ),
        ),
      ],
    );
  }

  String _formattedRaw(String raw, {required bool isJson}) {
    if (!isJson) return raw;
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }

  Widget _buildChapterCard(Road road, int i, ThemeData theme) => Card(
        margin: const EdgeInsets.only(bottom: 8.0),
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '播放线路 ${i + 1}：${road.name}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                _h8,
                Text('章节数量：${road.data.length}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                _h8,
                SizedBox(
                  width: double.infinity,
                  height: 120,
                  child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...road.identifier.asMap().entries.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: SelectableText(
                                    '${e.key + 1}. ${e.value}\n'
                                    '${e.key < road.data.length ? road.data[e.key] : ''}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ),
                        ]),
                  ),
                ),
              ]),
        ),
      );
}
