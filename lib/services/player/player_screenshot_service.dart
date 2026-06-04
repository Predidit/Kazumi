import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:media_kit/media_kit.dart';

class PlayerScreenshotService {
  const PlayerScreenshotService();

  Future<Uint8List?> capturePng(Player player) async {
    final raw = await player.safeScreenshot(format: null);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final geometry = _ScreenshotGeometry.resolve(
      rawLength: raw.lengthInBytes,
      state: player.state,
    );
    if (geometry == null) {
      return null;
    }

    final request = _ScreenshotEncodeRequest(
      raw: TransferableTypedData.fromList([raw]),
      width: geometry.width,
      height: geometry.height,
      rowStride: geometry.rowStride,
    );
    final encoded = await Isolate.run(
      () => _encodeBgraToPng(request),
    );

    return encoded.materialize().asUint8List();
  }
}

class _ScreenshotGeometry {
  const _ScreenshotGeometry({
    required this.width,
    required this.height,
    required this.rowStride,
  });

  final int width;
  final int height;
  final int rowStride;

  static _ScreenshotGeometry? resolve({
    required int rawLength,
    required PlayerState state,
  }) {
    for (final candidate in _dimensionCandidates(state)) {
      final width = candidate.width;
      final height = candidate.height;
      if (width <= 0 || height <= 0) {
        continue;
      }
      if (rawLength % height != 0) {
        continue;
      }
      final rowStride = rawLength ~/ height;
      if (rowStride < width * 4) {
        continue;
      }
      return _ScreenshotGeometry(
        width: width,
        height: height,
        rowStride: rowStride,
      );
    }
    return null;
  }

  static Iterable<_ScreenshotDimensions> _dimensionCandidates(
    PlayerState state,
  ) sync* {
    final seen = <String>{};

    _ScreenshotDimensions? unique(int? width, int? height) {
      if (width == null || height == null || width <= 0 || height <= 0) {
        return null;
      }
      final key = '$width:$height';
      if (!seen.add(key)) {
        return null;
      }
      return _ScreenshotDimensions(width, height);
    }

    final params = state.videoParams;
    final rotate = params.rotate ?? 0;
    final rotated = rotate == 90 || rotate == 270;

    for (final candidate in [
      unique(state.width, state.height),
      unique(params.dw, params.dh),
      if (rotated) unique(params.dh, params.dw),
      unique(params.w, params.h),
      if (rotated) unique(params.h, params.w),
    ]) {
      if (candidate != null) {
        yield candidate;
      }
    }
  }
}

class _ScreenshotDimensions {
  const _ScreenshotDimensions(this.width, this.height);

  final int width;
  final int height;
}

class _ScreenshotEncodeRequest {
  const _ScreenshotEncodeRequest({
    required this.raw,
    required this.width,
    required this.height,
    required this.rowStride,
  });

  final TransferableTypedData raw;
  final int width;
  final int height;
  final int rowStride;
}

TransferableTypedData _encodeBgraToPng(_ScreenshotEncodeRequest request) {
  final raw = request.raw.materialize().asUint8List();
  final frame = image.Image.fromBytes(
    width: request.width,
    height: request.height,
    bytes: raw.buffer,
    bytesOffset: raw.offsetInBytes,
    numChannels: 4,
    rowStride: request.rowStride,
    order: image.ChannelOrder.bgra,
  );
  final png = Uint8List.fromList(image.encodePng(frame));
  return TransferableTypedData.fromList([png]);
}
