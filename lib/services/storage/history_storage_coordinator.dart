import 'package:kazumi/utils/async_serial_queue.dart';

/// Serializes mutations to the history Hive box across repositories and sync.
class HistoryStorageCoordinator {
  HistoryStorageCoordinator._();

  static final HistoryStorageCoordinator _instance =
      HistoryStorageCoordinator._();

  factory HistoryStorageCoordinator() => _instance;

  final AsyncSerialQueue _writes = AsyncSerialQueue();

  Future<T> run<T>(Future<T> Function() action) => _writes.run(action);
}
