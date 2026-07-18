import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/sync/history_sync_path_policy.dart';

void main() {
  const validDeviceId = '123e4567-e89b-42d3-a456-426614174000';

  test('accepts canonical UUID device IDs and event filenames', () {
    expect(isValidHistorySyncDeviceId(validDeviceId), isTrue);
    expect(
      isValidHistorySyncEventFileName('$validDeviceId.jsonl'),
      isTrue,
    );
    expect(historySyncEventFileName(validDeviceId), '$validDeviceId.jsonl');
  });

  test('rejects traversal, separators, and non-device event names', () {
    for (final value in [
      '../snapshot.json.jsonl',
      r'..\snapshot.json.jsonl',
      '/absolute.jsonl',
      'device.jsonl',
      '$validDeviceId.jsonl.cache',
      '123e4567-e89b-02d3-a456-426614174000.jsonl',
    ]) {
      expect(
        isValidHistorySyncEventFileName(value),
        isFalse,
        reason: value,
      );
    }
  });

  test('refuses to construct a remote filename from an invalid device ID', () {
    expect(
      () => historySyncEventFileName('../snapshot'),
      throwsFormatException,
    );
  });
}
