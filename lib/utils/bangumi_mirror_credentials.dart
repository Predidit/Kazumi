// Public Bangumi mirror API credentials used by the search signature flow.
// CI should replace these values for release builds.
const Map<String, String> bangumiMirrorCredentials = {
  'id': String.fromEnvironment('KAZUMI_APPID'),
  'value': String.fromEnvironment('KAZUMI_KEY'),
};
