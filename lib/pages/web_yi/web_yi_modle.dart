import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/web_yi/web_yi_controller.dart';
import 'web_yi_page.dart';

class WebYiModule extends Module {
  @override
  void routes(r) {
    r.child("/", child: (_) => WebYiPage());
  }


}
