import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/about/about_page.dart';
import 'package:kazumi/pages/logs/logs_page.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/request/config/api_endpoints.dart';

final aboutModule = createModule(
  path: '/about',
  register: (c) {
    c
      ..route(
        '/',
        child: (context, state) => AboutPage(
          controller: inject<MyController>(),
        ),
      )
      ..route('/logs', child: (context, state) => const LogsPage())
      ..route(
        '/license',
        child: (context, state) => const LicensePage(
          applicationName: 'Kazumi',
          applicationVersion: ApiEndpoints.version,
          applicationLegalese: '开源许可证',
        ),
      );
  },
);
