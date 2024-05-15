import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:mobx/mobx.dart';

part 'favorite_controller.g.dart';

class FavoriteController = _FavoriteController with _$FavoriteController;

abstract class _FavoriteController with Store {
  late var storedFavorites = GStorage.favorites;

  List<BangumiItem> get favorites => storedFavorites.values.toList();

  bool isFavorite(BangumiItem bangumiItem) {
    return !(storedFavorites.get(bangumiItem.id) == null);
  }

  void addFavorite(BangumiItem bangumiItem) {
    storedFavorites.put(bangumiItem.id, bangumiItem);
  }

  void deleteFavorite(BangumiItem bangumiItem) {
    storedFavorites.delete(bangumiItem.id);
  }
}