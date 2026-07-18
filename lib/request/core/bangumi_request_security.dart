class BangumiRequestSecurity {
  BangumiRequestSecurity._();

  static const trustedAuthorizationHosts = <String>{
    'api.bgm.tv',
    // This endpoint is the explicit, upstream-maintained auth/sync route.
    // It must never receive credentials for a non-authenticated request.
    'api.bgmapi.com',
  };

  static bool canAttachAccessToken({
    required String? url,
    required bool requiresAuth,
  }) {
    if (!requiresAuth || url == null) return false;
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        trustedAuthorizationHosts.contains(uri.host.toLowerCase());
  }

  static bool hasAuthorizationHeader(Map<String, dynamic> headers) {
    return headers.keys.any(
      (key) => key.toLowerCase() == 'authorization',
    );
  }

  static void removeAuthorizationHeaders(Map<String, dynamic> headers) {
    headers.removeWhere(
      (key, value) =>
          key.toLowerCase() == 'authorization' ||
          key.toLowerCase() == 'proxy-authorization',
    );
  }
}
