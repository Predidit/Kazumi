import 'dart:convert';

String jsonToKazumiBase64(String jsonStr) {
  final base64Str = base64Encode(utf8.encode(jsonStr));
  return 'kazumi://$base64Str';
}

String kazumiBase64ToJson(String kazumiBase64Str) {
  if (!kazumiBase64Str.startsWith('kazumi://')) {
    return '';
  }
  final base64Str = kazumiBase64Str.substring(9);
  return utf8.decode(base64.decode(base64Str));
}
