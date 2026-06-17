import 'dart:math';

bool needUpdate(String localVersion, String remoteVersion) {
  final localVersionList = localVersion.split('.');
  final remoteVersionList = remoteVersion.split('.');
  final maxLength = max(localVersionList.length, remoteVersionList.length);
  for (var i = 0; i < maxLength; i++) {
    final localSegment =
        i < localVersionList.length ? int.parse(localVersionList[i]) : 0;
    final remoteSegment =
        i < remoteVersionList.length ? int.parse(remoteVersionList[i]) : 0;
    if (remoteSegment > localSegment) {
      return true;
    } else if (remoteSegment < localSegment) {
      return false;
    }
  }
  return false;
}
