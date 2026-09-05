import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/utils/search_parser.dart';

void main() {
  group('BangumiApi.buildBangumiSearchParams', () {
    test('keeps default search params compatible', () {
      final params = BangumiApi.buildBangumiSearchParams('frieren');
      final filter = params['filter'] as Map<String, dynamic>;

      expect(params['keyword'], 'frieren');
      expect(params['sort'], 'heat');
      expect(filter['type'], [2]);
      expect(filter['tag'], isEmpty);
      expect(filter['rank'], [">=0", "<=99999"]);
      expect(filter['nsfw'], isFalse);
    });

    test('builds advanced filter params', () {
      final params = BangumiApi.buildBangumiSearchParams(
        'bocchi',
        tags: ['音乐', '漫画改'],
        sort: 'score',
        dateRange: const SearchDateRange(
          start: '2022-09-01',
          end: '2022-12-01',
        ),
        rankRange: const SearchIntRange(min: 1, max: 1000),
        scoreRange: const SearchDoubleRange(min: 8.0, max: 10.0),
        weekdays: const [6, 1],
      );
      final filter = params['filter'] as Map<String, dynamic>;

      expect(params['keyword'], 'bocchi');
      expect(params['sort'], 'score');
      expect(filter['tag'], ['音乐', '漫画改']);
      expect(filter['air_date'], [">=2022-09-01", "<2022-12-01"]);
      expect(filter['rank'], [">=1", "<=1000"]);
      expect(filter['rating'], [">=8.0", "<=10.0"]);
      expect(filter['air_weekday'], [1, 6]);
      expect(filter['nsfw'], isFalse);
    });
  });
}
