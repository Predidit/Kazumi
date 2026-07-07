import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class RouteErrorPage extends StatelessWidget {
  const RouteErrorPage({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(title: Text('Kazumi')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.navigate('/tab/popular/'),
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
