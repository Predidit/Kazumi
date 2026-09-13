// Offline data and route targets for component/AVD regression only.
// This file is never imported by lib/ or a normal application entrypoint.
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/history/history_page.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/popular/popular_page.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/pages/search/search_page.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/video/video_playback_args.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/repositories/search_history_repository.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:kazumi/services/player/history_playback_service.dart';
import 'package:kazumi/services/plugin/rule_engine_models.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/episode_tile.dart';
import 'package:kazumi/bean/widget/tv_app_shell.dart';
import 'package:kazumi/bean/widget/tv_focus_navigation.dart';
import 'package:kazumi/navigation.dart';
import 'package:flutter/services.dart';

BangumiItem focusItem(int id) => BangumiItem(
    id: id,
    type: 2,
    name: '本地测试番剧 $id',
    nameCn: '本地测试番剧 $id',
    summary: '仅供焦点验证',
    airDate: '2026-09-06',
    airWeekday: 7,
    rank: id,
    images: {},
    tags: [],
    alias: [],
    ratingScore: 8,
    votes: 100,
    votesCount: List.filled(10, 10),
    info: '');

class FocusPopularController extends PopularController {
  FocusPopularController({int count = 31}) {
    trendList.addAll(List.generate(count, (i) => focusItem(i + 1)));
  }
  int queries = 0;
  @override
  Future<void> queryBangumiByTrend({String type = 'add'}) async {
    queries++;
  }

  @override
  Future<void> queryBangumiByTag({String type = 'add'}) async {
    queries++;
    if (type == 'init') {
      bangumiList.clear();
      bangumiList.addAll(trendList);
    }
  }
}

class _UnusedCollectRepository implements ICollectRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedSearchHistoryRepository implements ISearchHistoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FocusSearchController extends SearchPageController {
  FocusSearchController()
      : super(_UnusedCollectRepository(), _UnusedSearchHistoryRepository());
  String? submitted;
  bool preserveResults = false;
  @override
  void loadSearchHistories() {}
  @override
  Future<void> searchBangumi(String input, {String type = 'add'}) async {
    submitted = input;
    if (preserveResults) return;
    bangumiList.clear();
    bangumiList.add(focusItem(99));
    hasMoreSearchResults = false;
  }
}

class FocusCollectController implements CollectController {
  @override
  ObservableList<CollectedBangumi> collectibles = ObservableList();
  int type = 0;
  @override
  int getCollectType(BangumiItem item) => type;
  @override
  Future<void> addCollect(BangumiItem item, {dynamic type = 1}) async {
    this.type = type as int;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FocusHistoryRepository implements IHistoryRepository {
  FocusHistoryRepository({int count = 5})
      : items = List.generate(
            count,
            (i) => History(
                focusItem(i + 1), 2, '本地测试源', DateTime(2026, 9, 6), '', '第2集'));
  final List<History> items;
  final List<String> deleted = [];
  @override
  List<History> getAllHistories() => List.of(items);
  @override
  Future<void> deleteHistory(History history) async {
    deleted.add(history.key);
    items.removeWhere((item) => item.key == history.key);
  }

  @override
  Future<void> clearAllHistories() async {
    items.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FocusPlaybackService implements HistoryPlaybackService {
  final List<History> opened = [];
  @override
  Future<HistoryPlaybackResult> open(History history,
      {RuleCancelToken? cancelToken}) async {
    opened.add(history);
    return HistoryPlaybackReady(OfflineVideoPlaybackArgs(
        bangumiItem: history.bangumiItem,
        pluginName: history.adapterName,
        episodeNumber: history.lastWatchEpisode,
        road: 0,
        downloadedEpisodes: []));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FocusFixtureApp extends StatelessWidget {
  FocusFixtureApp(
      {super.key,
      this.initialRoute = '/tab/popular/',
      int count = 31,
      int historyCount = 5,
      this.textScale = 1,
      this.brightness = Brightness.dark}) {
    popular = FocusPopularController(count: count);
    historyRepository = FocusHistoryRepository(count: historyCount);
    history = HistoryController(historyRepository);
    module = createModule(register: (c) {
      c.addInstance<CollectController>(collection);
      c.addInstance<HistoryPlaybackService>(playback);
      c.route('/tab/',
          child: (_, state) => ScaffoldMenu(location: state.uri.path),
          children: (sub) {
            sub.route('/popular/',
                child: (_, __) => PopularPage(controller: popular));
            sub.route('/history/',
                child: (_, __) => HistoryPage(controller: history));
            sub.route('/timeline/',
                child: (_, __) => const FocusEpisodeFixture());
          });
      c.route('/search/', child: (_, __) => SearchPage(controller: search));
      c.route('/info/',
          child: (_, __) => const _FixtureDestination(label: '详情路由：本地测试'));
      c.route('/video/',
          child: (_, __) =>
              const _FixtureDestination(label: '续播路由：仅验证参数，不是真实视频'));
    });
  }
  final String initialRoute;
  final Brightness brightness;
  final double textScale;
  late final Module module;
  late final FocusPopularController popular;
  late final FocusHistoryRepository historyRepository;
  late final HistoryController history;
  final search = FocusSearchController();
  final collection = FocusCollectController();
  final playback = FocusPlaybackService();

  @override
  Widget build(BuildContext context) => ModularApp(
        module: module,
        initialRoute: initialRoute,
        navigatorKey: rootNavigatorKey,
        navigatorObservers: [rootRouteObserver, KazumiDialog.observer],
        child: Builder(
            builder: (context) => MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  theme: ThemeData(
                      colorSchemeSeed: Colors.green, brightness: brightness),
                  routerConfig: ModularApp.routerConfigOf(context),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(textScale)),
                    child: TvAppShell(child: child!),
                  ),
                )),
      );
}

class _FixtureDestination extends StatelessWidget {
  const _FixtureDestination({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(label)),
        body: Center(
            child: TextButton(
                autofocus: true,
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('返回原页面'))),
      );
}

class FocusEpisodeFixture extends StatefulWidget {
  const FocusEpisodeFixture({super.key});
  @override
  State<FocusEpisodeFixture> createState() => _FocusEpisodeFixtureState();
}

class _FocusEpisodeFixtureState extends State<FocusEpisodeFixture> {
  final nodes = List.generate(
      10, (i) => FocusNode(debugLabel: 'Fixture episode ${i + 1}'));
  @override
  void dispose() {
    for (final node in nodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('真实选集组件 · 本地状态样例（无视频）')),
        body: Center(
            child: SizedBox(
                width: 430,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(
                      autofocus: false,
                      onPressed: () {
                        Actions.maybeInvoke(context, const TvFocusRailIntent());
                      },
                      child: const Text('返回侧栏')),
                  GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 4,
                      childAspectRatio: 2,
                      children: List.generate(
                          10,
                          (i) => EpisodeTile(
                              label: '第${i + 1}集',
                              isPlaying: i == 0,
                              focusNode: nodes[i],
                              onPressed: () {},
                              onKeyEvent: (_, event) {
                                if (event is! KeyDownEvent &&
                                    event is! KeyRepeatEvent) {
                                  return KeyEventResult.ignored;
                                }
                                final direction = switch (event.logicalKey) {
                                  LogicalKeyboardKey.arrowLeft =>
                                    TraversalDirection.left,
                                  LogicalKeyboardKey.arrowRight =>
                                    TraversalDirection.right,
                                  LogicalKeyboardKey.arrowDown =>
                                    TraversalDirection.down,
                                  LogicalKeyboardKey.arrowUp =>
                                    TraversalDirection.up,
                                  _ => null,
                                };
                                if (direction == null ||
                                    (direction == TraversalDirection.up &&
                                        i < 4)) {
                                  return KeyEventResult.ignored;
                                }
                                nodes[tvGridTarget(i, 10, 4, direction)]
                                    .requestFocus();
                                return KeyEventResult.handled;
                              }))),
                ]))),
      );
}
