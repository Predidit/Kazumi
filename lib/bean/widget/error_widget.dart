import 'package:flutter/material.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 2 / 3,
              ),
              child: Text(
                errMsg,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        if (actions != null)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: actions!,
          ),
      ],
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
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((_) {
          return Theme.of(context).colorScheme.primary.withAlpha(20);
        }),
      ),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
