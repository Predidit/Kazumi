import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/timeline/timeline_page.dart';
import 'package:kazumi/pages/timeline/timeline_page_weekly.dart';
import 'package:kazumi/pages/timeline/timeline_page_list.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobx/mobx.dart' hide when;
import 'package:hive_ce/hive.dart';

// Mock 类
class MockTimelineController extends Mock implements TimelineController {}

class MockBox extends Mock implements Box {}

void main() {
  late MockTimelineController mockController;
  late NavigationBarState navigationBarState;
  late MockBox mockSettingBox;

  setUpAll(() {
    // 全局只初始化一次 GStorage.setting
    GStorage.setting = MockBox();
  });

  setUp(() {
    mockController = MockTimelineController();
    navigationBarState = NavigationBarState();
    mockSettingBox = GStorage.setting as MockBox;

    // 默认行为
    when(() => mockController.bangumiCalendar)
        .thenReturn(ObservableList<List<BangumiItem>>.of(List.generate(7, (_) => [])));
    when(() => mockController.isLoading).thenReturn(false);
    when(() => mockController.isTimeOut).thenReturn(false);
    when(() => mockController.seasonString).thenReturn('2024春');
    when(() => mockController.sortType).thenReturn(1);
    when(() => mockController.notShowAbandonedBangumis).thenReturn(false);
    when(() => mockController.notShowWatchedBangumis).thenReturn(false);
    when(() => mockController.loadAbandonedBangumiIds()).thenReturn(<int>{});
    when(() => mockController.loadWatchedBangumiIds()).thenReturn(<int>{});
    
    // 默认设置值
    when(() => mockSettingBox.get(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((invocation) {
          final key = invocation.positionalArguments[0];
          final defaultValue = invocation.namedArguments[Symbol('defaultValue')];
          
          if (key == SettingBoxKey.timelineShowList) return false;
          if (key == SettingBoxKey.showRating) return true;
          return defaultValue;
        });

    // 模拟 Modular 获取 Controller
    Modular.destroy();
    Modular.init(TestModule(mockController));
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: InheritedProvider<NavigationBarState>.value(
        value: navigationBarState,
        child: const TimelinePage(),
      ),
    );
  }

  group('TimelinePage Tests', () {
    testWidgets('should initial view as Weekly according to GStorage',
        (WidgetTester tester) async {
      when(() => mockSettingBox.get(SettingBoxKey.timelineShowList, defaultValue: any(named: 'defaultValue')))
          .thenReturn(false);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      
      expect(find.byType(TimelinePageWeekly), findsOneWidget);
    });

    testWidgets('should initial view as List if specified in GStorage',
        (WidgetTester tester) async {
      when(() => mockSettingBox.get(SettingBoxKey.timelineShowList, defaultValue: any(named: 'defaultValue')))
          .thenReturn(true);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      
      expect(find.byType(TimelinePageList), findsOneWidget);
    });
  });
}

class TestModule extends Module {
  final TimelineController controller;
  TestModule(this.controller);

  @override
  void binds(i) {
    i.addInstance<TimelineController>(controller);
  }
}
