import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/timeline/timeline_page.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';

final timelineModule = createModule(
  path: '/timeline',
  register: (c) {
    c.route(
      '/',
      transition: TransitionType.none,
      child: (context, state) => TimelinePage(
        controller: inject<TimelineController>(),
      ),
    );
  },
);
