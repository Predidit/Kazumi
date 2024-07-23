import 'package:html/parser.dart' show parse;
import 'package:flutter/material.dart' show debugPrint;
import 'dart:core';

// 弃用
class ParserWithoutWebview {
  static String extractM3U8Links(dynamic htmlContent) {
    debugPrint('开始解析 m3u8');
    var document = parse(htmlContent);
    // 匹配以http或https开头，后跟任意字符，然后是.m3u8的链接
    RegExp regExp = RegExp(r'(http[s]?://.*?\.m3u8)');
    // 匹配任何URL参数中的.m3u8链接
    RegExp paramRegExp = RegExp(r'(\?|\&)([^=]+)=([^&]*\.m3u8)');

    List<String> m3u8Urls = [];
    document.body!.querySelectorAll('*').forEach((element) {
      element.attributes.forEach((name, value) {
        var matches = regExp.allMatches(value);
        for (var match in matches) {
          var m3u8Url = match.group(0);
          if (m3u8Url!.contains('?')) {
            debugPrint('m3u8链接为URL参数');
            var paramMatches = paramRegExp.allMatches(m3u8Url);
            for (var paramMatch in paramMatches) {
              // 提取参数中的.m3u8链接
              var paramString = paramMatch.group(3);
              if (paramString != null && paramString.endsWith('.m3u8')) {
                m3u8Url = Uri.decodeComponent(paramString);
                m3u8Urls.add(m3u8Url);
              }
            }
          } else {
            m3u8Urls.add(m3u8Url);
          }
        }
      });
    });
    return m3u8Urls[0];
  }
  
  static String extractMP4Links(dynamic htmlContent) {
    var document = parse(htmlContent);
    // 匹配以http或https开头，后跟任意字符，然后是.mp4的链接
    RegExp regExp = RegExp(r'(http[s]?://.*?\.mp4)');
    // 匹配任何URL参数中的.mp4链接
    RegExp paramRegExp = RegExp(r'(\?|\&)([^=]+)=([^&]*\.mp4)');

    List<String> mp4Urls = [];
    document.body!.querySelectorAll('*').forEach((element) {
      element.attributes.forEach((name, value) {
        var matches = regExp.allMatches(value);
        for (var match in matches) {
          var mp4Url = match.group(0);
          // 检查.mp4链接是否为URL参数
          if (mp4Url!.contains('?')) {
            var paramMatches = paramRegExp.allMatches(mp4Url);
            for (var paramMatch in paramMatches) {
              // 提取参数中的.mp4链接
              var paramString = paramMatch.group(3);
              if (paramString != null && paramString.endsWith('.mp4')) {
                mp4Url = Uri.decodeComponent(paramString);
                mp4Urls.add(mp4Url);
              }
            }
          } else {
            mp4Urls.add(mp4Url);
          }
        }
      });
    });
    return mp4Urls[0];
  }
}
