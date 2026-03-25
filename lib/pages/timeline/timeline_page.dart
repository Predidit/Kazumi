import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/pages/timeline/timeline_page_weekly.dart';
import 'package:kazumi/pages/timeline/timeline_page_list.dart';
import 'package:kazumi/utils/storage.dart';

class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final timelineShowList = GStorage.setting.get(SettingBoxKey.showRating, defaultValue: true);

    return Observer(
      builder: (_) {
        if (timelineShowList) {
          return const TimelinePageList();
        } else {
          return const TimelinePageWeekly();
        }
      },
    );
  }
}
