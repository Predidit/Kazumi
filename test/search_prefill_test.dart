import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/pages/search/search_page.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/repositories/search_history_repository.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

class _UnusedCollectRepository extends Fake implements ICollectRepository {}

class _SearchController extends SearchPageController {
  _SearchController()
    : super(_UnusedCollectRepository(), SearchHistoryRepository());

  final searches = <(String, String)>[];

  @override
  Future<void> searchBangumi(String input, {String type = 'add'}) async {
    searches.add((input, type));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform originalPaths;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kazumi_search_prefill_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
    Hive.init(directory.path);
    await GStorage.init();
  });

  tearDownAll(() async {
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    await directory.delete(recursive: true);
  });

  testWidgets('submits a linked title once', (tester) async {
    final controller = _SearchController();
    const title = '葬送のフリーレン & A+B';
    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(controller: controller, initialQuery: title),
      ),
    );
    await tester.pumpAndSettle();

    final searchBar = tester.widget<SearchBar>(find.byType(SearchBar));
    expect(searchBar.controller!.text, title);
    expect(controller.searches, [(title, 'init')]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening search without a title does not submit', (tester) async {
    final controller = _SearchController();
    await tester.pumpWidget(
      MaterialApp(home: SearchPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(controller.searches, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
