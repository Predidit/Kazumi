import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/request/query_manager.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../bean/appbar/sys_app_bar.dart';
import '../../bean/widget/error_widget.dart';
import '../../modules/search/plugin_search_module.dart';
import '../../utils/constants.dart';
import '../history/history_controller.dart';
import '../video/video_controller.dart';

class SearchYiPage extends StatefulWidget {
  const SearchYiPage({super.key});

  @override
  State<SearchYiPage> createState() => _SearchYiPageState();
}

class _SearchYiPageState extends State<SearchYiPage>
    with SingleTickerProviderStateMixin {
  final InfoController infoController = InfoController();
  late final QueryManager? queryManager =
      QueryManager(infoController: infoController);
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  late final TabController tabController;
  final HistoryController historyController = Modular.get<HistoryController>();
  final Map<String, ScrollController> scrollControllers = {};

  // 标记每个插件是否正在加载（防重复请求）
  final Map<String, bool> _isLoading = {};

// 保存每个插件的滚动监听函数（用于正确移除监听）
  final Map<String, VoidCallback> _scrollListeners = {};


  final Map<String, int> _currentPages = {};

  @override
  void initState() {
    super.initState();
    for (var plugin in pluginsController.pluginList) {
      final pluginName = plugin.name;
      _currentPages[pluginName] = 1;
      _isLoading[pluginName] = false; // 初始化为未加载

      // 1. 只创建1次 ScrollController，避免重复
      final scrollController = ScrollController();
      scrollControllers[pluginName] = scrollController;

      // 2. 保存监听函数引用（匿名函数无法正确移除）
      VoidCallback scrollListener = () => _onScroll(plugin);
      _scrollListeners[pluginName] = scrollListener;

      // 3. 绑定监听
      scrollController.addListener(scrollListener);

      // 初始化搜索状态
      if (!infoController.pluginSearchStatus.containsKey(pluginName)) {
        infoController.pluginSearchStatus[pluginName] = 'pending';
      }
    }
    print(infoController.pluginSearchResponseList.length.toString()+"infoController.pluginSearchResponseList.length");
    queryManager?.queryAllSource('');
    tabController = TabController(
      length: pluginsController.pluginList.isNotEmpty
          ? pluginsController.pluginList.length
          : 1,
      vsync: this,
    );
  }

  int _generateUniqueId(String name) =>
      (BigInt.parse(
                '0x${sha256.convert(utf8.encode(name)).bytes.sublist(0, 8).map((b) => b.toRadixString(16).padLeft(2, '0')).join('')}',
              ) %
              BigInt.from(2000000000))
          .toInt() +
      100000000;

  @override
  void dispose() {
    queryManager?.cancel();
    _searchController.dispose();
    videoPageController.currentEpisode = 1;
    _focusNode.dispose();
    tabController.dispose();

    // 4. 正确移除监听+销毁控制器（关键：用保存的监听函数引用）
    for (var entry in scrollControllers.entries) {
      final pluginName = entry.key;
      final controller = entry.value;
      final listener = _scrollListeners[pluginName];
      if (listener != null) {
        controller.removeListener(listener); // 移除正确的监听函数
      }
      controller.dispose(); // 销毁控制器
    }
    // 清空缓存，避免内存泄漏
    _scrollListeners.clear();
    scrollControllers.clear();
    _isLoading.clear();
    super.dispose();
  }

  void _onScroll(Plugin plugin) {
    final pluginName = plugin.name;
    final controller = scrollControllers[pluginName];
    final isLoading = _isLoading[pluginName] ?? false;

    // 【优先级1】提前拦截无效场景：控制器无效、正在加载、已无更多数据
    if (controller == null ||
        !controller.hasClients ||
        isLoading) {
      return;
    }

    final position = controller.position;
    // 【优先级2】判断是否快到底部（距离底部200px，适配不同屏幕）
    // 同时确保列表有滚动空间（避免列表过短时误触发）
    final isNearBottom = position.pixels >= position.maxScrollExtent - 200 &&
        position.maxScrollExtent > 0;

    // 【优先级3】判断已有数据（避免首次加载前触发）
    final hasData = infoController.pluginSearchResponseList
            .where((r) => r.pluginName == pluginName)
            .fold(0, (sum, r) => sum + r.data.length) >
        0;

    // 所有条件满足，触发加载更多
    if (isNearBottom && hasData) {
      _loadMore(plugin);
    }
  }

// 2. 优化 _loadMore 逻辑
  void _loadMore(Plugin plugin) {
    final pluginName = plugin.name;
    final currentPage = _currentPages[pluginName] ?? 1;
    final nextPage = currentPage + 1;
    int? lengthBefore;
    PluginSearchResponse? searchHistory;
    if (infoController.pluginSearchResponseList
        .any((r) => r.pluginName == pluginName)) {
      searchHistory = infoController.pluginSearchResponseList
          .firstWhere((r) => r.pluginName == pluginName);
    }
    lengthBefore = searchHistory?.data.length;

    // 标记为加载中（双重锁：_isLoading + infoController）
    _isLoading[pluginName] = true;

    // 发起加载更多请求（用修改后的 querySource，拿到结果）
    queryManager
        ?.querySource(
      _searchController.text,
      pluginName,
      page: nextPage,
      isAppend: true,
    )
        .then((result) {
      infoController.pluginSearchStatus[pluginName] = 'success';
      if (lengthBefore! < searchHistory!.data.length) {
        _currentPages[pluginName] = nextPage;
      }
    }).catchError((error) {
      KazumiLogger().log(Level.error, '$pluginName 加载更多失败: $error');
    }).whenComplete(() {
      // 无论成功/失败，都解除加载锁
      _isLoading[pluginName] = false;
      setState(() {}); // 刷新UI
    });
  }

  void _search(String keyword) {
    // 重置所有插件状态为pending
    for (var plugin in pluginsController.pluginList) {
      infoController.pluginSearchStatus[plugin.name] = 'pending';
      _currentPages[plugin.name] = 1;
    }
    queryManager?.queryAllSource(keyword);
  }

  List<Widget> _buildCardItems(Plugin plugin) {
    return infoController.pluginSearchResponseList
        .where((response) => response.pluginName == plugin.name)
        .expand((response) => response.data
            .map((searchItem) => _buildSearchCard(context, searchItem, plugin)))
        .toList();
  }

  Widget _buildCardGrid(List<Widget> cardItems, Plugin plugin) {
    final pluginName = plugin.name;
    final isLoadingMore = _isLoading[pluginName] ?? false;

    int crossCount = 1;
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth > LayoutBreakpoint.compact['width']!) crossCount = 2;
    if (screenWidth > LayoutBreakpoint.medium['width']!) crossCount = 3;

    double cardHeight = 120;

    return Scaffold(
      body: CustomScrollView(
        controller: scrollControllers[pluginName],
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              mainAxisSpacing: StyleString.cardSpace - 2,
              crossAxisSpacing: StyleString.cardSpace,
              crossAxisCount: crossCount,
              mainAxisExtent: cardHeight + 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => cardItems[index],
              childCount: cardItems.length,
            ),
          ),
          // 加载更多/无更多提示（新增）
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: () {
                  if (isLoadingMore) {
                    // 加载中：小进度条（避免与首次加载的大进度条冲突）
                    return const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  } else {
                    // 其他情况：空容器（不占位）
                    return const SizedBox.shrink();
                  }
                }(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: cardItems.length/crossCount <= 8
          ? FloatingActionButton(
              onPressed: () => _loadMore(plugin),
              child: const Icon(Icons.arrow_downward))
          : FloatingActionButton(
              onPressed: () => scrollControllers[pluginName]?.animateTo(0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut),
              child: const Icon(Icons.arrow_upward),
            ),
    );
  }

  Widget _buildSearchCard(
      BuildContext context, SearchItem searchItem, Plugin plugin) {
    final theme = Theme.of(context);
    final double borderRadius = 18;
    final double imageWidth = 120 * 0.7;

    final surfaceWithOpacity = theme.colorScheme.surface.withOpacity(
      theme.brightness == Brightness.light ? 0.9 : 0.95,
    );

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      color: surfaceWithOpacity,
      child: InkWell(
        onTap: plugin.chapterRoads.isEmpty
            ? null
            : () => _handleCardTap(context, searchItem, plugin),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildImage(context, searchItem.img, imageWidth, 120, plugin,
                searchItem.src),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      searchItem.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: plugin.chapterRoads.isEmpty
                            ? theme.disabledColor
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: searchItem.tags.isNotEmpty ? 2 : 4,
                    ),
                    const SizedBox(height: 12),
                    if (searchItem.tags.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: searchItem.tags.entries
                            .map((entry) => propertyChip(
                                  title: entry.key,
                                  value: entry.value,
                                  showTitle: true,
                                ))
                            .toList(),
                      )
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget propertyChip({
    required String title,
    required String value,
    bool showTitle = false,
  }) {
    final message = '$title: $value';
    return Chip(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      side: BorderSide.none,
      label: Text(
        showTitle ? message : value,
        style: Theme.of(context).textTheme.labelSmall,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget buildImage(BuildContext context, String imageUrl, double width,
      double height, Plugin plugin, String resultUrl) {
    final double safeWidth = width <= 0 ? 100 : width;
    final double safeHeight = height <= 0 ? 100 : height;
    final borderRadius = BorderRadius.circular(16);
    Widget content;

    if (imageUrl.isEmpty) {
      content = _buildPlaceholderWidget(safeWidth, safeHeight);
    } else {
      content = Image.network(
        imageUrl,
        fit: BoxFit.fitHeight,
        cacheHeight: (safeHeight * 2).toInt(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return Container(
            width: safeWidth,
            height: safeHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onInverseSurface
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(StyleString.imgRadius.x),
            ),
            child: Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          (loadingProgress.expectedTotalBytes ?? 1)
                      : null,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWithRetryWidget(safeWidth, safeHeight, () {
            setState(() {});
          });
        },
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: GestureDetector(
        onTap: () => _handleImageTap(plugin, resultUrl),
        child: Hero(
          tag: imageUrl.isEmpty
              ? 'search_image_placeholder_${resultUrl.hashCode}'
              : 'search_image_${imageUrl.hashCode}',
          child: content,
        ),
      ),
    );
  }

  Widget _buildPlaceholderWidget(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, color: Colors.grey, size: 24),
            Text('无图片', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      );

  Widget _buildErrorWithRetryWidget(
          double width, double height, VoidCallback onRetry) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 24),
            const SizedBox(height: 8),
            const Text('加载失败',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '重试',
                style: TextStyle(fontSize: 10, color: Colors.blue),
              ),
            ),
          ],
        ),
      );

  Future<void> _handleCardTap(
      BuildContext context, SearchItem searchItem, Plugin plugin) async {
    KazumiDialog.showLoading(msg: '获取中');
    final todayDate = DateTime.now().toString().split(' ')[0];

    videoPageController
      ..bangumiItem =
          historyController.queryBangumiItem(plugin.name, searchItem.name) ??
              BangumiItem(
                id: _generateUniqueId(searchItem.name),
                type: _generateUniqueId(searchItem.name),
                name: searchItem.name,
                nameCn: searchItem.name,
                summary:
                    "影片《${searchItem.name}》是通过规则${plugin.name}直接搜索得到。\r无法获取bangumi的数据，但支持追番、观看记录等功能。",
                airDate: todayDate,
                airWeekday: 0,
                rank: 0,
                images: Map.fromEntries([
                  'small',
                  'grid',
                  'large',
                  'medium',
                  'common'
                ].map((key) => MapEntry(key, searchItem.img))),
                tags: [],
                alias: [],
                ratingScore: 0.0,
                votes: 0,
                votesCount: [],
                info: '', keyword: '',
              )
      ..currentPlugin = plugin
      ..title = searchItem.name
      ..src = searchItem.src;

    try {
      await videoPageController.queryRoads(searchItem.src, plugin.name);
      KazumiDialog.dismiss();
      Modular.to.pushNamed('/video/');
    } catch (e) {
      KazumiLogger().log(Level.error, e.toString());
      KazumiDialog.dismiss();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取播放列表失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleImageTap(Plugin plugin, String resultUrl) {
    String url = '';
    if (resultUrl.isNotEmpty) {
      if (resultUrl.startsWith(RegExp(r'^https?://'))) {
        url = resultUrl;
      } else if (plugin.baseUrl.isNotEmpty) {
        url = plugin.baseUrl.endsWith('/') && resultUrl.startsWith('/')
            ? '${plugin.baseUrl}${resultUrl.substring(1)}'
            : !plugin.baseUrl.endsWith('/') && !resultUrl.startsWith('/')
                ? '${plugin.baseUrl}/$resultUrl'
                : '${plugin.baseUrl}$resultUrl';
      }
    }

    if (url.isNotEmpty) {
      KazumiDialog.show(
          builder: (context) => AlertDialog(
                title: const Text('打开链接'),
                content: Text('是否在浏览器中打开：\n$url'),
                actions: [
                  TextButton(
                    onPressed: () => KazumiDialog.dismiss(),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () async {
                      KazumiDialog.dismiss();
                      try {
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url),
                              mode: LaunchMode.externalApplication);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('无法打开链接：$url')),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('打开链接失败：${e.toString()}')),
                          );
                        }
                      }
                    },
                    child: const Text('确认'),
                  ),
                ],
              ));
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无效的链接地址')),
      );
    }
  }

  Widget buildPagination(Plugin plugin) {
    final currentPage = _currentPages[plugin.name] ?? 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 35, minHeight: 35),
            style: IconButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: currentPage > 1
                ? () => _changePage(plugin, currentPage - 1)
                : null,
            icon: const Icon(Icons.arrow_back),
            color: Theme.of(context).primaryColor,
            disabledColor: Colors.grey[400],
          ),
          SizedBox(
            width: 56,
            child: TextField(
              controller: TextEditingController(text: currentPage.toString()),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 1.0,
                  ),
                ),
              ),
              onSubmitted: (value) =>
                  _changePage(plugin, int.tryParse(value) ?? 1),
            ),
          ),
          IconButton(
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 35, minHeight: 35),
            style: IconButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _changePage(plugin, currentPage + 1),
            icon: const Icon(Icons.arrow_forward),
            color: Theme.of(context).primaryColor,
            disabledColor: Colors.grey[400],
          ),
        ],
      ),
    );
  }

  void _changePage(Plugin plugin, int page) {
    _currentPages[plugin.name] = page;

    infoController.pluginSearchStatus[plugin.name] = 'pending';
    queryManager?.querySource(_searchController.text, plugin.name, page: page);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    if (pluginsController.pluginList.isEmpty) {
      return Scaffold(
        appBar: SysAppBar(title: const Text('搜索')),
        body: const Center(child: Text('没有可用的插件')),
      );
    }

    return Scaffold(
      appBar: SysAppBar(
        title: // 搜索栏
            Container(
          color: Theme.of(context).appBarTheme.backgroundColor,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  cursorColor: Theme.of(context).colorScheme.primary,
                  decoration: InputDecoration(
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    labelText: '输入搜索内容',
                    alignLabelWithHint: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => _search(_searchController.text),
                    ),
                  ),
                  style: TextStyle(
                      color: isLight ? Colors.black87 : Colors.white70),
                  onSubmitted: _search,
                ),
              ),
              if (MediaQuery.of(context).orientation == Orientation.portrait)
                IconButton(
                  tooltip: '历史记录',
                  onPressed: () => Modular.to.pushNamed('/settings/history/'),
                  icon: const Icon(Icons.history),
                ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // TabBar
            Container(
              color: Theme.of(context).appBarTheme.backgroundColor,
              child: TabBar(
                isScrollable: true,
                controller: tabController,
                tabs: pluginsController.pluginList
                    .map((plugin) => Observer(
                          builder: (context) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                plugin.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .fontSize,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 5.0),
                              Container(
                                width: 8.0,
                                height: 8.0,
                                decoration: BoxDecoration(
                                  color: infoController.pluginSearchStatus[
                                              plugin.name] ==
                                          'success'
                                      ? Colors.green
                                      : (infoController.pluginSearchStatus[
                                                  plugin.name] ==
                                              'pending'
                                          ? Colors.grey
                                          : Colors.red),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            Expanded(
              child: Observer(
                builder: (context) => TabBarView(
                  controller: tabController,
                  children: pluginsController.pluginList.map((plugin) {
                    final cardItems = _buildCardItems(plugin);
                    final status =
                        infoController.pluginSearchStatus[plugin.name];
                    return Column(
                      children: [
                        if (status == 'pending')
                          const Expanded(
                              child: Center(child: CircularProgressIndicator()))
                        else if (status == 'error')
                          Expanded(child: _buildErrorWidget(plugin, '请求失败 重试'))
                        else if (cardItems.isEmpty)
                          Expanded(child: _buildErrorWidget(plugin, '本页无结果 换个关键词'))
                        else
                          // 使用网格布局展示卡片
                          Expanded(
                            child: _buildCardGrid(cardItems, plugin),
                          ),
                        buildPagination(plugin),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(Plugin plugin, String message) {
    return GeneralErrorWidget(
      errMsg: '${plugin.name} $message或切换到其他视频来源',
      actions: [
        GeneralErrorButton(
          onPressed: () {
            // 点击重试时立即更新状态为pending
            infoController.pluginSearchStatus[plugin.name] = 'pending';
            // 触发UI刷新
            setState(() {});
            // 发起请求
            queryManager?.querySource(_searchController.text, plugin.name,
                page: _currentPages[plugin.name] ?? 1);
          },
          text: '重试',
        ),
        GeneralErrorButton(
          onPressed: () => _showWebLaunchDialog(
              plugin.searchURL, _currentPages[plugin.name]),
          text: 'web',
        ),
      ],
    );
  }

  void _showWebLaunchDialog(String searchURL, page) {
    if (searchURL.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无效的链接地址')),
        );
      }
      return;
    }

    KazumiDialog.show(
        builder: (context) => AlertDialog(
              title: const Text('退出确认'),
              content: const Text('您想要离开 Kazumi 并在浏览器中打开此链接吗？'),
              actions: [
                TextButton(
                  onPressed: () => KazumiDialog.dismiss(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    KazumiDialog.dismiss();
                    try {
                      String queryURL = searchURL.replaceAll(
                          '@keyword', _searchController.text);
                      if (queryURL.contains('@pagenum')) {
                        queryURL = queryURL.replaceAll(
                            '@pagenum', page > 0 ? page.toString() : '1');
                      }
                      await launchUrl(Uri.parse(queryURL),
                          mode: LaunchMode.externalApplication);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('打开链接失败：${e.toString()}')),
                        );
                      }
                    }
                  },
                  child: const Text('确认'),
                ),
              ],
            ));
  }
}
