import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/download/download_episode_sheet.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/repositories/download_repository.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:kazumi/services/download/download_manager.dart';

void main() {
  testWidgets('opens with the playing episode centered', (tester) async {
    final downloadRepository = _DownloadRepositoryFake();
    final downloadManager = _DownloadManagerFake();
    final downloadController = DownloadController(
      downloadRepository,
      downloadManager,
      PluginsController(),
    );
    bootstrapModule(createModule(register: (module) {
      module.addInstance(downloadController);
    }));

    final videoController = VideoPageController(
      HistoryController(_HistoryRepositoryFake()),
      downloadRepository,
      downloadManager,
    )
      ..bangumiItem = BangumiItem(
        id: 1,
        type: 2,
        name: 'Test',
        nameCn: 'Test',
        summary: '',
        airDate: '',
        airWeekday: 1,
        rank: 0,
        images: const {},
        tags: const [],
        alias: const [],
        ratingScore: 0,
        votes: 0,
        votesCount: const [],
        info: '',
      )
      ..currentPlugin = (Plugin.fromTemplate()..name = 'test')
      ..roadList.add(Road(
        name: '线路1',
        data: List.generate(100, (index) => 'url-${index + 1}'),
        identifier: List.generate(100, (index) => '第${index + 1}集'),
      ))
      ..playingEpisode = const VideoEpisodeSelection(episode: 80, road: 0);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DownloadEpisodeSheet(
          road: 0,
          videoPageController: videoController,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final episode = find.text('第80集');
    expect(episode, findsOneWidget);
    final gridCenter = tester.getRect(find.byType(GridView)).center.dy;
    expect((tester.getCenter(episode).dy - gridCenter).abs(), lessThan(56));
  });
}

class _DownloadRepositoryFake implements IDownloadRepository {
  @override
  DownloadRecord? getRecordByBangumiId(int bangumiId, String pluginName) =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DownloadManagerFake implements IDownloadManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HistoryRepositoryFake implements IHistoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
