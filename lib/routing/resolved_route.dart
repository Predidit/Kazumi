import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/route_error_page.dart';
import 'package:kazumi/services/plugin/rule_engine_models.dart'
    show RuleCancelToken;

class ResolvedRoute<T> extends StatefulWidget {
  const ResolvedRoute({super.key, required this.load, required this.builder});

  final Future<T> Function(RuleCancelToken token) load;
  final Widget Function(T value) builder;

  @override
  State<ResolvedRoute<T>> createState() => _ResolvedRouteState<T>();
}

class _ResolvedRouteState<T> extends State<ResolvedRoute<T>> {
  final _token = RuleCancelToken();
  late Future<T> _result = widget.load(_token);

  @override
  void dispose() {
    _token.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _result,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error;
            return RouteErrorPage(
              message:
                  error is FormatException ? error.message : '加载失败，请检查网络后重试。',
              onRetry: () => setState(() {
                _result = widget.load(_token);
              }),
            );
          }
          if (snapshot.hasData) return widget.builder(snapshot.requireData);
          return const Scaffold(
            appBar: SysAppBar(title: Text('Kazumi')),
            body: Center(child: CircularProgressIndicator()),
          );
        },
      );
}
