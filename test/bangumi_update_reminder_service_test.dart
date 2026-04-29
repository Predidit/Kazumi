import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_ranking_period.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/utils/bangumi_update_reminder_service.dart';

void main() {
  group('Bangumi update reminder', () {
    test('filters watching bangumi by current weekday', () {
      final monday = DateTime(2026, 4, 27);
      final mondayBangumi = _collectedBangumi(
        id: 1,
        title: 'Monday',
        weekday: DateTime.monday,
        type: CollectType.watching,
      );
      final tuesdayBangumi = _collectedBangumi(
        id: 2,
        title: 'Tuesday',
        weekday: DateTime.tuesday,
        type: CollectType.watching,
      );
      final watchedBangumi = _collectedBangumi(
        id: 3,
        title: 'Watched',
        weekday: DateTime.monday,
        type: CollectType.watched,
      );

      final result = BangumiUpdateReminderService.filterTodayUpdates(
        [mondayBangumi, tuesdayBangumi, watchedBangumi],
        monday,
      );

      expect(result.map((item) => item.id), [1]);
    });

    test('deduplicates repeated collectibles', () {
      final monday = DateTime(2026, 4, 27);
      final item = _bangumiItem(
        id: 1,
        title: 'Monday',
        weekday: DateTime.monday,
      );

      final result = BangumiUpdateReminderService.filterTodayUpdates(
        [
          CollectedBangumi(item, monday, CollectType.watching.value),
          CollectedBangumi(item, monday, CollectType.watching.value),
        ],
        monday,
      );

      expect(result.length, 1);
      expect(result.first.id, 1);
    });
  });

  group('Bangumi ranking period', () {
    test('only exposes month and all rankings', () {
      expect(BangumiRankingPeriod.values, [
        BangumiRankingPeriod.month,
        BangumiRankingPeriod.all,
      ]);
      expect(BangumiRankingPeriod.month.label, '月榜');
      expect(BangumiRankingPeriod.all.label, '总榜');
    });
  });
}

CollectedBangumi _collectedBangumi({
  required int id,
  required String title,
  required int weekday,
  required CollectType type,
}) {
  return CollectedBangumi(
    _bangumiItem(id: id, title: title, weekday: weekday),
    DateTime(2026, 4, 27),
    type.value,
  );
}

BangumiItem _bangumiItem({
  required int id,
  required String title,
  required int weekday,
}) {
  return BangumiItem(
    id: id,
    type: 2,
    name: title,
    nameCn: title,
    summary: '',
    airDate: '',
    airWeekday: weekday,
    rank: 0,
    images: const {},
    tags: const [],
    alias: const [],
    ratingScore: 0,
    votes: 0,
    votesCount: const [],
    info: '',
  );
}
