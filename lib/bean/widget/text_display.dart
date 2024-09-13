import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart'; 

class TextDisplayWidget extends StatefulWidget {
  const TextDisplayWidget({super.key});

  @override
  State<TextDisplayWidget> createState() => _TextDisplayWidgetState(); 
}

class _TextDisplayWidgetState extends State<TextDisplayWidget> {
  final VideoPageController videoPageController = Modular.get<VideoPageController>();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: videoPageController.logLines.length,
      itemBuilder: (context, index) {
        return Text(videoPageController.logLines[index]);
      },
    );
  }
}
