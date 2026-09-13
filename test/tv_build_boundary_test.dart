import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/platform/tv_mode.dart';

void main() {
  test('TV adaptation requires the explicit Android TV build', () {
    expect(TvMode.enabledForBuild(android: true, flavor: 'tv'), isTrue);
    for (final flavor in [null, '', 'mobile']) {
      expect(TvMode.enabledForBuild(android: true, flavor: flavor), isFalse);
    }
    expect(TvMode.enabledForBuild(android: false, flavor: 'tv'), isFalse);
  });
}
