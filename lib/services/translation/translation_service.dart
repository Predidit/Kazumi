import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';

/// Forces dynamic content (anime titles, summaries, etc.) coming from the
/// Bangumi API to English by machine-translating it on device.
///
/// Translations are cached both in memory and on disk (Hive) so each unique
/// string is only translated once. The underlying data model is never mutated,
/// translation happens only at display time via [TranslatedText].
class TranslationService {
  TranslationService._internal();
  static final TranslationService instance = TranslationService._internal();
  factory TranslationService() => instance;

  final Map<String, String> _memoryCache = {};
  final Map<String, Future<String?>> _inFlight = {};

  /// Matches CJK ideographs and Japanese kana - i.e. text that is not English.
  static final RegExp _nonLatin = RegExp(
      r'[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff66-\uff9f]');

  /// Whether the force-English feature is enabled (defaults to true).
  bool get enabled {
    try {
      return GStorage.setting
          .get(SettingBoxKey.forceEnglishTranslation, defaultValue: true);
    } catch (_) {
      return true;
    }
  }

  /// Returns true when [text] contains non-Latin characters worth translating.
  bool needsTranslation(String text) {
    if (text.isEmpty) return false;
    return _nonLatin.hasMatch(text);
  }

  /// Synchronously returns a cached translation if available, else null.
  String? cached(String text) {
    if (_memoryCache.containsKey(text)) return _memoryCache[text];
    try {
      final stored = GStorage.translationCache.get(text);
      if (stored != null) {
        _memoryCache[text] = stored;
        return stored;
      }
    } catch (_) {}
    return null;
  }

  /// Translates [text] to English. Returns the original text on failure so the
  /// UI never ends up empty. Results are cached.
  Future<String?> translateToEnglish(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !needsTranslation(trimmed)) return text;

    final hit = cached(trimmed);
    if (hit != null) return hit;

    if (_inFlight.containsKey(trimmed)) return _inFlight[trimmed];

    final future = _request(trimmed);
    _inFlight[trimmed] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(trimmed);
    }
  }

  Future<String?> _request(String text) async {
    try {
      final Dio dio = DioFactory.translateDio;
      final response = await dio.post(
        ApiEndpoints.translateApi,
        queryParameters: const {
          'client': 'gtx',
          'sl': 'auto',
          'tl': 'en',
          'dt': 't',
        },
        data: {'q': text},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );

      final translated = _parse(response.data);
      if (translated != null && translated.trim().isNotEmpty) {
        _memoryCache[text] = translated;
        try {
          await GStorage.translationCache.put(text, translated);
        } catch (_) {}
        return translated;
      }
    } catch (e) {
      KazumiLogger().w('Translation: failed to translate text', error: e);
    }
    return text;
  }

  /// The endpoint returns a nested JSON array:
  /// [[["translated","original",...], ...], null, "zh-CN", ...]
  String? _parse(dynamic data) {
    try {
      final decoded = data is String ? jsonDecode(data) : data;
      if (decoded is List && decoded.isNotEmpty && decoded[0] is List) {
        final buffer = StringBuffer();
        for (final segment in (decoded[0] as List)) {
          if (segment is List && segment.isNotEmpty && segment[0] is String) {
            buffer.write(segment[0] as String);
          }
        }
        final result = buffer.toString();
        return result.isEmpty ? null : result;
      }
    } catch (e) {
      KazumiLogger().w('Translation: failed to parse response', error: e);
    }
    return null;
  }
}
