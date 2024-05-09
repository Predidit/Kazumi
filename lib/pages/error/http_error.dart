import 'package:flutter/material.dart';

class HttpError extends StatelessWidget {
  const HttpError(
      {required this.errMsg, required this.fn, this.btnText, super.key});

  final String? errMsg;
  final Function()? fn;
  final String? btnText;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            Text(
              errMsg ?? '请求异常',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: () {
                fn!();
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith((states) {
                  return Theme.of(context).colorScheme.primary.withAlpha(20);
                }),
              ),
              child: Text(
                btnText ?? '点击重试',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
