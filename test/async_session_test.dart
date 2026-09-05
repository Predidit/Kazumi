import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/async_session.dart';

void main() {
  group('AsyncSessionOwner', () {
    test('only the latest replaceable operation remains active', () {
      final owner = AsyncSessionOwner();
      final first = owner.begin();
      final second = owner.begin();

      expect(first.isStale, isTrue);
      expect(second.isActive, isTrue);

      owner.cancel();

      expect(second.isStale, isTrue);
      expect(owner.begin().isActive, isTrue);
    });

    test('close invalidates pending work and permanently rejects new work',
        () async {
      final owner = AsyncSessionOwner();
      final cleanup = Completer<void>();
      final session = owner.begin();
      var installedAfterCleanup = false;

      final initialization = () async {
        await cleanup.future;
        if (session.isStale) {
          return;
        }
        installedAfterCleanup = true;
      }();

      owner.close();
      cleanup.complete();
      await initialization;

      expect(session.isStale, isTrue);
      expect(installedAfterCleanup, isFalse);
      expect(owner.isClosed, isTrue);
      expect(owner.begin, throwsStateError);
    });
  });
}
