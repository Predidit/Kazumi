import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/pages/player/controller/player_screenshot_controller.dart';

class PlayerScreenshotControls extends StatelessWidget {
  const PlayerScreenshotControls({
    super.key,
    required this.controller,
    required this.onCapture,
    required this.onReview,
  });
  final PlayerScreenshotController controller;
  final VoidCallback onCapture;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => Observer(
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '截取当前画面',
          style: IconButton.styleFrom(
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
          ),
          onPressed: controller.busy ? null : onCapture,
          icon: controller.capturing
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.photo_camera_outlined),
        ),
        if (controller.candidates.isNotEmpty)
          IconButton(
            tooltip: '挑选截图 · ${controller.candidates.length} 张',
            style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            onPressed: controller.saving ? null : onReview,
            icon: Badge.count(
              count: controller.candidates.length,
              child: const Icon(Icons.photo_library_outlined),
            ),
          ),
      ],
    ),
  );
}
