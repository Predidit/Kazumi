import CoreGraphics

#if canImport(Flutter)
  import Flutter
#elseif canImport(FlutterMacOS)
  import FlutterMacOS
#endif

public protocol ResizableTextureProtocol: NSObject, FlutterTexture {
  // Release the mpv render context before the player core is destroyed.
  func dispose()
  func resize(_ size: CGSize)
  func render(_ size: CGSize)
}
