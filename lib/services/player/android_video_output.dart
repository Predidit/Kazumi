/// Resolves the Android video output while preserving explicit user choices.
/// TV defaults to MediaCodec's embedded Surface path to avoid copying every
/// decoded frame through Flutter's SurfaceTexture/GPU composition pipeline.
String selectAndroidVideoOutput({
  required String configuredOutput,
  required bool isTv,
  required int androidSdkVersion,
}) {
  if (configuredOutput != 'auto') return configuredOutput;
  if (isTv) return 'mediacodec_embed';
  return androidSdkVersion >= 34 ? 'gpu-next' : 'gpu';
}

bool usesAndroidDirectMediaCodecOutput({
  required String configuredOutput,
  required bool isTv,
}) {
  return configuredOutput == 'mediacodec_embed' ||
      (configuredOutput == 'auto' && isTv);
}
