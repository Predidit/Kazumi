import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/skip/skip_segment.dart';
import 'package:kazumi/repositories/skip_segment_repository.dart';

void main() {
  group('SkipSegmentRepository', () {
    test('saves, replaces, reads and deletes templates', () async {
      final store = _MemorySkipSegmentStore();
      final repository = SkipSegmentRepository(store: store);
      final opening = _template(
        type: SkipSegmentType.opening,
        start: const Duration(seconds: 30),
        end: const Duration(seconds: 120),
      );
      final replacedOpening = _template(
        type: SkipSegmentType.opening,
        start: const Duration(seconds: 35),
        end: const Duration(seconds: 125),
      );
      final ending = _template(
        type: SkipSegmentType.ending,
        start: const Duration(minutes: 21),
        end: const Duration(minutes: 22, seconds: 30),
      );

      await repository.saveTemplate(opening);
      await repository.saveTemplate(ending);
      await repository.saveTemplate(replacedOpening);

      expect(repository.getAllTemplates(), hasLength(2));
      expect(
        repository
            .getTemplate(
              bangumiId: 1,
              pluginName: 'test',
              type: SkipSegmentType.opening,
            )
            ?.start,
        const Duration(seconds: 35),
      );

      await repository.deleteTemplate(
        bangumiId: 1,
        pluginName: 'test',
        type: SkipSegmentType.opening,
      );

      expect(repository.getAllTemplates(), hasLength(1));
      expect(
        repository.getTemplate(
          bangumiId: 1,
          pluginName: 'test',
          type: SkipSegmentType.opening,
        ),
        isNull,
      );
      expect(
        repository.getTemplate(
          bangumiId: 1,
          pluginName: 'test',
          type: SkipSegmentType.ending,
        ),
        isNotNull,
      );
    });

    test('replaces templates across changing roads', () async {
      final store = _MemorySkipSegmentStore();
      final repository = SkipSegmentRepository(store: store);
      final road0 = _template(
        type: SkipSegmentType.opening,
        start: const Duration(seconds: 10),
        end: const Duration(seconds: 100),
        road: 0,
      );
      final road2 = _template(
        type: SkipSegmentType.opening,
        start: const Duration(seconds: 20),
        end: const Duration(seconds: 110),
        road: 2,
      );

      await repository.saveTemplate(road0);
      await repository.saveTemplate(road2);

      final restored = repository.getTemplate(
        bangumiId: 1,
        pluginName: 'test',
        type: SkipSegmentType.opening,
      );
      expect(repository.getAllTemplates(), hasLength(1));
      expect(restored?.road, 2);
      expect(restored?.start, const Duration(seconds: 20));
    });
  });
}

SkipSegmentTemplate _template({
  required SkipSegmentType type,
  required Duration start,
  required Duration end,
  int road = 0,
}) {
  return SkipSegmentTemplate(
    bangumiId: 1,
    pluginName: 'test',
    road: road,
    sourceEpisode: 2,
    type: type,
    start: start,
    end: end,
    createdAt: DateTime(2026),
  );
}

class _MemorySkipSegmentStore implements SkipSegmentKeyValueStore {
  final Map<String, Object?> values = {};

  @override
  Object? get(String key, {Object? defaultValue}) {
    return values[key] ?? defaultValue;
  }

  @override
  Future<void> put(String key, Object? value) async {
    values[key] = value;
  }
}
