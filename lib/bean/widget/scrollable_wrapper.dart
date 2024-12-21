import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// 滚动容器
/// 支持鼠标滚轮滚动和拖动滚动
/// 传入ListView的scrollController
class ScrollableWrapper extends StatelessWidget {
  final Widget child;
  final ScrollController scrollController;

  const ScrollableWrapper({
    super.key,
    required this.child,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      child: Listener(
        onPointerSignal: (pointerSignal) {
          // 鼠标滚轮滚动
          if (pointerSignal is PointerScrollEvent &&
              scrollController.hasClients) {
            scrollController.position.moveTo(
              scrollController.offset + pointerSignal.scrollDelta.dy,
              curve: Curves.linear,
            );
          }
        },
        child: GestureDetector(
          onPanUpdate: (details) {
            // 拖动滚动
            if (scrollController.hasClients) {
              scrollController.position.moveTo(
                scrollController.offset - details.delta.dx,
                curve: Curves.linear,
              );
            }
          },
          child: child,
        ),
      ),
    );
  }
}
