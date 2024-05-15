import 'package:kazumi/pages/favorite/favorite_page.dart';
import 'package:flutter_modular/flutter_modular.dart';

class FavoriteModule extends Module {
  @override
  void routes(r) {
    r.child("/", child: (_) => const FavoritePage());
  }
}
