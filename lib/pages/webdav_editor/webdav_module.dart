import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/webdav_editor/webdav_editor_page.dart';
import 'package:kazumi/pages/webdav_editor/webdav_setting.dart';

final webDavModule = createModule(
  path: '/webdav',
  register: (c) {
    c
      ..route('/', child: (context, state) => const WebDavSettingsPage())
      ..route('/editor', child: (context, state) => const WebDavEditorPage());
  },
);
