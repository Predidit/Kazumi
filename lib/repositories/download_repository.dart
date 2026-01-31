import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/utils/logger.dart';

abstract class IDownloadRepository {
  List<DownloadRecord> getAllRecords();
  DownloadRecord? getRecord(String key);
  Future<void> putRecord(DownloadRecord record);
  Future<void> deleteRecord(String key);
  Future<void> updateEpisode(String recordKey, int episodeNumber, DownloadEpisode episode);
  Future<void> deleteEpisode(String recordKey, int episodeNumber);
}

class DownloadRepository implements IDownloadRepository {
  final _downloadsBox = GStorage.downloads;

  @override
  List<DownloadRecord> getAllRecords() {
    try {
      return _downloadsBox.values.cast<DownloadRecord>().toList();
    } catch (e) {
      KazumiLogger().w('DownloadRepository: get all records failed', error: e);
      return [];
    }
  }

  @override
  DownloadRecord? getRecord(String key) {
    try {
      return _downloadsBox.get(key);
    } catch (e) {
      KazumiLogger().w('DownloadRepository: get record failed. key=$key', error: e);
      return null;
    }
  }

  @override
  Future<void> putRecord(DownloadRecord record) async {
    try {
      await _downloadsBox.put(record.key, record);
      await _downloadsBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'DownloadRepository: put record failed. key=${record.key}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteRecord(String key) async {
    try {
      await _downloadsBox.delete(key);
      await _downloadsBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'DownloadRepository: delete record failed. key=$key',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> updateEpisode(String recordKey, int episodeNumber, DownloadEpisode episode) async {
    try {
      final record = _downloadsBox.get(recordKey);
      if (record == null) return;
      record.episodes[episodeNumber] = episode;
      await _downloadsBox.put(recordKey, record);
      await _downloadsBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'DownloadRepository: update episode failed. key=$recordKey, ep=$episodeNumber',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteEpisode(String recordKey, int episodeNumber) async {
    try {
      final record = _downloadsBox.get(recordKey);
      if (record == null) return;
      record.episodes.remove(episodeNumber);
      if (record.episodes.isEmpty) {
        await _downloadsBox.delete(recordKey);
      } else {
        await _downloadsBox.put(recordKey, record);
      }
      await _downloadsBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'DownloadRepository: delete episode failed. key=$recordKey, ep=$episodeNumber',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
