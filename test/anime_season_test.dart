import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/anime_season.dart';

/// The season window is consumed as a half-open interval
/// (`air_date >= start` and `air_date < end`), so the last month of a season
/// has to fall inside the window or those subjects are never returned.
List<DateTime> _seasonWindow(DateTime date) => AnimeSeason(
  date,
).toSeasonStartAndEnd().map(DateTime.parse).toList(growable: false);

void main() {
  group('AnimeSeason.toSeasonStartAndEnd', () {
    test('winter keeps the December padding and ends in April', () {
      final window = _seasonWindow(DateTime(2024, 1, 15));

      expect(window[0], DateTime(2023, 12, 1));
      expect(window[1], DateTime(2024, 4, 1));
    });

    test('spring ends in July', () {
      final window = _seasonWindow(DateTime(2024, 4, 15));

      expect(window[0], DateTime(2024, 3, 1));
      expect(window[1], DateTime(2024, 7, 1));
    });

    test('summer ends in October', () {
      final window = _seasonWindow(DateTime(2024, 7, 15));

      expect(window[0], DateTime(2024, 6, 1));
      expect(window[1], DateTime(2024, 10, 1));
    });

    test('autumn rolls the end over into the next year', () {
      final window = _seasonWindow(DateTime(2024, 10, 15));

      expect(window[0], DateTime(2024, 9, 1));
      expect(window[1], DateTime(2025, 1, 1));
    });

    test('the whole last month of every season is inside the window', () {
      for (final date in [
        DateTime(2024, 1, 1),
        DateTime(2024, 4, 1),
        DateTime(2024, 7, 1),
        DateTime(2024, 10, 1),
      ]) {
        final window = _seasonWindow(date);
        final lastMonthOfSeason = DateTime(date.year, date.month + 2, 1);

        expect(
          lastMonthOfSeason.isBefore(window[1]),
          isTrue,
          reason:
              '${date.month} 月份所在季度的最后一个月'
              '${lastMonthOfSeason.month} 月被排除在 ${window[1]} 之外',
        );
      }
    });

    test('every month of a season resolves to the same window', () {
      for (final month in [1, 2, 3]) {
        expect(
          _seasonWindow(DateTime(2024, month, 10)),
          _seasonWindow(DateTime(2024, 1, 10)),
        );
      }
      for (final month in [10, 11, 12]) {
        expect(
          _seasonWindow(DateTime(2024, month, 10)),
          _seasonWindow(DateTime(2024, 10, 10)),
        );
      }
    });
  });

  group('isSameSeason', () {
    test('treats every month of a season as the same season', () {
      expect(isSameSeason(DateTime(2024, 1, 1), DateTime(2024, 3, 31)), isTrue);
      expect(isSameSeason(DateTime(2024, 4, 1), DateTime(2024, 6, 30)), isTrue);
      expect(isSameSeason(DateTime(2024, 7, 1), DateTime(2024, 9, 30)), isTrue);
      expect(
        isSameSeason(DateTime(2024, 10, 1), DateTime(2024, 12, 31)),
        isTrue,
      );
    });

    test('separates adjacent seasons', () {
      expect(
        isSameSeason(DateTime(2024, 3, 31), DateTime(2024, 4, 1)),
        isFalse,
      );
      expect(
        isSameSeason(DateTime(2024, 9, 30), DateTime(2024, 10, 1)),
        isFalse,
      );
    });

    test('separates the same calendar quarter across years', () {
      expect(
        isSameSeason(DateTime(2023, 1, 15), DateTime(2024, 1, 15)),
        isFalse,
      );
    });
  });
}
