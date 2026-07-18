import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/update/update_release_metadata_loader.dart';

void main() {
  const mirror = 'https://mirror.example/kazumi/latest';
  const official =
      'https://api.github.com/repos/Predidit/Kazumi/releases/latest';

  test('falls back to official metadata after a mirror transport failure',
      () async {
    final attempts = <String>[];
    final failures = <String>[];
    final loader = UpdateReleaseMetadataLoader(
      endpoints: const [mirror, official],
      fetch: (endpoint) async {
        attempts.add(endpoint);
        if (endpoint == mirror) {
          throw Exception('proxy blocked mirror');
        }
        return json.encode({
          'tag_name': '2.2.1',
          'assets': <Object>[],
        });
      },
      onFailure: (endpoint, _) => failures.add(endpoint.host),
    );

    final metadata = await loader.load();

    expect(metadata['tag_name'], '2.2.1');
    expect(attempts, [mirror, official]);
    expect(failures, ['mirror.example']);
  });

  test('falls back when a mirror returns malformed metadata', () async {
    final loader = UpdateReleaseMetadataLoader(
      endpoints: const [mirror, official],
      fetch: (endpoint) async => endpoint == mirror
          ? '{"message":"rate limited"}'
          : '{"tag_name":"2.2.1","assets":[]}',
    );

    expect((await loader.load())['tag_name'], '2.2.1');
  });

  test('does not contact a fallback after the primary response is valid',
      () async {
    var calls = 0;
    final loader = UpdateReleaseMetadataLoader(
      endpoints: const [mirror, official],
      fetch: (_) async {
        calls += 1;
        return '{"tag_name":"2.2.1","assets":[]}';
      },
    );

    await loader.load();

    expect(calls, 1);
  });

  test('rejects insecure metadata endpoints before a request', () async {
    var calls = 0;
    final loader = UpdateReleaseMetadataLoader(
      endpoints: const ['http://mirror.example/latest'],
      fetch: (_) async {
        calls += 1;
        return '{}';
      },
    );

    await expectLater(loader.load(), throwsFormatException);
    expect(calls, 0);
  });
}
