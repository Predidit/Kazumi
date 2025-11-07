import 'package:flutter/material.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.inputTag = ''});

  final String inputTag;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final SearchController searchController = SearchController();

  /// Don't use modular singleton here. We may have multiple search pages.
  /// Use a new instance of SearchPageController for each search page.
  final SearchPageController searchPageController = SearchPageController();
  final ScrollController scrollController = ScrollController();

  late final Set<String> watchedBangumiNames;

  final List<Tab> tabs = [
    Tab(text: "排序方式"),
    Tab(text: "过滤器"),
  ];

  @override
  void initState() {
    super.initState();
    scrollController.addListener(scrollListener);
    searchPageController.loadSearchHistories();
    watchedBangumiNames = searchPageController.loadWatchedBangumiNames();
  }

  @override
  void dispose() {
    searchPageController.bangumiList.clear();
    scrollController.removeListener(scrollListener);
    super.dispose();
  }

  void scrollListener() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !searchPageController.isLoading &&
        searchController.text != '' &&
        searchPageController.bangumiList.length >= 20) {
      debugPrint('Search results is loading more');
      searchPageController.searchBangumi(searchController.text, type: 'add');
    }
  }

  Widget showFilterSwitcher() {
    return Wrap(
      children: [
        Observer(
          builder: (context) => InkWell(
            onTap: () {
              searchPageController.setNotShowWatchedBangumis(
                  !searchPageController.notShowWatchedBangumis);
            },
            child: ListTile(
              title: const Text('不显示已看过的番剧'),
              trailing: Switch(
                value: searchPageController.notShowWatchedBangumis,
                onChanged: (value) {
                  searchPageController.setNotShowWatchedBangumis(value);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget showSortSwitcher() {
    return Wrap(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('按热度排序'),
              onTap: () {
                Navigator.pop(context);
                searchController.text = searchPageController.attachSortParams(
                    searchController.text, 'heat');
                searchPageController.searchBangumi(searchController.text,
                    type: 'init');
              },
            ),
            ListTile(
              title: const Text('按评分排序'),
              onTap: () {
                Navigator.pop(context);
                searchController.text = searchPageController.attachSortParams(
                    searchController.text, 'rank');
                searchPageController.searchBangumi(searchController.text,
                    type: 'init');
              },
            ),
            ListTile(
              title: const Text('按匹配程度排序'),
              onTap: () {
                Navigator.pop(context);
                searchController.text = searchPageController.attachSortParams(
                    searchController.text, 'match');
                searchPageController.searchBangumi(searchController.text,
                    type: 'init');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget showSearchOptionTabBar({required List<Widget> options}) {
    return DefaultTabController(
        length: tabs.length,
        child: Scaffold(
            body: Column(
          children: [
            PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: Material(
                child: TabBar(
                  tabs: tabs,
                ),
              ),
            ),
            Expanded(
                child: TabBarView(
              children: options,
            ))
          ],
        )));
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.inputTag != '') {
        final String tagString = 'tag:${Uri.decodeComponent(widget.inputTag)}';
        searchController.text = tagString;
        searchPageController.searchBangumi(tagString, type: 'init');
      }
    });
    return Scaffold(
      appBar: SysAppBar(
        backgroundColor: Colors.transparent,
        title: const Text("搜索"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          showModalBottomSheet(
            isScrollControlled: true,
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height >=
                      LayoutBreakpoint.compact['height']!)
                  ? MediaQuery.of(context).size.height * 1 / 4
                  : MediaQuery.of(context).size.height,
              maxWidth: (MediaQuery.sizeOf(context).width >=
                      LayoutBreakpoint.medium['width']!)
                  ? MediaQuery.of(context).size.width * 9 / 16
                  : MediaQuery.of(context).size.width,
            ),
            clipBehavior: Clip.antiAlias,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            context: context,
            builder: (context) {
              return showSearchOptionTabBar(
                  options: [showSortSwitcher(), showFilterSwitcher()]);
            },
          );
        },
        icon: const Icon(Icons.sort),
        label: const Text("搜索设置"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: FocusScope(
              descendantsAreFocusable: false,
              child: SearchAnchor.bar(
                searchController: searchController,
                barElevation: WidgetStateProperty<double>.fromMap(
                  <WidgetStatesConstraint, double>{WidgetState.any: 0},
                ),
                viewElevation: 0,
                viewLeading: IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.arrow_back),
                ),
                isFullScreen: MediaQuery.sizeOf(context).width <
                    LayoutBreakpoint.compact['width']!,
                suggestionsBuilder: (context, controller) => [
                  Observer(
                    builder: (context) {
                      if (controller.text.isNotEmpty) {
                        return Container(
                          height: 400,
                          alignment: Alignment.center,
                          child: Text("无可用搜索建议，回车以直接检索"),
                        );
                      } else {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var history in searchPageController
                                .searchHistories
                                .take(10))
                              ListTile(
                                title: Text(history.keyword),
                                onTap: () {
                                  controller.text = history.keyword;
                                  searchPageController.searchBangumi(
                                      controller.text,
                                      type: 'init');
                                  if (searchController.isOpen) {
                                    searchController.closeView(history.keyword);
                                  }
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    searchPageController
                                        .deleteSearchHistory(history);
                                  },
                                ),
                              ),
                          ],
                        );
                      }
                    },
                  ),
                ],
                onSubmitted: (value) {
                  searchPageController.searchBangumi(value, type: 'init');
                  if (searchController.isOpen) {
                    searchController.closeView(value);
                  }
                },
              ),
            ),
          ),
          Expanded(
            child: Observer(builder: (context) {
              if (searchPageController.isTimeOut) {
                return Center(
                  child: SizedBox(
                    height: 400,
                    child: GeneralErrorWidget(
                      errMsg: '什么都没有找到 (´;ω;`)',
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            searchPageController.searchBangumi(
                                searchController.text,
                                type: 'init');
                          },
                          text: '点击重试',
                        ),
                      ],
                    ),
                  ),
                );
              }


              if (searchPageController.isLoading &&
                  searchPageController.bangumiList.isEmpty) {
                return Center(child: CircularProgressIndicator());
              }
              int crossCount = 3;
              if (MediaQuery.sizeOf(context).width >
                  LayoutBreakpoint.compact['width']!) {
                crossCount = 5;
              }
              if (MediaQuery.sizeOf(context).width >
                  LayoutBreakpoint.medium['width']!) {
                crossCount = 6;
              }
              final filteredList = searchPageController.notShowWatchedBangumis
                  ? searchPageController.bangumiList
                      .where((item) => !watchedBangumiNames.contains(item.name))
                      .toList()
                  : searchPageController.bangumiList;

              return GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  mainAxisSpacing: StyleString.cardSpace - 2,
                  crossAxisSpacing: StyleString.cardSpace,
                  crossAxisCount: crossCount,
                  mainAxisExtent:
                      MediaQuery.of(context).size.width / crossCount / 0.65 +
                          MediaQuery.textScalerOf(context).scale(32.0),
                ),
                itemCount: filteredList.isNotEmpty ? filteredList.length : 10,
                itemBuilder: (context, index) {
                  return filteredList.isNotEmpty
                      ? BangumiCardV(
                          enableHero: false,
                          bangumiItem: filteredList[index],
                        )
                      : Container();
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
