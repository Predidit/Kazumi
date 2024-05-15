import 'package:kazumi/pages/timeline/timeline_page.dart';
import 'package:flutter_modular/flutter_modular.dart';

class TimelineModule extends Module {
  @override
  void routes(r) {
    r.child("/", child: (_) => const TimelinePage());
  }
}
