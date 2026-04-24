import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/skip/skip_segment.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';

abstract class ISkipSegmentRepository {
  List<SkipSegmentTemplate> getAllTemplates();

  SkipSegmentTemplate? getTemplate({
    required int bangumiId,
    required String pluginName,
    required SkipSegmentType type,
  });

  Future<void> saveTemplate(SkipSegmentTemplate template);

  Future<void> deleteTemplate({
    required int bangumiId,
    required String pluginName,
    required SkipSegmentType type,
  });
}

abstract class SkipSegmentKeyValueStore {
  Object? get(String key, {Object? defaultValue});

  Future<void> put(String key, Object? value);
}

class HiveSkipSegmentKeyValueStore implements SkipSegmentKeyValueStore {
  final Box<dynamic> box;

  const HiveSkipSegmentKeyValueStore(this.box);

  @override
  Object? get(String key, {Object? defaultValue}) {
    return box.get(key, defaultValue: defaultValue);
  }

  @override
  Future<void> put(String key, Object? value) {
    return box.put(key, value);
  }
}

class SkipSegmentRepository implements ISkipSegmentRepository {
  final SkipSegmentKeyValueStore _store;

  SkipSegmentRepository({
    Box<dynamic>? settingBox,
    SkipSegmentKeyValueStore? store,
  }) : _store = store ??
            HiveSkipSegmentKeyValueStore(settingBox ?? GStorage.setting);

  @override
  List<SkipSegmentTemplate> getAllTemplates() {
    final encoded = _store.get(
      SettingBoxKey.skipSegmentTemplates,
      defaultValue: '[]',
    );
    if (encoded is! String || encoded.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => SkipSegmentTemplate.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ))
          .toList();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'SkipSegmentRepository: failed to parse templates',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  @override
  SkipSegmentTemplate? getTemplate({
    required int bangumiId,
    required String pluginName,
    required SkipSegmentType type,
  }) {
    final key = SkipSegmentTemplate.keyOf(
      bangumiId: bangumiId,
      pluginName: pluginName,
      type: type,
    );
    for (final template in getAllTemplates()) {
      if (template.key == key) {
        return template;
      }
    }
    return null;
  }

  @override
  Future<void> saveTemplate(SkipSegmentTemplate template) async {
    template.validate();
    final templates = getAllTemplates()
        .where((item) => item.key != template.key)
        .toList()
      ..add(template);
    await _saveAll(templates);
  }

  @override
  Future<void> deleteTemplate({
    required int bangumiId,
    required String pluginName,
    required SkipSegmentType type,
  }) async {
    final key = SkipSegmentTemplate.keyOf(
      bangumiId: bangumiId,
      pluginName: pluginName,
      type: type,
    );
    final templates =
        getAllTemplates().where((template) => template.key != key).toList();
    await _saveAll(templates);
  }

  Future<void> _saveAll(List<SkipSegmentTemplate> templates) async {
    final encoded = jsonEncode(
      templates.map((template) => template.toJson()).toList(),
    );
    await _store.put(SettingBoxKey.skipSegmentTemplates, encoded);
  }
}
