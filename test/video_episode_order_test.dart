import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/video/video_page.dart';

void main() {
  test('episode order maps display positions without changing episode numbers',
      () {
    expect(
      List.generate(
        4,
        (index) => episodeNumberForDisplayIndex(index, 4, descending: false),
      ),
      [1, 2, 3, 4],
    );
    expect(
      List.generate(
        4,
        (index) => episodeNumberForDisplayIndex(index, 4, descending: true),
      ),
      [4, 3, 2, 1],
    );
    expect(
      displayIndexForEpisodeNumber(2, 4, descending: true),
      2,
    );
  });

  test('changing one source keeps other source preferences', () {
    expect(
      descendingEpisodeSources(
        const ['giriGiriLove'],
        '7sefun',
        descending: true,
      ),
      unorderedEquals(['giriGiriLove', '7sefun']),
    );
    expect(
      descendingEpisodeSources(
        const ['giriGiriLove', '7sefun'],
        '7sefun',
        descending: false,
      ),
      ['giriGiriLove'],
    );
  });
}
