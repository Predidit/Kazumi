import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_auth_models.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/utils/storage.dart';

class BangumiAuth {
  static Box get _setting => GStorage.setting;

  static String get accessToken =>
      _setting.get(SettingBoxKey.bangumiAccessToken, defaultValue: '');

  static String get username =>
      _setting.get(SettingBoxKey.bangumiUsername, defaultValue: '');

  static String get nickname =>
      _setting.get(SettingBoxKey.bangumiNickname, defaultValue: '');

  static String get avatar =>
      _setting.get(SettingBoxKey.bangumiAvatar, defaultValue: '');

  static bool get isLoggedIn => accessToken.trim().isNotEmpty;

  static Future<void> saveToken(String token) async {
    await _setting.put(SettingBoxKey.bangumiAccessToken, token.trim());
  }

  static Future<void> saveUser(BangumiAuthUser user) async {
    await _setting.put(SettingBoxKey.bangumiUsername, user.username);
    await _setting.put(SettingBoxKey.bangumiNickname, user.nickname);
    await _setting.put(SettingBoxKey.bangumiAvatar, user.avatar);
  }

  static Future<void> clear() async {
    await _setting.put(SettingBoxKey.bangumiAccessToken, '');
    await _setting.put(SettingBoxKey.bangumiUsername, '');
    await _setting.put(SettingBoxKey.bangumiNickname, '');
    await _setting.put(SettingBoxKey.bangumiAvatar, '');
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
}
