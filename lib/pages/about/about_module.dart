import 'package:flutter/material.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/pages/about/about_page.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/logs/logs_page.dart';

class AboutModule extends Module {
  @override
  void binds(i) {}

  @override
  void routes(r) {
    r.child("/", child: (_) => const AboutPage());
    r.child("/logs", child: (_) => const LogsPage());
    r.child(
      "/license",
      child: (_) => const LicensePage(
        applicationName: 'Akiora',
        applicationVersion: ApiEndpoints.version,
        applicationLegalese: 'Open source licenses',
      ),
    );
  }
}
