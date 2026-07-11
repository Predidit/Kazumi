import 'dart:convert';

String jsonToKazumiBase64(String jsonStr) {
  final base64Str = base64Encode(utf8.encode(jsonStr));
  return 'kazumi://$base64Str';
}

String kazumiBase64ToJson(String kazumiBase64Str) {
  final input = kazumiBase64Str.trim();
  final schemeMatch = RegExp(
    r'^kazumi:(?://)?',
    caseSensitive: false,
  ).firstMatch(input);
  if (schemeMatch == null) {
    throw const FormatException('Invalid Kazumi rule link');
  }

  var payload = input.substring(schemeMatch.end);
  try {
    payload = Uri.decodeComponent(payload);
  } on FormatException {
    throw const FormatException('Invalid encoding in Kazumi rule link');
  }
  payload = payload.replaceAll(RegExp(r'\s'), '');
  if (payload.isEmpty) {
    throw const FormatException('Kazumi rule link is empty');
  }

  // Accept both standard and URL-safe Base64, with or without padding. Links
  // are frequently wrapped by chat applications or percent-encoded by URI
  // handlers before they reach the import dialog.
  final normalized = base64.normalize(
    payload.replaceAll('-', '+').replaceAll('_', '/'),
  );
  try {
    return utf8.decode(base64.decode(normalized));
  } on FormatException {
    throw const FormatException('Invalid Kazumi rule link payload');
  }
}
