import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:kazumi/utils/bangumi_mirror_credentials.dart';
import 'package:kazumi/utils/dandan_credentials.dart';

String generateDandanSignature(String path, int timestamp) {
  final id = dandanCredentials['id']!;
  final value = dandanCredentials['value']!;
  final data = id + timestamp.toString() + path + value;
  final bytes = utf8.encode(data);
  final digest = sha256.convert(bytes);
  return base64Encode(digest.bytes);
}

String generateBangumiMirrorSearchSignature({
  required String method,
  required String path,
  required String body,
  required int timestamp,
}) {
  final id = bangumiMirrorCredentials['id']!;
  final value = bangumiMirrorCredentials['value']!;
  final bodyDigest = sha256.convert(utf8.encode(body)).toString();
  final data = id + timestamp.toString() + method + path + bodyDigest + value;
  final digest = sha256.convert(utf8.encode(data));
  return base64Encode(digest.bytes);
}

Future<String> calculateFileHash(File file) async {
  final bytes = await file.readAsBytes();
  final digest = sha256.convert(bytes);
  return digest.toString();
}
