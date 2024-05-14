import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/utils/constans.dart';
import 'package:kazumi/pages/error/http_error.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter/services.dart';

class PopularPage extends StatefulWidget {
  const PopularPage({super.key});

  @override
  State<PopularPage> createState() => _PopularPageState();
}

class _PopularPageState extends State<PopularPage>
    with AutomaticKeepAliveClientMixin {
  DateTime? _lastPressedAt;
  bool timeout = false;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final PopularController popularController = Modular.get<PopularController>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint('Popular初始化成功');
    timeout = false;
    if (popularController.bangumiList.length < 5) {
      debugPrint('Popular缓存列表为空, 尝试重加载');
      Timer(const Duration(seconds: 3), () {
        timeout = true;
      });
      popularController.scrollOffset = 0.0;
      popularController.queryBangumiListFeed();
    }
  }

  @override
  void dispose() {
    // popularController.scrollOffset = scrollController.offset;
    scrollController.removeListener(() {});
    debugPrint('popular 模块已卸载, 监听器移除');
    super.dispose();
  }

  void onBackPressed(BuildContext context) {
    if (_lastPressedAt == null ||
        DateTime.now().difference(_lastPressedAt!) >
            const Duration(seconds: 2)) {
      // 两次点击时间间隔超过2秒，重新记录时间戳
      _lastPressedAt = DateTime.now();
      SmartDialog.showToast("再按一次退出应用");
      return;
    }
    SystemNavigator.pop(); // 退出应用
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var themedata = Theme.of(context);
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      debugPrint('尝试恢复状态');
      scrollController.jumpTo(popularController.scrollOffset);
      debugPrint('Popular加载完成');
    });
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        onBackPressed(context);
      },
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await popularController.queryBangumiListFeed();
          },
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Theme.of(context)
                .colorScheme
                .primary
                .withOpacity(0.5),
              title: TextField(
                focusNode: _focusNode,
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: const InputDecoration(
                  hintText: '快速搜索',
                  hintStyle: TextStyle(color: Colors.white, fontSize: 20),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.white),
                ),
                autocorrect: false,
                autofocus: false,
                onTap: () {
                  setState(() {
                    _focusNode.requestFocus();
                    _controller.clear();
                  });
                },
                onChanged: (_) {
                  scrollController.jumpTo(0.0);
                },
                onSubmitted: (t) {
                  popularController.searchKeyword = t;
                  popularController.queryBangumi(popularController.searchKeyword);
                },
              ),
              // actions: [IconButton(onPressed: () {
              //   popularController.queryBangumi(popularController.keyword);
              // }, icon: const Icon(Icons.search))],
            ),
            body: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(top: 10, bottom: 10, left: 16),
                    // child: Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //     Text(
                    //       '每日放送',
                    //       style: Theme.of(context).textTheme.titleMedium,
                    //     ),
                    //   ],
                    // ),
                  ),
                ),
                SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        StyleString.safeSpace, 0, StyleString.safeSpace, 0),
                    sliver: Observer(builder: (context) {
                      if (popularController.bangumiList.length < 5 &&
                          timeout == true) {
                        return HttpError(
                          errMsg: '加载推荐流错误',
                          fn: () {
                            popularController.queryBangumiListFeed();
                          },
                        );
                      }
                      if (popularController.bangumiList.length < 5 &&
                          timeout == false) {
                        return const SliverToBoxAdapter(
                          child: SizedBox(
                              height: 600,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                ],
                              )),
                        );
                      }
                      return contentGrid(popularController.bangumiList);
                    })),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                scrollController.jumpTo(0.0);
                popularController.scrollOffset = 0.0;
              },
              child: const Icon(Icons.arrow_upward),
            ),
            backgroundColor: themedata.colorScheme.primaryContainer,
          ),
        ),
      ),
    );
  }

  Widget contentGrid(bangumiList) {
    int crossCount = Platform.isWindows || Platform.isLinux ? 6 : 3;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        // 行间距
        mainAxisSpacing: StyleString.cardSpace - 2,
        // 列间距
        crossAxisSpacing: StyleString.cardSpace,
        // 列数
        crossAxisCount: crossCount,
        mainAxisExtent: MediaQuery.of(context).size.width / crossCount / 0.65 +
            MediaQuery.textScalerOf(context).scale(32.0),
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return bangumiList!.isNotEmpty
              ? BangumiCardV(bangumiItem: bangumiList[index])
              : null;
        },
        childCount: bangumiList!.isNotEmpty ? bangumiList!.length : 10,
      ),
    );
  }
}
