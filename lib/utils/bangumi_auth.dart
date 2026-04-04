import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:kazumi/modules/bangumi/bangumi_auth_models.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/utils/bangumi_oauth.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';

class BangumiAuth {
  static const String _redirectUri = '${Api.bangumiIndex}dev/app';

  static const String _secureUsernameKey = 'bangumiSecureUsername';
  static const String _securePasswordKey = 'bangumiSecurePassword';
  static const String _secureAccessTokenKey = 'bangumiSecureAccessToken';
  static const String _secureRefreshTokenKey = 'bangumiSecureRefreshToken';
  static const String _secureTokenTypeKey = 'bangumiSecureTokenType';
  static const String _secureScopeKey = 'bangumiSecureScope';
  static const String _secureExpiresAtKey = 'bangumiSecureExpiresAt';

  static final FlutterSecureStorage _secureStorage =
      FlutterSecureStorage(iOptions: _secureIosOptions);

  static _BangumiLoginSession? _loginSession;

  static IOSOptions get _secureIosOptions =>
      const IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  static Box get _setting => GStorage.setting;

  static String get _appId => bangumiOAuth['appId']?.trim() ?? '';

  static String get _appSecret => bangumiOAuth['appSecret']?.trim() ?? '';

  static String get accessToken =>
      _setting.get(SettingBoxKey.bangumiAccessToken, defaultValue: '');

  static String get username =>
      _setting.get(SettingBoxKey.bangumiUsername, defaultValue: '');

  static String get nickname =>
      _setting.get(SettingBoxKey.bangumiNickname, defaultValue: '');

  static String get avatar =>
      _setting.get(SettingBoxKey.bangumiAvatar, defaultValue: '');

  static bool get isLoggedIn => accessToken.trim().isNotEmpty;

  static Future<String> get savedUsername async =>
      (await _secureStorage.read(key: _secureUsernameKey) ?? '').trim();

  static Future<bool> get hasSavedCredentials async {
    final storedUsername = await _secureStorage.read(key: _secureUsernameKey);
    final storedPassword = await _secureStorage.read(key: _securePasswordKey);
    return (storedUsername ?? '').trim().isNotEmpty &&
        (storedPassword ?? '').isNotEmpty;
  }

  static Future<void> saveToken(String token) async {
    final trimmed = token.trim();
    await _setting.put(SettingBoxKey.bangumiAccessToken, trimmed);
    await _secureStorage.write(key: _secureAccessTokenKey, value: trimmed);
  }

  static Future<void> saveUser(BangumiAuthUser user) async {
    await _setting.put(SettingBoxKey.bangumiUsername, user.username);
    await _setting.put(SettingBoxKey.bangumiNickname, user.nickname);
    await _setting.put(SettingBoxKey.bangumiAvatar, user.avatar);
  }

  static Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    await _secureStorage.write(
      key: _secureUsernameKey,
      value: username.trim(),
    );
    await _secureStorage.write(
      key: _securePasswordKey,
      value: password,
    );
  }

  static Future<void> clear() async {
    await _setting.put(SettingBoxKey.bangumiAccessToken, '');
    await _setting.put(SettingBoxKey.bangumiUsername, '');
    await _setting.put(SettingBoxKey.bangumiNickname, '');
    await _setting.put(SettingBoxKey.bangumiAvatar, '');
    await _secureStorage.delete(key: _secureAccessTokenKey);
    await _secureStorage.delete(key: _secureRefreshTokenKey);
    await _secureStorage.delete(key: _secureTokenTypeKey);
    await _secureStorage.delete(key: _secureScopeKey);
    await _secureStorage.delete(key: _secureExpiresAtKey);
  }

  static Future<void> logout() async {
    await clear();
    await _secureStorage.delete(key: _secureUsernameKey);
    await _secureStorage.delete(key: _securePasswordKey);
  }

  static Future<BangumiAuthUser> verifyAndSaveToken(String token) async {
    await saveToken(token);
    try {
      final user = await BangumiHTTP.getCurrentUser();
      await saveUser(user);
      return user;
    } catch (_) {
      await clear();
      rethrow;
    }
  }

  static Future<BangumiAuthUser> loginWithPassword({
    required String username,
    required String password,
    String captcha = '',
  }) async {
    _ensureOauthConfig();
    _loginSession ??= await _createLoginSession();
    final result = await _performInternalOauthLogin(
      username: username.trim(),
      password: password,
      captcha: captcha.trim(),
    );
    await saveCredentials(username: username, password: password);
    await _saveTokenBundle(result.token);
    await saveUser(result.user);
    _loginSession = null;
    return result.user;
  }

  static Future<BangumiCaptchaChallenge> loadCaptcha() async {
    _ensureOauthConfig();
    _loginSession = await _createLoginSession();
    return _fetchCaptcha(_loginSession!);
  }

  static Future<BangumiCaptchaChallenge> refreshCaptcha() async {
    _ensureOauthConfig();
    _loginSession ??= await _createLoginSession();
    return _fetchCaptcha(_loginSession!);
  }

  static Future<bool> tryAutoLogin() async {
    final storedUsername = await _secureStorage.read(key: _secureUsernameKey);
    final storedPassword = await _secureStorage.read(key: _securePasswordKey);
    final username = (storedUsername ?? '').trim();
    final password = storedPassword ?? '';

    try {
      final localToken = accessToken.trim();
      if (localToken.isNotEmpty) {
        await BangumiHTTP.getCurrentUser();
        return true;
      }
    } catch (_) {}

    try {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        return true;
      }
    } catch (_) {}

    if (username.isEmpty || password.isEmpty) {
      return false;
    }

    try {
      await loginWithPassword(username: username, password: password);
      return true;
    } catch (e) {
      debugPrint('Bangumi auto login failed: $e');
      await clear();
      return false;
    }
  }

  static Future<bool> _tryRefreshToken() async {
    _ensureOauthConfig();
    final refreshToken =
        (await _secureStorage.read(key: _secureRefreshTokenKey) ?? '').trim();
    if (refreshToken.isEmpty) {
      return false;
    }

    final response = await Request().post(
      '${Api.bangumiIndex}oauth/access_token',
      data: {
        'grant_type': 'refresh_token',
        'client_id': _appId,
        'client_secret': _appSecret,
        'refresh_token': refreshToken,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'user-agent': Utils.getRandomUA(),
        },
      ),
      shouldRethrow: true,
    );
    final token = BangumiOauthToken.fromJson(
      Map<String, dynamic>.from(response.data),
    );
    await _saveTokenBundle(token);
    final user = await BangumiHTTP.getCurrentUser();
    await saveUser(user);
    return true;
  }

  static Future<void> _saveTokenBundle(BangumiOauthToken token) async {
    await saveToken(token.accessToken);
    await _secureStorage.write(
      key: _secureRefreshTokenKey,
      value: token.refreshToken,
    );
    await _secureStorage.write(
      key: _secureTokenTypeKey,
      value: token.tokenType,
    );
    await _secureStorage.write(
      key: _secureScopeKey,
      value: token.scope,
    );
    await _secureStorage.write(
      key: _secureExpiresAtKey,
      value: token.expiresAt?.millisecondsSinceEpoch.toString() ?? '',
    );
  }

  static Future<_BangumiLoginResult> _performInternalOauthLogin({
    required String username,
    required String password,
    String captcha = '',
  }) async {
    _ensureOauthConfig();
    final session = _loginSession ?? await _createLoginSession();
    _loginSession = session;

    final loginResponse = await session.dio.post(
      '${Api.bangumiIndex}FollowTheRabbit',
      data: {
        'formhash': session.formhash,
        'referer': '',
        'dreferer': '',
        'email': username,
        'password': password,
        'captcha_challenge_field': captcha,
        'loginsubmit': '登录',
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'cookie': session.cookie,
        },
      ),
    );
    session.cookie = _mergeCookie(session.cookie, loginResponse.headers['set-cookie']);

    final loginResultHtml = (loginResponse.data ?? '').toString();
    if (loginResultHtml.contains('验证码') ||
        loginResultHtml.contains('captcha_challenge_field')) {
      if (captcha.isEmpty) {
        throw Exception('Bangumi 需要验证码，请填写验证码后重试');
      }
      throw Exception('Bangumi 验证码错误或已过期');
    }
    if (!_hasAuthCookie(session.cookie)) {
      throw Exception('Bangumi 账号或密码错误');
    }

    final authorizeUrl =
        '${Api.bangumiIndex}oauth/authorize?client_id=$_appId&response_type=code&redirect_uri=${Uri.encodeComponent(_redirectUri)}';
    final authorizePage = await session.dio.get(
      authorizeUrl,
      options: Options(headers: {'cookie': session.cookie}),
    );
    session.cookie = _mergeCookie(session.cookie, authorizePage.headers['set-cookie']);
    final authorizeHtml = (authorizePage.data ?? '').toString();
    final authorizeFormhash = _extractInputValue(authorizeHtml, 'formhash');
    if (authorizeFormhash.isEmpty) {
      throw Exception('Bangumi 授权页 formhash 获取失败');
    }

    final authorizeResult = await session.dio.post(
      authorizeUrl,
      data: {
        'formhash': authorizeFormhash,
        'redirect_uri': '',
        'client_id': _appId,
        'submit': '授权',
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'cookie': session.cookie},
      ),
    );
    final location =
        authorizeResult.headers.value('location') ?? _responseUrl(authorizeResult);
    final code = _extractCodeFromUrl(location);
    if (code.isEmpty) {
      throw Exception('Bangumi OAuth 授权码获取失败');
    }

    final tokenResponse = await Request().post(
      '${Api.bangumiIndex}oauth/access_token',
      data: {
        'grant_type': 'authorization_code',
        'client_id': _appId,
        'client_secret': _appSecret,
        'code': code,
        'redirect_uri': _redirectUri,
        'state': DateTime.now().millisecondsSinceEpoch.toString(),
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'user-agent': Utils.getRandomUA(),
        },
      ),
      shouldRethrow: true,
    );

    final token = BangumiOauthToken.fromJson(
      Map<String, dynamic>.from(tokenResponse.data),
    );
    final user = await BangumiHTTP.getCurrentUser();
    return _BangumiLoginResult(token: token, user: user);
  }

  static bool _hasAuthCookie(String cookie) {
    return cookie.contains('chii_auth=');
  }

  static String _extractCodeFromUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(url);
    return uri?.queryParameters['code']?.trim() ?? '';
  }

  static String _extractInputValue(String html, String name) {
    final document = html_parser.parse(html);
    final input = document.querySelector('input[name="$name"]');
    return input?.attributes['value']?.trim() ?? '';
  }

  static String _mergeCookie(String current, List<String>? setCookies) {
    final cookieMap = <String, String>{};
    if (current.trim().isNotEmpty) {
      for (final segment in current.split(';')) {
        final parts = segment.split('=');
        if (parts.length < 2) {
          continue;
        }
        final key = parts.first.trim();
        final value = parts.sublist(1).join('=').trim();
        if (key.isNotEmpty) {
          cookieMap[key] = value;
        }
      }
    }
    for (final raw in setCookies ?? const <String>[]) {
      final firstSegment = raw.split(';').first.trim();
      final index = firstSegment.indexOf('=');
      if (index <= 0) {
        continue;
      }
      final key = firstSegment.substring(0, index).trim();
      final value = firstSegment.substring(index + 1).trim();
      if (key.isNotEmpty) {
        cookieMap[key] = value;
      }
    }
    return cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  static String _responseUrl(Response<dynamic> response) {
    try {
      return response.realUri.toString();
    } catch (_) {
      return '';
    }
  }

  static void _ensureOauthConfig() {
    if (_appId.isEmpty ||
        _appSecret.isEmpty ||
        _appId == 'bangumi_app_id_placeholder' ||
        _appSecret == 'bangumi_app_secret_placeholder') {
      throw Exception('Bangumi OAuth 配置缺失，请在构建时注入 App ID 和 App Secret');
    }
  }

  static Future<_BangumiLoginSession> _createLoginSession() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: 12000),
        receiveTimeout: const Duration(milliseconds: 12000),
        followRedirects: false,
        validateStatus: (_) => true,
        responseType: ResponseType.plain,
        headers: {
          'user-agent': Utils.getRandomUA(),
          'referer': '',
        },
      ),
    );
    String cookie = '';
    final loginPage = await dio.get('${Api.bangumiIndex}login');
    cookie = _mergeCookie(cookie, loginPage.headers['set-cookie']);
    final loginHtml = (loginPage.data ?? '').toString();
    final loginFormhash = _extractInputValue(loginHtml, 'formhash');
    if (loginFormhash.isEmpty) {
      throw Exception('Bangumi 登录页 formhash 获取失败');
    }
    return _BangumiLoginSession(
      dio: dio,
      cookie: cookie,
      formhash: loginFormhash,
    );
  }

  static Future<BangumiCaptchaChallenge> _fetchCaptcha(
    _BangumiLoginSession session,
  ) async {
    final suffix =
        '${DateTime.now().millisecondsSinceEpoch}${1 + DateTime.now().millisecond % 6}';
    final response = await session.dio.get<List<int>>(
      '${Api.bangumiIndex}signup/captcha?$suffix',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'cookie': session.cookie},
      ),
    );
    session.cookie = _mergeCookie(session.cookie, response.headers['set-cookie']);
    final bytes = Uint8List.fromList(response.data ?? const <int>[]);
    if (bytes.isEmpty) {
      throw Exception('Bangumi 验证码加载失败');
    }
    return BangumiCaptchaChallenge(
      imageBytes: bytes,
      issuedAt: DateTime.now(),
    );
  }
}

class BangumiOauthToken {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final String scope;
  final int expiresIn;
  final DateTime? expiresAt;

  const BangumiOauthToken({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.scope,
    required this.expiresIn,
    required this.expiresAt,
  });

  factory BangumiOauthToken.fromJson(Map<String, dynamic> json) {
    final expiresIn = int.tryParse((json['expires_in'] ?? '0').toString()) ?? 0;
    return BangumiOauthToken(
      accessToken: (json['access_token'] ?? '').toString().trim(),
      refreshToken: (json['refresh_token'] ?? '').toString().trim(),
      tokenType: (json['token_type'] ?? 'Bearer').toString().trim(),
      scope: (json['scope'] ?? '').toString(),
      expiresIn: expiresIn,
      expiresAt: expiresIn > 0
          ? DateTime.now().add(Duration(seconds: expiresIn))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'scope': scope,
      'expires_in': expiresIn,
      'expires_at': expiresAt?.toIso8601String() ?? '',
    };
  }
}

class _BangumiLoginResult {
  final BangumiOauthToken token;
  final BangumiAuthUser user;

  const _BangumiLoginResult({
    required this.token,
    required this.user,
  });
}

class BangumiCaptchaChallenge {
  final Uint8List imageBytes;
  final DateTime issuedAt;

  const BangumiCaptchaChallenge({
    required this.imageBytes,
    required this.issuedAt,
  });
}

class _BangumiLoginSession {
  final Dio dio;
  final String formhash;
  String cookie;

  _BangumiLoginSession({
    required this.dio,
    required this.cookie,
    required this.formhash,
  });
}
