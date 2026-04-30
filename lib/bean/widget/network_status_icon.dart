import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkStatusIcon extends StatefulWidget {
  const NetworkStatusIcon({
    super.key,
    this.color = Colors.white,
    this.size = 18,
  });

  final Color color;
  final double size;

  @override
  State<NetworkStatusIcon> createState() => _NetworkStatusIconState();
}

class _NetworkStatusIconState extends State<NetworkStatusIcon> {
  late final Stream<List<ConnectivityResult>> _connectivityStream;

  @override
  void initState() {
    super.initState();
    _connectivityStream = Connectivity().onConnectivityChanged;
  }

  IconData _networkIconForResults(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) {
      return Icons.wifi_rounded;
    }
    if (results.contains(ConnectivityResult.ethernet)) {
      return Icons.cable;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return Icons.signal_cellular_alt;
    }
    return Icons.signal_wifi_off_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: _connectivityStream,
      initialData: const [ConnectivityResult.none],
      builder: (context, snapshot) {
        final results = snapshot.data ?? const [ConnectivityResult.none];
        return Icon(
          _networkIconForResults(results),
          color: widget.color,
          size: widget.size,
        );
      },
    );
  }
}
