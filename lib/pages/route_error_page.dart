import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/widget/error_widget.dart';

class RouteErrorPage extends StatelessWidget {
  const RouteErrorPage({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SysAppBar(title: Text('Kazumi')),
      body: GeneralErrorWidget(
        errMsg: message,
        actions: [
          GeneralErrorButton(
            onPressed: () => context.navigate('/tab/popular/'),
            text: '返回首页',
          ),
        ],
      ),
    );
  }
}
