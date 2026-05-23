class SyncPlayEndPoint {
  final String host;
  final int port;

  const SyncPlayEndPoint({required this.host, required this.port});
}

SyncPlayEndPoint? parseSyncPlayEndPoint(String endPoint) {
  final input = endPoint.trim();
  if (input.isEmpty) {
    return null;
  }

  String host = '';
  String portStr = '';

  if (input.startsWith('[')) {
    final closeIndex = input.indexOf(']');
    if (closeIndex == -1) {
      return null;
    }
    host = input.substring(1, closeIndex);
    final rest = input.substring(closeIndex + 1);
    if (!rest.startsWith(':')) {
      return null;
    }
    portStr = rest.substring(1);
  } else {
    final lastColonIndex = input.lastIndexOf(':');
    if (lastColonIndex == -1) {
      return null;
    }
    host = input.substring(0, lastColonIndex);
    portStr = input.substring(lastColonIndex + 1);
  }

  host = host.trim();
  portStr = portStr.trim();
  if (host.isEmpty || portStr.isEmpty) {
    return null;
  }

  final port = int.tryParse(portStr);
  if (port == null || port <= 0 || port > 65535) {
    return null;
  }

  return SyncPlayEndPoint(host: host, port: port);
}
