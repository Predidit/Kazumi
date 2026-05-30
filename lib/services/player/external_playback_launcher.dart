import 'dart:io';

import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/services/player/external_player.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ExternalPlaybackLauncher {
  final String Function() videoUrl;
  final String Function() referer;

  ExternalPlaybackLauncher({
    required this.videoUrl,
    required this.referer,
  });

  Future<void> launch() async {
    final currentVideoUrl = videoUrl();
    final currentReferer = referer();
    if ((Platform.isAndroid || Platform.isWindows) && currentReferer.isEmpty) {
      if (await ExternalPlayer.launchURLWithMIME(
          currentVideoUrl, 'video/mp4')) {
        KazumiDialog.dismiss();
        KazumiDialog.showToast(
          message: 'Trying to launch external player',
        );
      } else {
        KazumiDialog.showToast(
          message: 'Failed to launch external player',
        );
      }
    } else if (Platform.isMacOS || Platform.isIOS) {
      if (await ExternalPlayer.launchURLWithReferer(
          currentVideoUrl, currentReferer)) {
        KazumiDialog.dismiss();
        KazumiDialog.showToast(
          message: 'Trying to launch external player',
        );
      } else {
        KazumiDialog.showToast(
          message: 'Failed to launch external player',
        );
      }
    } else if (Platform.isLinux && currentReferer.isEmpty) {
      KazumiDialog.dismiss();
      if (await canLaunchUrlString(currentVideoUrl)) {
        launchUrlString(currentVideoUrl);
        KazumiDialog.showToast(
          message: 'Trying to launch external player',
        );
      } else {
        KazumiDialog.showToast(
          message: 'Cannot use external player',
        );
      }
    } else {
      if (currentReferer.isEmpty) {
        KazumiDialog.showToast(
          message: 'This device is not supported yet',
        );
      } else {
        KazumiDialog.showToast(
          message: 'This rule is not supported yet',
        );
      }
    }
  }
}
