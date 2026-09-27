import 'dart:convert';
import 'dart:math';

import 'package:hive_ce/hive.dart';
import 'package:kazumi/services/storage/storage.dart';

class LocalDanmakuBinding {
  const LocalDanmakuBinding({
    required this.episodeId,
    required this.anime,
    required this.episode,
  });
  final int episodeId;
  final String anime;
  final String episode;
  Map<String, dynamic> toMap() => {
    'id': episodeId,
    'anime': anime,
    'episode': episode,
  };
  factory LocalDanmakuBinding.fromMap(Map map) => LocalDanmakuBinding(
    episodeId: map['id'] as int,
    anime: map['anime'] as String,
    episode: map['episode'] as String,
  );
}

class LocalVideoReference {
  const LocalVideoReference({
    required this.source,
    required this.name,
    required this.location,
    required this.size,
    this.modifiedMs,
    this.bookmark,
    this.ownedPath,
  });
  final String source;
  final String name;
  final String location;
  final int size;
  final int? modifiedMs;
  final String? bookmark;
  final String? ownedPath;
  Map<String, dynamic> toMap() => {
    'source': source,
    'name': name,
    'location': location,
    'size': size,
    'modifiedMs': modifiedMs,
    'bookmark': bookmark,
    'ownedPath': ownedPath,
  };
  factory LocalVideoReference.fromMap(Map map) => LocalVideoReference(
    source: map['source'] as String,
    name: map['name'] as String,
    location: map['location'] as String,
    size: map['size'] as int,
    modifiedMs: map['modifiedMs'] as int?,
    bookmark: map['bookmark'] as String?,
    ownedPath: map['ownedPath'] as String?,
  );
}

class LocalVideoRecord {
  LocalVideoRecord({
    required this.id,
    required this.reference,
    this.positionMs = 0,
    this.durationMs = 0,
    this.completed = false,
    this.watchedMs = 0,
    this.binding,
  });
  factory LocalVideoRecord.create(LocalVideoReference reference) =>
      LocalVideoRecord(
        id: base64Url.encode(List.generate(16, (_) => _random.nextInt(256))),
        reference: reference,
      );
  static final _random = Random.secure();
  final String id;
  LocalVideoReference reference;
  int positionMs;
  int durationMs;
  bool completed;
  int watchedMs;
  LocalDanmakuBinding? binding;
  int get resumeMs => completed ? 0 : positionMs;
  Map<String, dynamic> toMap() => {
    'id': id,
    'reference': reference.toMap(),
    'positionMs': positionMs,
    'durationMs': durationMs,
    'completed': completed,
    'watchedMs': watchedMs,
    'binding': binding?.toMap(),
  };
  factory LocalVideoRecord.fromMap(Map map) => LocalVideoRecord(
    id: map['id'] as String,
    reference: LocalVideoReference.fromMap(map['reference'] as Map),
    positionMs: map['positionMs'] as int,
    durationMs: map['durationMs'] as int,
    completed: map['completed'] as bool,
    watchedMs: map['watchedMs'] as int,
    binding: map['binding'] == null
        ? null
        : LocalDanmakuBinding.fromMap(map['binding'] as Map),
  );
}

/// A separate box: local paths and progress never enter history or WebDAV.
class LocalVideoStore {
  LocalVideoStore(this.box);
  final Box<dynamic> box;
  static Future<LocalVideoStore>? _opening;
  static Future<LocalVideoStore> open() =>
      _opening ??= GStorage.openBoxSafe<dynamic>('localVideos')
          .then(LocalVideoStore.new)
          .catchError((Object error) {
            _opening = null;
            throw error;
          });
  final Map<String, Object> _owners = {};
  Future<void> _writes = Future<void>.value();
  List<LocalVideoRecord> get records =>
      box.values.map((value) => LocalVideoRecord.fromMap(value as Map)).toList()
        ..sort((a, b) => b.watchedMs.compareTo(a.watchedMs));
  LocalVideoRecord? findSource(String source) {
    for (final record in records) {
      if (record.reference.source == source) return record;
    }
    return null;
  }

  LocalVideoSession begin(LocalVideoRecord record) {
    final token = Object();
    _owners[record.id] = token;
    return LocalVideoSession._(
      this,
      LocalVideoRecord.fromMap(record.toMap()),
      token,
    );
  }

  Future<void> _enqueue(Future<void> Function() write) {
    final result = _writes.then((_) => write());
    _writes = result.catchError((Object _) {});
    return result;
  }

  Future<void> remove(String id) {
    _owners.remove(id);
    return _enqueue(() async {
      await box.delete(id);
      await box.flush();
    });
  }
}

class LocalVideoSession {
  LocalVideoSession._(this.store, this.record, this._token);
  final LocalVideoStore store;
  final LocalVideoRecord record;
  final Object _token;
  bool _playable = false;
  bool _closed = false;
  bool get active => !_closed && identical(store._owners[record.id], _token);
  void markPlayable() {
    if (active) _playable = true;
  }

  void close() {
    _closed = true;
  }

  Future<void> save({
    required int positionMs,
    required int durationMs,
    bool completed = false,
  }) async {
    if (!active || !_playable || durationMs <= 0 || positionMs < 0) return;
    record.positionMs = positionMs.clamp(0, durationMs);
    record.durationMs = durationMs;
    record.completed = completed;
    record.watchedMs = DateTime.now().millisecondsSinceEpoch;
    await _persist();
  }

  Future<bool> bind(LocalDanmakuBinding? binding, {bool Function()? canApply}) {
    bool current() => active && _playable && (canApply?.call() ?? true);
    if (!current()) return Future.value(false);
    var applied = false;
    return store
        ._enqueue(() async {
          if (!current()) return;
          final snapshot = record.toMap();
          try {
            await store.box.put(record.id, {
              ...snapshot,
              'binding': binding?.toMap(),
            });
            await store.box.flush();
            if (!current()) {
              await store.box.put(record.id, snapshot);
              await store.box.flush();
              return;
            }
            record.binding = binding;
            applied = true;
          } catch (_) {
            // Hive may have accepted the write before a flush failed. Preserve the
            // previous association in memory as well as on the next successful save.
            try {
              await store.box.put(record.id, snapshot);
            } catch (_) {}
            rethrow;
          }
        })
        .then((_) => applied);
  }

  Future<void> _persist() {
    final snapshot = record.toMap();
    return store._enqueue(() async {
      if (!identical(store._owners[record.id], _token)) return;
      snapshot['binding'] = record.binding?.toMap();
      await store.box.put(record.id, snapshot);
      await store.box.flush();
    });
  }
}
