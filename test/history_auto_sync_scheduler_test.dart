import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/sync/history_auto_sync_scheduler.dart';

void main() {
  group('HistoryAutoSyncScheduler', () {
    testWidgets('coalesces repeated history writes into one trailing sync',
        (tester) async {
      var syncCalls = 0;
      final scheduler = HistoryAutoSyncScheduler(
        isEnabled: () => true,
        sync: () async {
          syncCalls += 1;
        },
        debounce: const Duration(seconds: 10),
        maxWait: const Duration(minutes: 1),
      );

      scheduler.markDirty();
      scheduler.markDirty();
      scheduler.markDirty();

      await tester.pump(const Duration(seconds: 9));
      expect(syncCalls, 0);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(syncCalls, 1);
      expect(scheduler.hasPendingWork, isFalse);
      scheduler.dispose();
    });

    testWidgets('max wait syncs during continuous playback', (tester) async {
      var syncCalls = 0;
      final scheduler = HistoryAutoSyncScheduler(
        isEnabled: () => true,
        sync: () async {
          syncCalls += 1;
        },
        debounce: const Duration(seconds: 10),
        maxWait: const Duration(seconds: 30),
      );

      scheduler.markDirty();
      for (var i = 0; i < 3; i += 1) {
        await tester.pump(const Duration(seconds: 9));
        scheduler.markDirty();
      }
      expect(syncCalls, 0);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(syncCalls, 1);
      scheduler.dispose();
    });

    test('flush drains changes that arrive during an in-flight sync', () async {
      final firstSyncStarted = Completer<void>();
      final allowFirstSyncToFinish = Completer<void>();
      var syncCalls = 0;
      final scheduler = HistoryAutoSyncScheduler(
        isEnabled: () => true,
        sync: () async {
          syncCalls += 1;
          if (syncCalls == 1) {
            firstSyncStarted.complete();
            await allowFirstSyncToFinish.future;
          }
        },
      );

      scheduler.markDirty();
      final flush = scheduler.flush();
      await firstSyncStarted.future;
      scheduler.markDirty();
      allowFirstSyncToFinish.complete();
      await flush;

      expect(syncCalls, 2);
      expect(scheduler.hasPendingWork, isFalse);
      scheduler.dispose();
    });

    test('disabled scheduling neither starts timers nor flushes', () async {
      var syncCalls = 0;
      final scheduler = HistoryAutoSyncScheduler(
        isEnabled: () => false,
        sync: () async {
          syncCalls += 1;
        },
      );

      scheduler.markDirty();
      await scheduler.flush();

      expect(syncCalls, 0);
      expect(scheduler.hasPendingWork, isFalse);
      scheduler.dispose();
    });

    testWidgets('scheduled failures stay dirty and retry without timer leaks',
        (tester) async {
      var syncCalls = 0;
      var reportedErrors = 0;
      final scheduler = HistoryAutoSyncScheduler(
        isEnabled: () => true,
        sync: () async {
          syncCalls += 1;
          if (syncCalls == 1) {
            throw StateError('offline');
          }
        },
        onError: (_, __) => reportedErrors += 1,
        debounce: const Duration(seconds: 5),
        maxWait: const Duration(seconds: 20),
      );

      scheduler.markDirty();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(syncCalls, 1);
      expect(reportedErrors, 1);
      expect(scheduler.hasPendingWork, isTrue);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(syncCalls, 2);
      expect(scheduler.hasPendingWork, isFalse);
      scheduler.dispose();
    });

    test('flush propagates a failure but preserves work for a later retry',
        () async {
      var syncCalls = 0;
      final scheduler = HistoryAutoSyncScheduler(
        isEnabled: () => true,
        sync: () async {
          syncCalls += 1;
          if (syncCalls == 1) {
            throw StateError('offline');
          }
        },
      );

      scheduler.markDirty();
      await expectLater(scheduler.flush(), throwsStateError);
      expect(scheduler.hasPendingWork, isTrue);

      await scheduler.flush();
      expect(syncCalls, 2);
      expect(scheduler.hasPendingWork, isFalse);
      scheduler.dispose();
    });
  });
}
