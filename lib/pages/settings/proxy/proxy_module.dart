import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/settings/proxy/proxy_editor_page.dart';
import 'package:kazumi/pages/settings/proxy/proxy_settings_page.dart';

final proxyModule = createModule(
  path: '/proxy',
  register: (c) {
    c
      ..route('/', child: (context, state) => const ProxySettingsPage())
      ..route('/editor', child: (context, state) => const ProxyEditorPage());
  },
);
