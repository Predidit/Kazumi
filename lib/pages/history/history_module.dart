import 'package:kazumi/pages/history/history_page.dart';
import 'package:flutter_modular/flutter_modular.dart';

class HistoryModule extends Module {
  @override
  void routes(r) {
    r.child("/", child: (_) => const HistoryPage());
  }
}
