import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';

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
      body: GeneralErrorWidget(
        title: '无法打开页面',
        errMsg: message,
        actions: [
          StateActionButton(
            onPressed: () => context.navigate('/tab/popular/'),
            icon: Icons.home_outlined,
            text: '返回首页',
          ),
        ],
      ),
    );
  }
}
