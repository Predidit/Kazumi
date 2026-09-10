import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/collect/collect_page.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';

final collectModule = createModule(
  path: '/collect',
  register: (c) {
    c.route(
      '/',
      transition: TransitionType.none,
      child: (context, state) => CollectPage(
        controller: inject<CollectController>(),
      ),
    );
  },
);
