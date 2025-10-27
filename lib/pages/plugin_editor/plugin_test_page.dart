import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' show parse;
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

import '../../modules/roads/road_module.dart';
import '../../plugins/plugins.dart';

const _h8 = SizedBox(height: 8.0);
const _h12 = SizedBox(height: 12.0);

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

  Future<String> _parseItemHtml(int index) async {
    if (_itemHtmlMap.containsKey(index)) return _itemHtmlMap[index]!;
    try {
      final node = (parse(searchHtml)
          .documentElement!
          .queryXPath(plugin.searchList)
          .nodes[index]
          .node as Element);
      return _itemHtmlMap[index] = node.outerHtml;
    } catch (e) {
      KazumiLogger().log(Level.error, "解析第 ${index + 1} 条HTML失败：$e");
      return "解析失败：$e";
    }
  }

  Future<void> _toggleItemHtml(int index) async {
    if (_showItemHtmlIdx == index)
      return setState(() => _showItemHtmlIdx = null);
    setState(() => isTesting = true);
    await _parseItemHtml(index);
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
      _testSearchRequestCancelToken = null;
      _testSearchRequestCancelToken = CancelToken();
      // 1. 搜索请求
      searchHtml = await plugin.testSearchRequest(keyword,
          shouldRethrow: true, cancelToken: _testSearchRequestCancelToken);
      // 2. 解析搜索结果
      searchRes = plugin.testQueryBangumi(searchHtml);
      // 3. 获取章节
      if (_hasSearchData && _needChapterParse) {
        final firstItem = searchRes!.data.first;
        if (firstItem.src.isNotEmpty) {
          _testRoadsCancelToken?.cancel();
          _testRoadsCancelToken = null;
          _testRoadsCancelToken = CancelToken();
          chapters = await plugin.querychapterRoads(firstItem.src,
              cancelToken: _testRoadsCancelToken);
        }
      }
    } catch (e, stack) {
      errorMsg = "测试失败：$e";
      KazumiLogger().log(Level.error, errorMsg, stackTrace: stack);
    } finally {
      if (mounted) setState(() => isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) => !didPop ? onBackPressed() : null,
      child: Scaffold(
        appBar: SysAppBar(
          title: Text('${plugin.name} 测试'),
          actions: [
            IconButton(
              onPressed: isTesting ? null : startTest,
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: '开始测试',
            ),
            IconButton(
                onPressed: resetState,
                icon: const Icon(Icons.refresh),
                tooltip: '重置'),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKeywordInput(),
                    _h12,
                    _buildErrorWidget(),
                    _buildExpansionTile(
                      title: '1. 搜索请求测试',
                      subtitle: _getSearchSubtitle(),
                      expanded: true,
                      child: _buildSearchContent(),
                    ),
                    _h12,
                    _buildExpansionTile(
                      title: '2. 搜索解析测试',
                      subtitle: _getParseSubtitle(),
                      expanded: false,
                      child: _buildParseContent(),
                    ),
                    _h12,
                    _buildExpansionTile(
                      title: '3. 章节列表测试',
                      subtitle: _getChapterSubtitle(),
                      expanded: _hasSearchData,
                      child: _buildChapterContent(),
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpansionTile({
    required String title,
    required String subtitle,
    required bool expanded,
    required Widget child,
  }) {
    return ExpansionTile(
      title: Text(title),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12.0, color: _getSubtitleColor(subtitle))),
      initiallyExpanded: expanded,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: Colors.transparent,
      children: [_h8, child, _h8],
    );
  }

  Widget _buildKeywordInput() => TextField(
        controller: testKeywordController,
        decoration: const InputDecoration(
            labelText: '测试关键词', border: OutlineInputBorder()),
        enabled: !isTesting,
        onSubmitted: (_) => startTest(),
      );

  Widget _buildErrorWidget() => errorMsg.isEmpty || isTesting
      ? const SizedBox.shrink()
      : Container(
          padding: EdgeInsets.all(12.0),
          decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red[300]!),
              borderRadius: BorderRadius.circular(8)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            _h8,
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(errorMsg,
                      style: TextStyle(color: Colors.red[800], fontSize: 14)),
                  _h8,
                  TextButton(
                      onPressed: startTest,
                      child: const Text('重试测试',
                          style: TextStyle(color: Colors.blue))),
                ])),
          ]),
        );

  Widget _buildLoading() =>
      const Center(child: CircularProgressIndicator.adaptive());

  Widget _buildEmpty(String text, {Color? color}) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(text,
              style: TextStyle(color: color ?? Colors.grey, fontSize: 14)),
        ),
      );

  String _getSearchSubtitle() {
    if (isTesting) return '测试中...';
    if (!_hasSearchHtml) return '未执行测试';
    return 'HTML长度：${searchHtml.length} 字符';
  }

  Color _getSubtitleColor(String subtitle) {
    if (subtitle.contains('测试中') || subtitle.contains('获取中'))
      return Colors.blue;
    if (subtitle.contains('未') || subtitle.contains('无需')) return Colors.grey;
    if (subtitle.contains('失败') || subtitle.contains('无可用'))
      return Colors.orange;
    return Colors.green[700]!;
  }

  Widget _buildSearchContent() {
    if (isTesting) return _buildLoading();
    if (!_hasSearchHtml) return _buildEmpty('点击顶部「开始测试」按钮执行');
    return Container(
      margin: EdgeInsets.only(bottom: 8.0),
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!)),
      height: 250,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => n.depth == 0,
        child: SingleChildScrollView(
          controller: htmlScrollController,
          physics: const ClampingScrollPhysics(),
          child: SelectableText(searchHtml,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
        ),
      ),
    );
  }

  String _getParseSubtitle() {
    if (isTesting && _showItemHtmlIdx == null) return '解析中...';
    if (!_hasSearchHtml) return '未执行解析';
    if (!_hasSearchData) return '未解析到结果';
    return '解析到 ${searchRes?.data.length ?? 0} 条结果';
  }

  Widget _buildParseContent() {
    if (isTesting && _showItemHtmlIdx == null) return _buildLoading();
    if (!_hasSearchHtml) return _buildEmpty('请先完成搜索请求测试');
    if (!_hasSearchData) return _buildEmpty('未解析到搜索结果', color: Colors.orange);

    return Column(children: [
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: searchRes!.data.length,
        itemBuilder: (_, i) => _buildSearchItemCard(searchRes!.data[i], i),
      ),
      _h8,
    ]);
  }

  Widget _buildSearchItemCard(SearchItem item, int i) {
    final isShowHtml = _showItemHtmlIdx == i;
    final itemHtml = _itemHtmlMap[i] ?? '加载中...';

    return Column(children: [
      Card(
        margin: EdgeInsets.only(bottom: 8.0),
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Text('${i + 1}：${item.name}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                onPressed: isTesting ? null : () => _toggleItemHtml(i),
                icon: Icon(isShowHtml ? Icons.keyboard_arrow_up : Icons.code,
                    size: 18, color: Colors.blue),
                tooltip: isShowHtml ? '隐藏HTML' : '查看HTML',
              ),
            ]),
            _h8,
            Text('链接：${item.src}', style: TextStyle(fontSize: 12)),
          ]),
        ),
      ),
      if (isShowHtml)
        Container(
          margin: EdgeInsets.only(bottom: 8.0),
          padding: EdgeInsets.all(8.0),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!)),
          height: 250,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) => n.depth == 0,
            child: SingleChildScrollView(
              controller: itemHtmlScrollController,
              physics: const ClampingScrollPhysics(),
              child: SelectableText(itemHtml,
                  style:
                      const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ),
          ),
        ),
    ]);
  }

  String _getChapterSubtitle() {
    if (isTesting) return '获取中...';
    if (!_hasSearchData) return '无有效搜索结果';
    if (!_needChapterParse) return '无需解析章节';
    if (chapters == null) return '未获取章节数据';
    return '获取到 ${chapters?.length ?? 0} 个播放列表';
  }

  Widget _buildChapterContent() {
    if (!_needChapterParse) return _buildEmpty('未填写章节规则');
    if (isTesting) return _buildLoading();
    if (!_hasSearchData) return _buildEmpty('请先解析到有效结果');
    if (chapters == null) return _buildEmpty('未获取章节数据', color: Colors.orange);
    if (!_hasChapters) return _buildEmpty('无可用章节', color: Colors.orange);

    return Container(
      padding: EdgeInsets.all(8.0),
      height: 280,
      child: ListView.builder(
        controller: chapterScrollController,
        itemCount: chapters?.length ?? 0,
        itemBuilder: (_, i) => _buildChapterCard(chapters![i], i),
      ),
    );
  }

  Widget _buildChapterCard(Road road, int i) => Card(
    margin: EdgeInsets.only(bottom: 8.0),
    child: Padding(
      padding: EdgeInsets.all(12.0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('播放列表 ${i + 1}：${road.name}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            _h8,
            Text('章节数量：${road.data.length}', style: TextStyle(fontSize: 12)),
            _h8,
            SizedBox(
              width: double.infinity, // 关键添加：让宽度匹配父级约束（即maxWidth:1000）
              height: 120,
              child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...road.identifier.asMap().entries.map((e) => Text(
                          '${e.key + 1}. ${e.value}',
                          style: TextStyle(fontSize: 12))),
                    ]),
              ),
            ),
          ]),
    ),
  );
}
