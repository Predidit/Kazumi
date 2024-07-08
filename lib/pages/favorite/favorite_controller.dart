import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';

part 'favorite_controller.g.dart';

class FavoriteController = _FavoriteController with _$FavoriteController;

abstract class _FavoriteController with Store {
  // late var storedFavorites = GStorage.favorites;
  Box setting = GStorage.setting;

  List<BangumiItem> get favorites => GStorage.favorites.values.toList();

  bool isFavorite(BangumiItem bangumiItem) {
    return !(GStorage.favorites.get(bangumiItem.id) == null);
  }

  Future addFavorite(BangumiItem bangumiItem) async {
    await GStorage.favorites.put(bangumiItem.id, bangumiItem);
    await GStorage.favorites.flush();
    bool webDavEnable = await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    bool webDavEnableFavorite = await setting.get(SettingBoxKey.webDavEnableFavorite, defaultValue: false);
    if (webDavEnable && webDavEnableFavorite) {
      try {
        await updateFavorite();
      } catch (e) {
        SmartDialog.showToast('更新webDav记录失败 ${e.toString()}');
      }
    }
  }

  Future deleteFavorite(BangumiItem bangumiItem) async {
    await GStorage.favorites.delete(bangumiItem.id);
    await GStorage.favorites.flush();
    bool webDavEnable = await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    bool webDavEnableFavorite = await setting.get(SettingBoxKey.webDavEnableFavorite, defaultValue: false);
    if (webDavEnable && webDavEnableFavorite) {
      try {
        await updateFavorite();
      } catch (e) {
        SmartDialog.showToast('更新webDav记录失败 ${e.toString()}');
      }
    }
  }

  Future updateFavorite() async{
    debugPrint('提交到WebDav的追番列表长度 ${GStorage.favorites.length}');
    await WebDav().updateFavorite();
  }
}
