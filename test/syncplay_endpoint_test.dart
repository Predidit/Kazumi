import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/syncplay_endpoint.dart';
import 'package:kazumi/services/storage/settings_keys.dart';

void main() {
  test('uses an official server as the default endpoint', () {
    expect(SettingsKeys.syncPlayEndPoint.defaultValue, defaultSyncPlayEndPoint);
    expect(officialSyncPlayEndPoints, contains(defaultSyncPlayEndPoint));
  });

  group('isOfficialSyncPlayEndPoint', () {
    test('recognizes every built-in official server', () {
      for (final endPoint in officialSyncPlayEndPoints) {
        expect(
          isOfficialSyncPlayEndPoint(parseSyncPlayEndPoint(endPoint)!),
          isTrue,
        );
      }
    });

    test('normalizes host casing and surrounding whitespace', () {
      expect(
        isOfficialSyncPlayEndPoint(
          parseSyncPlayEndPoint('  SYNCPLAY.PL:8996  ')!,
        ),
        isTrue,
      );
    });

    test('rejects custom hosts and ports', () {
      for (final endPoint in [
        'syncplay.example.com:8996',
        'syncplay.pl:9000',
        'localhost:8996',
      ]) {
        expect(
          isOfficialSyncPlayEndPoint(parseSyncPlayEndPoint(endPoint)!),
          isFalse,
        );
      }
    });
  });

  test('parseSyncPlayEndPoint rejects invalid endpoints', () {
    expect(parseSyncPlayEndPoint('syncplay.pl'), isNull);
    expect(parseSyncPlayEndPoint(''), isNull);
  });
}
