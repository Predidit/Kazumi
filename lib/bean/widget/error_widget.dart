import 'package:flutter/material.dart';
import 'package:kazumi/design_system/kazumi_surfaces.dart';

class GeneralErrorWidget extends StatelessWidget {
  const GeneralErrorWidget({
    required this.errMsg,
    this.actions,
    super.key,
  });

  final String errMsg;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return KazumiStatePanel(
      kind: KazumiStateKind.error,
      title: '暂时无法加载',
      message: errMsg,
      actions: actions ?? const [],
    );
  }
}

class GeneralLoadingWidget extends StatelessWidget {
  const GeneralLoadingWidget({super.key, this.message = '正在加载'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return KazumiStatePanel(
      kind: KazumiStateKind.loading,
      title: message,
    );
  }
}

class GeneralEmptyWidget extends StatelessWidget {
  const GeneralEmptyWidget({
    super.key,
    this.title = '这里还没有内容',
    this.message,
    this.actions = const [],
  });

  final String title;
  final String? message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return KazumiStatePanel(
      kind: KazumiStateKind.empty,
      title: title,
      message: message,
      actions: actions,
    );
  }
}

class GeneralErrorButton extends StatelessWidget {
  const GeneralErrorButton({
    super.key,
    required this.onPressed,
    required this.text,
  });

  final Function() onPressed;
  final String text;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      child: Text(text),
    );
  }
}
