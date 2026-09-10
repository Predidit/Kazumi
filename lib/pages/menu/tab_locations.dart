import 'package:kazumi/services/storage/storage.dart';

const tabLocations = [
  '/tab/popular',
  '/tab/timeline',
  '/tab/collect',
  '/tab/my',
];

String defaultTabLocation() {
  final stored = GStorage.getSetting(SettingsKeys.defaultStartupPage);
  final path = stored.replaceFirst(RegExp(r'/+$'), '');
  return tabLocations.contains(path) ? path : tabLocations.first;
}
