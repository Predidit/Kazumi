import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/pages/settings/host_api/host_api_settings_page.dart';

class HostApiModule extends Module {
  @override
  void binds(i) {}

  @override
  void routes(r) {
    r.child("/", child: (_) => const HostApiSettingsPage());
  }
}
