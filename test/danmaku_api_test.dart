import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/request/apis/danmaku_api.dart';

void main() {
  test('anime search opts into the v2 search engine', () {
    expect(
      DanmakuApi.buildAnimeSearchQuery('一拳超人 第三季'),
      {
        'keyword': '一拳超人 第三季',
        'v2': 'true',
      },
    );
  });
}
