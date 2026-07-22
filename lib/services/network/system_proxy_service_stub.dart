class SystemProxyService {
  SystemProxyService._();

  static void init() {}
  static bool refresh() => false;
  static bool get isActive => false;
  static (String, int)? proxyFor(String scheme) => null;
  static String findProxy(Uri url) => 'DIRECT';
}
