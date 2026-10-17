import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:kazumi/modules/danmaku/custom_danmaku_server_config.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';
import 'package:kazumi/services/logging/logger.dart';

/// 自定义弹幕服务器（danmu_api / LogVar 兼容）的 HTTP 客户端。
///
/// 响应结构与弹弹play v2 一致，直接复用 Kazumi 既有解析模型：
/// - search/episodes  -> DanmakuSearchResponse
/// - bangumi/{id}     -> DanmakuEpisodeResponse
/// - comment/{id}     -> {comments: DanmakuEntry}（p 为 时间,类型,颜色,[来源]）
///
/// 与弹弹play 的差异：
/// - 不支持 bgmtv 番剧 ID 映射，自动取弹幕需先经 match 接口按标题匹配 episodeId；
/// - commentId 由服务端内部分配，播放时按标题解析，手动选择分集时用列表返回的 ID。
class CustomDanmakuClient {
  CustomDanmakuClient._();

  static final CustomDanmakuClient instance = CustomDanmakuClient._();

  /// danmu_api 在缓存未命中时会实时抓取上游源，冷请求可能超过默认 12s
  /// 接收超时，这里单独放宽。
  static const Duration _receiveTimeout = Duration(seconds: 30);
  static const Duration _connectTimeout = Duration(seconds: 10);

  Dio get _dio => DioFactory.apiDio;

  Future<DanmakuSearchResponse> searchAnimes(String title) async {
    final base = CustomDanmakuServerConfig.baseUrl;
    if (base == null) {
      throw StateError('自定义弹幕服务器地址未配置或格式不正确');
    }
    final jsonData = await _get(
      '$base${ApiEndpoints.customDanmuAPISearchEpisodes}',
      queryParameters: {'anime': title, 'v2': 'true'},
    );
    return DanmakuSearchResponse.fromJson(_asJsonMap(jsonData));
  }

  Future<DanmakuEpisodeResponse> getEpisodes(int animeId) async {
    final base = CustomDanmakuServerConfig.baseUrl;
    if (base == null) {
      throw StateError('自定义弹幕服务器地址未配置或格式不正确');
    }
    final jsonData =
        await _get('$base${ApiEndpoints.customDanmuAPIBangumi}$animeId');
    return DanmakuEpisodeResponse.fromJson(_asJsonMap(jsonData));
  }

  Future<List<DanmakuEntry>> getComments(int episodeId) async {
    final base = CustomDanmakuServerConfig.baseUrl;
    if (base == null) {
      throw StateError('自定义弹幕服务器地址未配置或格式不正确');
    }
    final jsonData = await _get(
      '$base${ApiEndpoints.customDanmuAPIComment}$episodeId',
      queryParameters: {'format': 'json'},
    );
    final comments = _asJsonMap(jsonData)['comments'] as List?;
    if (comments == null || comments.isEmpty) {
      return const [];
    }
    // 单条弹幕格式异常不应中断整个列表，跳过坏数据。
    return [
      for (final comment in comments)
        if (comment is Map<String, dynamic> &&
            comment['p'] is String &&
            comment['m'] is String)
          DanmakuEntry.fromJson(comment),
    ];
  }

  /// 按标题匹配并解析 episodeId（danmu_api 的自动匹配接口）。
  ///
  /// danmu_api 的 matches 项除 episodeId 外还带有 animeTitle/episodeTitle
  /// (含平台来源标记, 如 【bahamut】第2集), 一并带回供弹幕来源标签
  /// 完整展示; 服务端未返回时为 null。
  Future<({int? episodeId, String? animeTitle, String? episodeTitle})>
      matchEpisodeId({required String fileName}) async {
    final base = CustomDanmakuServerConfig.baseUrl;
    if (base == null) {
      throw StateError('自定义弹幕服务器地址未配置或格式不正确');
    }
    final jsonData = await _post(
      '$base${ApiEndpoints.customDanmuAPIMatch}',
      data: {'fileName': fileName},
    );
    final map = _asJsonMap(jsonData);
    if (map['isMatched'] != true) {
      return (episodeId: null, animeTitle: null, episodeTitle: null);
    }
    final matches = map['matches'] as List?;
    if (matches == null || matches.isEmpty) {
      return (episodeId: null, animeTitle: null, episodeTitle: null);
    }
    final match = matches.first;
    if (match is! Map<String, dynamic>) {
      return (episodeId: null, animeTitle: null, episodeTitle: null);
    }
    final episodeId = match['episodeId'];
    return (
      episodeId: episodeId is int ? episodeId : null,
      animeTitle: match['animeTitle'] is String
          ? match['animeTitle'] as String
          : null,
      episodeTitle: match['episodeTitle'] is String
          ? match['episodeTitle'] as String
          : null,
    );
  }

  /// 轻量连通性测试，命中缓存列表接口即可，不触发任何源站抓取。
  Future<bool> testConnection() async {
    final base = CustomDanmakuServerConfig.baseUrl;
    if (base == null) {
      return false;
    }
    try {
      await _get('$base${ApiEndpoints.customDanmuAPICacheAnimes}');
      return true;
    } catch (e) {
      KazumiLogger().w('CustomDanmakuClient: connection test failed', error: e);
      return false;
    }
  }

  /// 将响应数据安全转为 JSON Map。
  /// dio 在 content-type 不是 application/json 时会返回 String, 手动解码;
  /// 无法解析时抛出, 由调用方的错误分支统一处理。
  static Map<String, dynamic> _asJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    }
    throw StateError('自定义弹幕服务器返回了无法解析的数据');
  }

  Future<dynamic> _get(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        url,
        queryParameters: queryParameters,
        options: Options(
          connectTimeout: _connectTimeout,
          receiveTimeout: _receiveTimeout,
          headers: const {'referer': ''},
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  Future<dynamic> _post(String url, {required Map<String, dynamic> data}) async {
    try {
      final response = await _dio.post<dynamic>(
        url,
        data: data,
        options: Options(
          connectTimeout: _connectTimeout,
          receiveTimeout: _receiveTimeout,
          headers: const {'referer': ''},
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }
}
