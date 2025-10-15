import 'package:flutter/material.dart';

class TextDisplayWidget extends StatelessWidget {
  const TextDisplayWidget({super.key, required this.logLines});

  final List<String> logLines;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: logLines.length,
      itemBuilder: (context, index) {
        return Text(logLines[index]);
      },
    );
  }
}
