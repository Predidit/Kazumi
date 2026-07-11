import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/settings/host_api/host_api_settings_page.dart';

final hostApiModule = createModule(
  path: '/hostapi',
  register: (c) {
    c.route('/', child: (context, state) => const HostApiSettingsPage());
  },
);
