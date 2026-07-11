import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/my/my_page.dart';

final myModule = createModule(
  path: '/my',
  register: (c) {
    c.route(
      '/',
      transition: TransitionType.none,
      child: (context, state) => const MyPage(),
    );
  },
);
