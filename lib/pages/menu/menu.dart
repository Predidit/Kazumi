import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/playback/playback_source.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/router.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/services/local_video_picker_service.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:provider/provider.dart';

class ScaffoldMenu extends StatefulWidget {
  const ScaffoldMenu({super.key});

  @override
  State<ScaffoldMenu> createState() => _ScaffoldMenu();
}

class NavigationBarState extends ChangeNotifier {
  late int _selectedIndex = getDefaultSelectedIndex();
  bool _isHide = false;
  bool _isBottom = false;

  int get selectedIndex => _selectedIndex;

  bool get isHide => _isHide;

  bool get isBottom => _isBottom;

  int getDefaultSelectedIndex() {
    final defaultPage = GStorage.setting
        .get(SettingBoxKey.defaultStartupPage, defaultValue: "/tab/popular/");

    switch (defaultPage) {
      case "/tab/popular/":
        return 0;
      case "/tab/timeline/":
        return 1;
      case "/tab/collect/":
        return 2;
      case "/tab/my/":
        return 3;
      default:
        return 0;
    }
  }

  void updateSelectedIndex(int pageIndex) {
    _selectedIndex = pageIndex;
    notifyListeners();
  }

  void hideNavigate() {
    _isHide = true;
    notifyListeners();
  }

  void showNavigate() {
    _isHide = false;
    notifyListeners();
  }
}

class _ScaffoldMenu extends State<ScaffoldMenu> {
  final PageController _page = PageController();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final HistoryController historyController = Modular.get<HistoryController>();
  final LocalVideoPickerService localVideoPickerService =
      LocalVideoPickerService();

  History? _findLocalFileHistory(String videoPath) {
    for (final history in historyController.histories) {
      if (!history.isLocalVideo) {
        continue;
      }
      if (history.localVideoPath == videoPath || history.lastSrc == videoPath) {
        return history;
      }
      for (final progress in history.progresses.values) {
        if (progress.localPath == videoPath) {
          return history;
        }
      }
    }
    return null;
  }

  Future<void> _openLocalVideo() async {
    final context = await localVideoPickerService.pickVideo();
    if (context == null) {
      return;
    }

    historyController.init();
    await _showLocalVideoSheet(context);
  }

  Future<void> _showLocalVideoSheet(
      LocalVideoPlaybackContext localVideoContext) async {
    final displayTitle =
        localVideoContext.title.isEmpty ? '本地视频' : localVideoContext.title;
    final videoPath = localVideoContext.path;
    final history = _findLocalFileHistory(videoPath);
    final historyProgress = history?.progresses[history.lastWatchEpisode];
    BangumiItem? selectedBangumi =
        history?.isBoundLocalVideo == true ? history!.bangumiItem : null;
    var episodeNumber = history?.lastWatchEpisode ?? 1;
    if (episodeNumber < 1) {
      episodeNumber = 1;
    }

    var results = <BangumiItem>[];
    var searching = false;
    final searchController = TextEditingController();
    final episodeController =
        TextEditingController(text: episodeNumber.toString());

    Future<void> startPlayback({required bool skipBinding}) async {
      final parsedEpisode = int.tryParse(episodeController.text.trim()) ?? 1;
      videoPageController.initForLocalFilePlayback(
        context: localVideoContext.copyWith(
          title: (historyProgress?.episodeTitle.isNotEmpty ?? false)
              ? historyProgress!.episodeTitle
              : displayTitle,
        ),
        boundBangumiItem: skipBinding ? null : selectedBangumi,
        episodeNumber: parsedEpisode < 1 ? 1 : parsedEpisode,
      );
      KazumiDialog.dismiss();
      Modular.to.pushNamed('/video/');
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> searchBangumi() async {
              final keyword = searchController.text.trim();
              if (keyword.isEmpty) {
                return;
              }
              setModalState(() {
                searching = true;
              });
              final value = await BangumiApi.bangumiSearch(keyword);
              setModalState(() {
                results = value;
                searching = false;
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '匹配番剧',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () => startPlayback(skipBinding: true),
                          child: const Text('不绑定'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              labelText: 'Bangumi 搜索',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => searchBangumi(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: searching ? null : searchBangumi,
                          tooltip: '搜索',
                          icon: searching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                        ),
                      ],
                    ),
                    if (selectedBangumi != null) ...[
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(
                          selectedBangumi!.nameCn.isNotEmpty
                              ? selectedBangumi!.nameCn
                              : selectedBangumi!.name,
                        ),
                        subtitle: const Text('已选择绑定条目'),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: episodeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '集数',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                    if (results.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final item = results[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item.nameCn.isNotEmpty
                                    ? item.nameCn
                                    : item.name,
                              ),
                              subtitle: Text(
                                item.airDate,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                setModalState(() {
                                  selectedBangumi = item;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton(
                          onPressed: selectedBangumi == null
                              ? null
                              : () => startPlayback(skipBinding: false),
                          child: const Text('绑定并播放'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
    episodeController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (context) => NavigationBarState(),
        child: Consumer<NavigationBarState>(builder: (context, state, _) {
          return OrientationBuilder(builder: (context, orientation) {
            state._isBottom = orientation == Orientation.portrait;
            return orientation != Orientation.portrait
                ? sideMenuWidget(context, state)
                : bottomMenuWidget(context, state);
          });
        }));
  }

  Widget bottomMenuWidget(BuildContext context, NavigationBarState state) {
    return Scaffold(
        body: Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: PageView.builder(
            physics: const NeverScrollableScrollPhysics(),
            controller: _page,
            itemCount: menu.size,
            itemBuilder: (_, __) => const RouterOutlet(),
          ),
        ),
        floatingActionButton: state.isHide
            ? null
            : FloatingActionButton.small(
                heroTag: 'openLocalVideoBottom',
                tooltip: '打开本地视频',
                onPressed: _openLocalVideo,
                child: const Icon(Icons.video_file_outlined),
              ),
        bottomNavigationBar: state.isHide
            ? const SizedBox(height: 0)
            : NavigationBar(
                destinations: const <Widget>[
                  NavigationDestination(
                    selectedIcon: Icon(Icons.home),
                    icon: Icon(Icons.home_outlined),
                    label: '推荐',
                  ),
                  NavigationDestination(
                    selectedIcon: Icon(Icons.timeline),
                    icon: Icon(Icons.timeline_outlined),
                    label: '时间表',
                  ),
                  NavigationDestination(
                    selectedIcon: Icon(Icons.favorite),
                    icon: Icon(Icons.favorite_outlined),
                    label: '追番',
                  ),
                  NavigationDestination(
                    selectedIcon: Icon(Icons.settings),
                    icon: Icon(Icons.settings),
                    label: '我的',
                  ),
                ],
                selectedIndex: state.selectedIndex,
                onDestinationSelected: (int index) {
                  state.updateSelectedIndex(index);
                  Modular.to.navigate("/tab${menu.getPath(index)}/");
                },
              ));
  }

  Widget sideMenuWidget(BuildContext context, NavigationBarState state) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Row(
        children: [
          EmbeddedNativeControlArea(
            child: Visibility(
              visible: !state.isHide,
              child: NavigationRail(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                groupAlignment: 1.0,
                leading: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      elevation: 0,
                      heroTag: 'search',
                      tooltip: '搜索',
                      onPressed: () {
                        Modular.to.pushNamed('/search/');
                      },
                      child: const Icon(Icons.search),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.small(
                      elevation: 0,
                      heroTag: 'openLocalVideoRail',
                      tooltip: '打开本地视频',
                      onPressed: _openLocalVideo,
                      child: const Icon(Icons.video_file_outlined),
                    ),
                  ],
                ),
                labelType: NavigationRailLabelType.selected,
                destinations: const <NavigationRailDestination>[
                  NavigationRailDestination(
                    selectedIcon: Icon(Icons.home),
                    icon: Icon(Icons.home_outlined),
                    label: Text('推荐'),
                  ),
                  NavigationRailDestination(
                    selectedIcon: Icon(Icons.timeline),
                    icon: Icon(Icons.timeline_outlined),
                    label: Text('时间表'),
                  ),
                  NavigationRailDestination(
                    selectedIcon: Icon(Icons.favorite),
                    icon: Icon(Icons.favorite_border),
                    label: Text('追番'),
                  ),
                  NavigationRailDestination(
                    selectedIcon: Icon(Icons.settings),
                    icon: Icon(Icons.settings_outlined),
                    label: Text('我的'),
                  ),
                ],
                selectedIndex: state.selectedIndex,
                onDestinationSelected: (int index) {
                  state.updateSelectedIndex(index);
                  Modular.to.navigate("/tab${menu.getPath(index)}/");
                },
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  bottomLeft: Radius.circular(16.0),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  bottomLeft: Radius.circular(16.0),
                ),
                child: PageView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: menu.size,
                  itemBuilder: (_, __) => const RouterOutlet(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
