import 'package:kazumi/pages/my/my_page.dart';
import 'package:flutter_modular/flutter_modular.dart';

class MyModule extends Module {
  @override
  void routes(r) {
    r.child("/", child: (_) => const MyPage());
  }
}
