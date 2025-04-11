import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/search/search_page.dart';

class SearchModule extends Module {
  @override
  void binds(i) {}

  @override
  void routes(r) {
    r.child("/:tag", child: (_) {
      return SearchPage(inputTag: r.args.params['tag']);
    });
  }
}
