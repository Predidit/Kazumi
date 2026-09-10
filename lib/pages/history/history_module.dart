import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/history/history_page.dart';
import 'package:kazumi/pages/history/history_controller.dart';

final historyModule = createModule(
  path: '/history',
  register: (c) {
    c.route(
      '/',
      child: (context, state) => HistoryPage(
        controller: inject<HistoryController>(),
      ),
    );
  },
);
