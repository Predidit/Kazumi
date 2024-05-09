import 'package:kazumi/pages/popular/popular_page.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PopularModule extends Module {
  @override
  void routes(r) {
    r.child("/", child: (_) => const PopularPage());
  }
}
