
import 'dart:io';

import 'package:kazumi/pages/web_yi/web_yi_controller_impel/web_yi_controller_impel.dart';
import 'package:kazumi/pages/web_yi/web_yi_controller_impel/web_yi_windows_controller_impel.dart';
import 'package:mobx/mobx.dart';

abstract class WebYiController<T> with Store{

  late final String url;

  late final T webviewController;

  Future<void> init();

  Future<void> loadUrl(String url);

  Future<void> unloadPage();

  Future<String> getHtml(String url, String htmlIdentifier );

  Future<String> getCookie(String url);

  void dispose() {}

}

class WebYiControllerFactory {
  static WebYiController getController() {
    if (Platform.isWindows) {
      return WebYiWindowsControllerImpel();
    }
    return WebYiControllerImpel();
  }
}