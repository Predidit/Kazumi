import 'package:kazumi/pages/info/info_page.dart';
import 'package:flutter_modular/flutter_modular.dart';

class InfoModule extends Module {
  @override
  void routes(r) {
    r.child("/", child: (_) => const InfoPage());
  }
}
