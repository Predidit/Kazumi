import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final RegExp _embeddedVideoSourceRegExp = RegExp(
  r"""((?:https?:)?//[^\s'"<>]+?\.(?:m3u8|mp4)(?:[^\s'"<>]*)?)""",
  caseSensitive: false,
);

/// Extracts either a direct media URL or one nested inside a parser URL.
String? extractVideoSourceUrl(String source) {
  final nestedUrl = extractNestedVideoSourceUrl(source);
  if (nestedUrl != null) {
    return nestedUrl;
  }

  final rawUri = Uri.tryParse(source);
  if (rawUri != null) {
    if (_isDirectVideoSourceUri(rawUri)) {
      return rawUri.toString();
    }
  }

  final decodedSource = _decodeFullSafe(source);
  final decodedUri = Uri.tryParse(decodedSource);
  if (decodedUri != null) {
    if (_isDirectVideoSourceUri(decodedUri)) {
      return decodedUri.toString();
    }
  }

  return null;
}

/// Extracts only media URLs embedded inside another source/parser URL.
///
/// Direct media URLs intentionally return null so generic source-load events do
/// not preempt the dedicated media source handlers.
String? extractNestedVideoSourceUrl(String source) {
  final rawUri = Uri.tryParse(source);
  if (rawUri != null) {
    if (_isDirectVideoSourceUri(rawUri)) {
      return null;
    }
    final nestedUrl = _extractFromQueryParameters(rawUri);
    if (nestedUrl != null) {
      return nestedUrl;
    }
  }

  final decodedSource = _decodeFullSafe(source);
  final decodedUri = Uri.tryParse(decodedSource);
  if (decodedUri != null) {
    if (_isDirectVideoSourceUri(decodedUri)) {
      return null;
    }
    final nestedUrl = _extractFromQueryParameters(decodedUri);
    if (nestedUrl != null) {
      return nestedUrl;
    }
  }

  final match = _embeddedVideoSourceRegExp.firstMatch(decodedSource);
  final embeddedUrl = match?.group(1);
  if (embeddedUrl == null || !_isDirectVideoSourceUrl(embeddedUrl)) {
    return null;
  }
  final normalizedEmbeddedUrl = Uri.encodeFull(embeddedUrl);
  if (normalizedEmbeddedUrl == _normalizeDirectVideoSourceUrl(source) ||
      normalizedEmbeddedUrl == _normalizeDirectVideoSourceUrl(decodedSource)) {
    return null;
  }
  return normalizedEmbeddedUrl;
}

String decodeVideoSource(String iframeUrl) {
  return extractVideoSourceUrl(iframeUrl) ?? Uri.encodeFull(iframeUrl);
}

bool _isDirectVideoSourceUrl(String source) {
  final uri = Uri.tryParse(source);
  return uri != null && _isDirectVideoSourceUri(uri);
}

String? _normalizeDirectVideoSourceUrl(String source) {
  final uri = Uri.tryParse(source);
  if (uri == null || !_isDirectVideoSourceUri(uri)) {
    return null;
  }
  return uri.toString();
}

String? _extractFromQueryParameters(Uri uri) {
  for (final value in uri.queryParameters.values) {
    final decodedValue = _decodeFullSafe(value);
    if (_isDirectVideoSourceUrl(decodedValue)) {
      return Uri.encodeFull(decodedValue);
    }
  }
  return null;
}

String _decodeFullSafe(String value) {
  try {
    return Uri.decodeFull(value);
  } on FormatException {
    return value;
  } on ArgumentError {
    return value;
  }
}

bool _isDirectVideoSourceUri(Uri uri) {
  if (!uri.hasScheme && uri.host.isEmpty) {
    return false;
  }
  final path = uri.path.toLowerCase();
  return path.endsWith('.m3u8') || path.endsWith('.mp4');
}

int extractEpisodeNumber(String input) {
  final regExp = RegExp(r'第?(\d+)[话集]?');
  final match = regExp.firstMatch(input);

  if (match != null && match.group(1) != null) {
    return int.tryParse(match.group(1)!) ?? 0;
  }

  return 0;
}

Future<String> getPlayerTempPath() async {
  final directory = await getTemporaryDirectory();
  return directory.path;
}

String buildShadersAbsolutePath(String baseDirectory, List<String> shaders) {
  final absolutePaths = shaders.map((shader) {
    return path.join(baseDirectory, shader);
  }).toList();
  if (Platform.isWindows) {
    return absolutePaths.join(';');
  }
  return absolutePaths.join(':');
}
