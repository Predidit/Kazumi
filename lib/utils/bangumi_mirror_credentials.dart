// Bangumi mirror API credentials for the search signature flow.
// Release/PR CI injects them via --dart-define=KAZUMI_APPID / KAZUMI_KEY.
const Map<String, String> bangumiMirrorCredentials = {
  'id': String.fromEnvironment('KAZUMI_APPID'),
  'value': String.fromEnvironment('KAZUMI_KEY'),
};

/// 是否注入了镜像签名凭据。
///
/// 未注入时（本地或自建 CI 编译）签名必然无效，调用方应跳过签名并改用免签名镜像，
/// 否则镜像会以 401 invalid request signature 拒绝请求，搜索恒为空。
bool get hasBangumiMirrorCredentials =>
    (bangumiMirrorCredentials['id'] ?? '').isNotEmpty &&
    (bangumiMirrorCredentials['value'] ?? '').isNotEmpty;
