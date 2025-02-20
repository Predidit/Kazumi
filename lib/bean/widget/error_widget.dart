import 'package:flutter/material.dart';

class GeneralErrorWidget extends StatelessWidget {
  const GeneralErrorWidget(
      {required this.errMsg,
      this.fn,
      this.showButton = true,
      this.btnText,
      super.key});

  final String? errMsg;
  final bool showButton;
  final Function()? fn;
  final String? btnText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 30),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 2 / 3,
              ),
              child: Text(
                errMsg ?? '请求异常',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        showButton ? FilledButton.tonal(
          onPressed: fn,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              return Theme.of(context).colorScheme.primary.withAlpha(20);
            }),
          ),
          child: Text(
            btnText ?? '点击重试',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ) : Container(),
      ],
    );
  }
}
