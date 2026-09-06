import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/about/about_page.dart';
import 'package:kazumi/pages/about/credits_page.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/request/config/api_endpoints.dart';

final aboutModule = createModule(
  path: '/about',
  register: (c) {
    c
      ..route(
        '/',
        child: (context, state) => AboutPage(
          onCheckUpdate: inject<MyController>().checkUpdate,
        ),
      )
      ..route('/credits', child: (context, state) => const CreditsPage())
      ..route(
        '/license',
        child: (context, state) => const LicensePage(
          applicationName: 'Kazumi',
          applicationVersion: ApiEndpoints.version,
          applicationLegalese: 'Kazumi · GNU General Public License v3.0',
        ),
      );
  },
);
