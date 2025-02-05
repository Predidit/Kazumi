import 'package:kazumi/pages/collect/collect_page.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CollectModule extends Module {
  @override
  void routes(r) {
    r.child("/", child: (_) => const CollectPage());
  }
}
