import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/pages/settings/lan/lan_server_settings_page.dart';

class LanServerModule extends Module {
  @override
  void binds(i) {}

  @override
  void routes(r) {
    r.child("/", child: (_) => const LanServerSettingsPage());
  }
}
