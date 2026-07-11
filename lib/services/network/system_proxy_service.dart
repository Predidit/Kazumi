import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/proxy_manager.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:win32/win32.dart';

/// Snapshot of the Windows system proxy configuration.
class SystemProxyState {
  const SystemProxyState({
    this.httpProxy,
    this.httpsProxy,
    this.bypassPatterns = const [],
    this.bypassLocal = false,
  });

  final (String, int)? httpProxy;
  final (String, int)? httpsProxy;
  final List<String> bypassPatterns;
  final bool bypassLocal;

  bool get hasProxy => httpProxy != null || httpsProxy != null;

  bool sameAs(SystemProxyState other) {
    if (httpProxy != other.httpProxy || httpsProxy != other.httpsProxy) {
      return false;
    }
    if (bypassLocal != other.bypassLocal) return false;
    if (bypassPatterns.length != other.bypassPatterns.length) return false;
    for (var i = 0; i < bypassPatterns.length; i++) {
      if (bypassPatterns[i] != other.bypassPatterns[i]) return false;
    }
    return true;
  }
}

/// Follows the WinINET system proxy on Windows, Chrome-style.
///
/// The registry snapshot lives in memory only and is never persisted, so the
/// app always starts from the actual system state. A background isolate
/// watches the registry key and refreshes the snapshot on change. Like
/// Chrome, an unreachable proxy endpoint surfaces as a network error rather
/// than silently falling back to a direct connection.
///
/// The in-app manual proxy takes precedence structurally: call sites only
/// install [findProxy] when no manual proxy is configured.
class SystemProxyService {
  SystemProxyService._();

  static const _regPath =
      r'Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  static SystemProxyState _state = const SystemProxyState();
  static bool _watcherStarted = false;
  static Timer? _debounce;

  /// Reads the registry synchronously and starts the change watcher.
  /// Windows only; call before `runApp` so the first requests see the
  /// correct state.
  static void init() {
    if (!Platform.isWindows) return;
    refresh();
    _startWatcher();
  }

  /// Re-reads the registry. Returns true when the effective proxy changed.
  static bool refresh() {
    if (!Platform.isWindows) return false;
    SystemProxyState newState;
    try {
      newState = _readFromRegistry();
    } catch (e) {
      KazumiLogger().w('Proxy: 读取系统代理配置失败 $e');
      newState = const SystemProxyState();
    }
    if (newState.sameAs(_state)) return false;
    _state = newState;
    final proxy = newState.httpProxy ?? newState.httpsProxy;
    KazumiLogger().i(proxy == null
        ? 'Proxy: 系统代理已移除，回到直连'
        : 'Proxy: 检测到系统代理 ${proxy.$1}:${proxy.$2}');
    return true;
  }

  static bool get isActive => Platform.isWindows && _state.hasProxy;

  /// Proxy for [scheme] ('http' or 'https'), for consumers that cannot use
  /// [findProxy] (e.g. mpv).
  static (String, int)? proxyFor(String scheme) {
    if (!isActive) return null;
    return scheme == 'https' ? _state.httpsProxy : _state.httpProxy;
  }

  /// PAC-style callback for `HttpClient.findProxy`. Evaluates the current
  /// snapshot per request; never throws.
  static String findProxy(Uri url) {
    try {
      if (!isActive) return 'DIRECT';
      final state = _state;
      if (shouldBypass(url, state)) return 'DIRECT';
      final proxy =
          url.scheme == 'https' ? state.httpsProxy : state.httpProxy;
      if (proxy == null) return 'DIRECT';
      return 'PROXY ${proxy.$1}:${proxy.$2}';
    } catch (_) {
      return 'DIRECT';
    }
  }

  // Pure parsing helpers, public for unit tests.

  /// Parses the registry `ProxyServer` value into (http, https) proxies.
  ///
  /// Accepts a single `host:port` (applies to both schemes) or a
  /// per-protocol list like `http=h:p;https=h:p;socks=h:p`. `http` and
  /// `https` fall back to each other; `ftp`/`socks` entries are ignored
  /// because `HttpClient` cannot use them.
  static ((String, int)?, (String, int)?) parseProxyServer(String raw) {
    raw = raw.trim();
    if (raw.isEmpty) return (null, null);

    if (!raw.contains('=')) {
      final parsed = parseHostPort(raw);
      return (parsed, parsed);
    }

    (String, int)? http;
    (String, int)? https;
    for (final entry in raw.split(';')) {
      final idx = entry.indexOf('=');
      if (idx <= 0) continue;
      final scheme = entry.substring(0, idx).trim().toLowerCase();
      final parsed = parseHostPort(entry.substring(idx + 1));
      if (parsed == null) continue;
      if (scheme == 'http') http = parsed;
      if (scheme == 'https') https = parsed;
    }
    return (http ?? https, https ?? http);
  }

  /// Parses `host:port`, tolerating a `scheme://` prefix and `[IPv6]:port`.
  static (String, int)? parseHostPort(String value) {
    value = value.trim();
    if (value.isEmpty) return null;

    final schemeIdx = value.indexOf('://');
    if (schemeIdx > 0) {
      value = value.substring(schemeIdx + 3);
    }

    // IPv6 literals contain colons; the port follows the last one.
    final colon = value.lastIndexOf(':');
    if (colon <= 0 || colon == value.length - 1) return null;

    var host = value.substring(0, colon);
    final port = int.tryParse(value.substring(colon + 1));
    if (port == null || port < 1 || port > 65535) return null;

    if (host.startsWith('[') && host.endsWith(']')) {
      host = host.substring(1, host.length - 1);
    }
    if (host.isEmpty) return null;
    return (host, port);
  }

  /// Parses the registry `ProxyOverride` (bypass) list into wildcard
  /// patterns and whether `<local>` is present.
  static (List<String>, bool) parseBypassList(String raw) {
    final patterns = <String>[];
    var bypassLocal = false;
    for (final part in raw.split(RegExp(r'[;,]'))) {
      var entry = part.trim().toLowerCase();
      if (entry.isEmpty) continue;
      if (entry == '<local>') {
        bypassLocal = true;
        continue;
      }
      final schemeIdx = entry.indexOf('://');
      if (schemeIdx > 0) {
        entry = entry.substring(schemeIdx + 3);
      }
      if (entry.isNotEmpty) patterns.add(entry);
    }
    return (patterns, bypassLocal);
  }

  /// Loopback hosts always bypass (as in Chrome); `<local>` matches dotless
  /// hostnames; patterns containing a `:port` match against `host:port`.
  static bool shouldBypass(Uri url, SystemProxyState state) {
    final host = url.host.toLowerCase();
    if (host.isEmpty) return true;
    if (_isLoopback(host)) return true;
    if (state.bypassLocal && !host.contains('.') && !host.contains(':')) {
      return true;
    }
    for (final pattern in state.bypassPatterns) {
      if (_matchesPattern(pattern, host, url.port)) return true;
    }
    return false;
  }

  static bool _isLoopback(String host) {
    if (host == 'localhost' || host == '::1') return true;
    return host.startsWith('127.');
  }

  static bool _matchesPattern(String pattern, String host, int port) {
    var target = host;
    final colon = pattern.lastIndexOf(':');
    if (colon > 0 && int.tryParse(pattern.substring(colon + 1)) != null) {
      target = '$host:$port';
    }
    final regex =
        RegExp('^${RegExp.escape(pattern).replaceAll(r'\*', '.*')}\$');
    return regex.hasMatch(target);
  }

  static SystemProxyState buildState(String proxyServer, String proxyOverride) {
    final (http, https) = parseProxyServer(proxyServer);
    final (patterns, bypassLocal) = parseBypassList(proxyOverride);
    return SystemProxyState(
      httpProxy: http,
      httpsProxy: https,
      bypassPatterns: patterns,
      bypassLocal: bypassLocal,
    );
  }

  static SystemProxyState _readFromRegistry() {
    return using((arena) {
      final subKey = _regPath.toNativeUtf16(allocator: arena);

      int? readDword(String name) {
        final valueName = name.toNativeUtf16(allocator: arena);
        final data = arena<Uint32>();
        final cbData = arena<Uint32>()..value = sizeOf<Uint32>();
        final status = RegGetValue(HKEY_CURRENT_USER, subKey, valueName,
            RRF_RT_REG_DWORD, nullptr, data, cbData);
        return status == ERROR_SUCCESS ? data.value : null;
      }

      String? readString(String name) {
        final valueName = name.toNativeUtf16(allocator: arena);
        final cbData = arena<Uint32>();
        var status = RegGetValue(HKEY_CURRENT_USER, subKey, valueName,
            RRF_RT_REG_SZ, nullptr, nullptr, cbData);
        if (status != ERROR_SUCCESS || cbData.value == 0) return null;
        final buffer = arena.allocate<Utf16>(cbData.value);
        status = RegGetValue(HKEY_CURRENT_USER, subKey, valueName,
            RRF_RT_REG_SZ, nullptr, buffer, cbData);
        return status == ERROR_SUCCESS ? buffer.toDartString() : null;
      }

      // WinINET semantics: ProxyEnable=0 means no proxy regardless of a
      // leftover ProxyServer value. PAC (AutoConfigURL) and WPAD are not
      // supported and are treated as no proxy.
      if ((readDword('ProxyEnable') ?? 0) == 0) {
        return const SystemProxyState();
      }
      return buildState(
        readString('ProxyServer') ?? '',
        readString('ProxyOverride') ?? '',
      );
    });
  }

  static void _startWatcher() {
    if (_watcherStarted) return;
    _watcherStarted = true;
    final port = ReceivePort();
    port.listen((_) => _onRegistryChanged());
    Isolate.spawn(
      _watchRegistry,
      port.sendPort,
      debugName: 'SystemProxyWatcher',
    ).then((_) {}, onError: (Object e) {
      KazumiLogger().w('Proxy: 系统代理监视启动失败 $e');
      port.close();
    });
  }

  static void _onRegistryChanged() {
    // Proxy tools write several registry values in a burst; debounce them
    // into a single refresh.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!refresh()) return;
      // A manual proxy overrides the system proxy, so clients need no rebuild.
      if (GStorage.getSetting(SettingsKeys.proxyEnable)) return;
      ProxyManager.applyProxy();
    });
  }

  /// Isolate entry: blocks on registry change notifications for the process
  /// lifetime and pings the main isolate on each change.
  static void _watchRegistry(SendPort sendPort) {
    using((arena) {
      final subKey = _regPath.toNativeUtf16(allocator: arena);
      final phKey = arena<IntPtr>();
      if (RegOpenKeyEx(HKEY_CURRENT_USER, subKey, 0, KEY_NOTIFY, phKey) !=
          ERROR_SUCCESS) {
        return;
      }
      final hKey = phKey.value;
      try {
        while (true) {
          final status = RegNotifyChangeKeyValue(
            hKey,
            TRUE,
            REG_NOTIFY_CHANGE_NAME | REG_NOTIFY_CHANGE_LAST_SET,
            NULL,
            FALSE,
          );
          if (status != ERROR_SUCCESS) break;
          sendPort.send(true);
        }
      } finally {
        RegCloseKey(hKey);
      }
    });
  }
}
