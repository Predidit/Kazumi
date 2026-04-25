import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kazumi/modules/search/image_search_module.dart';
import 'package:kazumi/request/api.dart';

import 'request.dart';

class Trace {
  ///根据图片搜索番剧信息
  static Future<ImageSearchItem> searchAnimeByImageFile(File imageFile,
      {int anilistInfo = 2}) async {
    final bytes = await imageFile.readAsBytes();

    return await Request()
        .post(Api.traceApi,
            queryParameters: {
              'anilistInfo': anilistInfo,
            },
            data: bytes,
            options: Options(headers: {'Content-Type': 'image/jpeg'}))
        .then((onValue) =>
            ImageSearchItem.fromJson(onValue.data as Map<String, dynamic>));
  }

  ///根据图片URL搜索番剧信息
  static Future<ImageSearchItem> searchAnimeByImageUrl(String imageUrl,
      {int anilistInfo = 2}) async {
    return await Request()
        .post(Api.traceApi,
            queryParameters: {
              'anilistInfo': anilistInfo,
              'url': imageUrl,
            })
        .then((onValue) =>
            ImageSearchItem.fromJson(onValue.data as Map<String, dynamic>));
  }
}
