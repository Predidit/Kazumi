import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/anime_season.dart';

void main() {
  group('AnimeSeason.toString', () {
    test('January is winter', () {
      final season = AnimeSeason(DateTime(2024, 1, 15));
      expect(season.toString(), '2024年冬季新番');
    });

    test('April is spring', () {
      final season = AnimeSeason(DateTime(2024, 4, 1));
      expect(season.toString(), '2024年春季新番');
    });

    test('July is summer', () {
      final season = AnimeSeason(DateTime(2024, 7, 31));
      expect(season.toString(), '2024年夏季新番');
    });

    test('October is autumn', () {
      final season = AnimeSeason(DateTime(2024, 10, 1));
      expect(season.toString(), '2024年秋季新番');
    });

    test('season boundary: March 31 = winter', () {
      final season = AnimeSeason(DateTime(2024, 3, 31));
      expect(season.toString(), '2024年冬季新番');
    });

    test('season boundary: April 1 = spring', () {
      final season = AnimeSeason(DateTime(2024, 4, 1));
      expect(season.toString(), '2024年春季新番');
    });

    test('December = autumn (same year)', () {
      final season = AnimeSeason(DateTime(2024, 12, 25));
      expect(season.toString(), '2024年秋季新番');
    });
  });

  group('getSeasonStringByMonth', () {
    test('months 1-3 are winter', () {
      expect(getSeasonStringByMonth(1), '冬');
      expect(getSeasonStringByMonth(2), '冬');
      expect(getSeasonStringByMonth(3), '冬');
    });

    test('months 4-6 are spring', () {
      expect(getSeasonStringByMonth(4), '春');
      expect(getSeasonStringByMonth(5), '春');
      expect(getSeasonStringByMonth(6), '春');
    });

    test('months 7-9 are summer', () {
      expect(getSeasonStringByMonth(7), '夏');
      expect(getSeasonStringByMonth(8), '夏');
      expect(getSeasonStringByMonth(9), '夏');
    });

    test('months 10-12 are autumn', () {
      expect(getSeasonStringByMonth(10), '秋');
      expect(getSeasonStringByMonth(11), '秋');
      expect(getSeasonStringByMonth(12), '秋');
    });
  });

  group('isSameSeason', () {
    test('same month same year', () {
      expect(
        isSameSeason(DateTime(2024, 1, 10), DateTime(2024, 1, 20)),
        isTrue,
      );
    });

    test('adjacent months in same quarter', () {
      expect(
        isSameSeason(DateTime(2024, 1, 1), DateTime(2024, 2, 28)),
        isTrue,
      );
    });

    test('two months apart in same quarter', () {
      expect(
        isSameSeason(DateTime(2024, 1, 1), DateTime(2024, 3, 31)),
        isTrue,
      );
    });

    test('three months apart crosses season boundary', () {
      expect(
        isSameSeason(DateTime(2024, 1, 1), DateTime(2024, 4, 1)),
        isFalse,
      );
    });

    test('different year but same month', () {
      expect(
        isSameSeason(DateTime(2024, 7, 1), DateTime(2025, 7, 1)),
        isFalse,
      );
    });

    test('absolute difference handles month reversal', () {
      expect(
        isSameSeason(DateTime(2024, 3, 1), DateTime(2024, 1, 1)),
        isTrue,
      );
    });
  });
}
