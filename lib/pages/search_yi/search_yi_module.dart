import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/search_yi/search_yi_page.dart';

class SearchYiModule extends Module {
  @override
  void routes(r) {
    r.child("/", child: (_) => const SearchYiPage());
  }
}
