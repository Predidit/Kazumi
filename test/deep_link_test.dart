import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/deep_links/deep_link_dispatcher.dart';
import 'package:kazumi/services/deep_links/kazumi_deep_link.dart';
import 'package:kazumi/utils/encoding.dart';

void main() {
  test('opens a positive Bangumi subject ID', () {
    final link = KazumiDeepLink.parse(Uri.parse('kazumi://bangumi/12345'));
    expect(link, isA<BangumiDeepLink>());
    expect((link as BangumiDeepLink).id, 12345);
  });

  test('decodes title search once and preserves punctuation', () {
    const title = '葬送のフリーレン & A+B / 100%';
    final uri = Uri(
      scheme: 'kazumi',
      host: 'search',
      queryParameters: {'query': title},
    );
    final link = KazumiDeepLink.parse(uri) as SearchDeepLink;
    expect(link.query, title);
    expect(
      (KazumiDeepLink.parse(
        Uri.parse('kazumi://search?query=100%2525'),
      ) as SearchDeepLink).query,
      '100%25',
    );
  });

  test('ignores unsupported and malformed destinations', () {
    for (final raw in [
      'https://bangumi/123',
      'kazumi://bangumi/0',
      'kazumi://bangumi/-1',
      'kazumi://bangumi/1.5',
      'kazumi://bangumi/1/extra',
      'kazumi://bangumi/999999999999999999999999',
      'kazumi://user@bangumi/1',
      'kazumi://bangumi:80/1',
      'kazumi://bangumi/1#fragment',
      'kazumi://search',
      'kazumi://search?query=%20',
      'kazumi://search?query=a&query=b',
      'kazumi://search/extra?query=a',
    ]) {
      expect(KazumiDeepLink.parse(Uri.parse(raw)), isNull, reason: raw);
    }
  });

  test(
    'rule share links still round trip through the existing importer codec',
    () {
      const json = '{"name":"test","version":"1"}';
      final link = jsonToKazumiBase64(json);
      expect(KazumiDeepLink.parse(Uri.parse(link)), isNull);
      expect(kazumiBase64ToJson(link), json);
    },
  );

  test('keeps only the latest startup link until ready', () async {
    final opened = <int>[];
    final dispatcher = DeepLinkDispatcher(
      onOpen: (link, isCurrent) async {
        opened.add((link as BangumiDeepLink).id);
      },
      onError: (error, stack) => fail('$error'),
    );
    dispatcher.receive(Uri.parse('kazumi://bangumi/1'));
    dispatcher.receive(Uri.parse('kazumi://bangumi/2'));
    dispatcher.receive(Uri.parse('kazumi://unsupported'));
    expect(opened, isEmpty);
    dispatcher.markReady();
    await pumpEventQueue();
    expect(opened, [2]);
    dispatcher.markReady();
    expect(opened, [2]);
  });

  test('a warm link supersedes an in-flight detail lookup', () async {
    final lookup = Completer<void>();
    final opened = <int>[];
    final dispatcher = DeepLinkDispatcher(
      onOpen: (link, isCurrent) async {
        final id = (link as BangumiDeepLink).id;
        if (id == 1) await lookup.future;
        if (isCurrent()) opened.add(id);
      },
      onError: (error, stack) => fail('$error'),
    )..markReady();
    dispatcher.receive(Uri.parse('kazumi://bangumi/1'));
    dispatcher.receive(Uri.parse('kazumi://bangumi/2'));
    lookup.complete();
    await pumpEventQueue();
    expect(opened, [2]);
  });

  test('reports lookup failures and accepts subsequent links', () async {
    final errors = <Object>[];
    final opened = <String>[];
    final dispatcher = DeepLinkDispatcher(
      onOpen: (link, isCurrent) async {
        if (link is BangumiDeepLink) throw StateError('offline');
        opened.add((link as SearchDeepLink).query);
      },
      onError: (error, stack) => errors.add(error),
    )..markReady();
    dispatcher.receive(Uri.parse('kazumi://bangumi/1'));
    await pumpEventQueue();
    expect(errors.single, isA<StateError>());
    dispatcher.receive(Uri.parse('kazumi://search?query=Frieren'));
    await pumpEventQueue();
    expect(opened, ['Frieren']);
  });
}
