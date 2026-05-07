import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
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
  bool _openingLocalVideo = false;

  String _normalizeLocalVideoPath(String path) {
    return path.replaceAll('\\', '/').toLowerCase();
  }

  History? _findLocalFileHistory(String videoPath) {
    final normalizedVideoPath = _normalizeLocalVideoPath(videoPath);
    for (final history in historyController.histories) {
      if (!history.isLocalVideo) {
        continue;
      }
      if (_normalizeLocalVideoPath(history.localVideoPath) ==
              normalizedVideoPath ||
          _normalizeLocalVideoPath(history.lastSrc) == normalizedVideoPath) {
        return history;
      }
      for (final progress in history.progresses.values) {
        if (_normalizeLocalVideoPath(progress.localPath) ==
            normalizedVideoPath) {
          return history;
        }
      }
    }
    return null;
  }

  Future<void> _openLocalVideo() async {
    if (_openingLocalVideo) {
      return;
    }
    _openingLocalVideo = true;
    final context = await localVideoPickerService.pickVideo();
    if (context == null) {
      _openingLocalVideo = false;
      return;
    }

    try {
      historyController.init();
      await _showLocalVideoSheet(context);
    } finally {
      _openingLocalVideo = false;
    }
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
    var episodeLoading = false;
    var episodeLoadFailed = false;
    var openingPlayback = false;
    var shouldOpenPlayback = false;
    var episodeList = <EpisodeInfo>[];
    int? selectedEpisode = selectedBangumi == null ? null : episodeNumber;
    final searchController = TextEditingController();
    final episodeController =
        TextEditingController(text: episodeNumber.toString());

    Future<void> startPlayback({
      required BuildContext sheetContext,
      required bool skipBinding,
    }) async {
      if (openingPlayback) {
        return;
      }
      openingPlayback = true;
      final parsedEpisode =
          selectedEpisode ?? int.tryParse(episodeController.text.trim()) ?? 1;
      videoPageController.initForLocalFilePlayback(
        context: localVideoContext.copyWith(
          title: (historyProgress?.episodeTitle.isNotEmpty ?? false)
              ? historyProgress!.episodeTitle
              : displayTitle,
        ),
        boundBangumiItem: skipBinding ? null : selectedBangumi,
        episodeNumber: parsedEpisode < 1 ? 1 : parsedEpisode,
      );
      if (!sheetContext.mounted) {
        return;
      }
      shouldOpenPlayback = true;
      Navigator.of(sheetContext).pop();
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
              try {
                final value = await BangumiApi.bangumiSearch(keyword);
                if (!context.mounted) {
                  return;
                }
                setModalState(() {
                  results = value;
                  searching = false;
                });
                if (value.isEmpty) {
                  KazumiDialog.showToast(message: '未找到匹配结果');
                }
              } catch (e) {
                if (!context.mounted) {
                  return;
                }
                setModalState(() {
                  searching = false;
                });
                KazumiDialog.showToast(message: '搜索失败');
              }
            }

            Future<void> selectBangumi(BangumiItem item) async {
              setModalState(() {
                selectedBangumi = item;
                selectedEpisode = null;
                results = [];
                episodeList = [];
                episodeLoadFailed = false;
                episodeLoading = true;
              });
              try {
                final value = await BangumiApi.getBangumiEpisodesByID(item.id);
                if (!context.mounted) {
                  return;
                }
                setModalState(() {
                  episodeList = value
                      .where((episode) => episode.type == 0)
                      .where((episode) => episode.episode > 0)
                      .toList();
                  episodeLoading = false;
                  episodeLoadFailed = episodeList.isEmpty;
                });
                if (episodeList.isEmpty) {
                  KazumiDialog.showToast(message: '未获取到集数，请手动输入');
                }
              } catch (e) {
                if (!context.mounted) {
                  return;
                }
                setModalState(() {
                  episodeList = [];
                  episodeLoading = false;
                  episodeLoadFailed = true;
                });
                KazumiDialog.showToast(message: '未获取到集数，请手动输入');
              }
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
                          onPressed: openingPlayback
                              ? null
                              : () => startPlayback(
                                    sheetContext: context,
                                    skipBinding: true,
                                  ),
                          child: const Text('不绑定'),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: openingPlayback
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
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
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              labelText: 'Bangumi 搜索',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                tooltip: '清除',
                                onPressed: () {
                                  setModalState(() {
                                    searchController.clear();
                                    selectedBangumi = null;
                                    selectedEpisode = null;
                                    results = [];
                                    episodeList = [];
                                    episodeLoadFailed = false;
                                    episodeLoading = false;
                                  });
                                },
                                icon: const Icon(Icons.clear),
                              ),
                            ),
                            onChanged: (_) {
                              if (selectedBangumi == null) {
                                return;
                              }
                              setModalState(() {
                                selectedBangumi = null;
                                selectedEpisode = null;
                                episodeList = [];
                                episodeLoadFailed = false;
                                episodeLoading = false;
                              });
                            },
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
                        subtitle: Text(
                          selectedEpisode == null && !episodeLoadFailed
                              ? '已选择绑定条目'
                              : '已选择绑定条目 · 第${selectedEpisode ?? int.tryParse(episodeController.text.trim()) ?? 1}集',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (episodeLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (episodeList.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 216),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final crossAxisCount = (constraints.maxWidth / 72)
                                  .floor()
                                  .clamp(4, 8)
                                  .toInt();
                              return GridView.builder(
                                shrinkWrap: true,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  mainAxisExtent: 48,
                                ),
                                itemCount: episodeList.length,
                                itemBuilder: (context, index) {
                                  final episode =
                                      episodeList[index].episode.toInt();
                                  final selected = selectedEpisode == episode;
                                  return selected
                                      ? FilledButton.tonal(
                                          onPressed: () {},
                                          child: Text(episode.toString()),
                                        )
                                      : OutlinedButton(
                                          onPressed: () {
                                            setModalState(() {
                                              selectedEpisode = episode;
                                              episodeController.text =
                                                  episode.toString();
                                            });
                                          },
                                          child: Text(episode.toString()),
                                        );
                                },
                              );
                            },
                          ),
                        )
                      else if (episodeLoadFailed)
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
                                selectBangumi(item);
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
                          onPressed: openingPlayback ||
                                  selectedBangumi == null ||
                                  (selectedEpisode == null &&
                                      !episodeLoadFailed)
                              ? null
                              : () => startPlayback(
                                    sheetContext: context,
                                    skipBinding: false,
                                  ),
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
    if (shouldOpenPlayback) {
      await Future<void>.delayed(Duration.zero);
      Modular.to.pushNamed('/video/');
    }
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
