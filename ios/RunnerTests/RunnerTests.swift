import CoreVideo
import Flutter
import UIKit
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testOnlyMediaKitRegistrarIsWrapped() throws {
    let original = TestPluginRegistry()
    let registry = KazumiPipPluginRegistry(registry: original) { _, _ in }

    XCTAssertTrue(registry.registrar(forPlugin: "OtherPlugin") === original.registrar)
    let video = try XCTUnwrap(registry.registrar(forPlugin: "MediaKitVideoPlugin"))
    XCTAssertFalse(video === original.registrar)
    XCTAssertTrue(video.messenger() === original.registrar.binaryMessenger)
    XCTAssertFalse(video.textures() === original.registrar.textureRegistry)
    XCTAssertTrue(registry.hasPlugin("MediaKitVideoPlugin"))

    let publication = NSObject()
    video.publish(publication)
    XCTAssertTrue(registry.valuePublished(byPlugin: "MediaKitVideoPlugin") === publication)
    XCTAssertEqual(video.lookupKey(forAsset: "poster.png"), "asset/poster.png")
    XCTAssertEqual(
      video.lookupKey(forAsset: "poster.png", fromPackage: "video"), "video/poster.png")
  }

  func testTextureFramesAreForwardedAndReleasedAfterUnregistration() throws {
    let releaseCount = PixelBufferReleaseCount()
    try autoreleasepool {
      let original = TestPluginRegistry()
      var events: [String] = []
      var lastFrame: CVPixelBuffer?
      let registry = KazumiPipPluginRegistry(registry: original) { buffer, textureID in
        XCTAssertEqual(textureID, 42)
        lastFrame = buffer
        events.append("frame")
      }
      original.registrar.textureRegistry.onFrameAvailable = { textureID in
        XCTAssertEqual(textureID, 42)
        events.append("flutter")
      }
      let video = try XCTUnwrap(registry.registrar(forPlugin: "MediaKitVideoPlugin"))
      var texture: TestTexture? = TestTexture(buffer: try makePixelBuffer(releaseCount))
      let textureID = video.textures().register(try XCTUnwrap(texture))

      video.textures().textureFrameAvailable(textureID)
      XCTAssertEqual(events, ["frame", "flutter"])
      XCTAssertTrue(lastFrame === texture?.buffer)
      var copiedFrame = registry.copyPixelBuffer(forTexture: textureID)
      XCTAssertTrue(copiedFrame === texture?.buffer)

      video.textures().unregisterTexture(textureID)
      XCTAssertNil(registry.copyPixelBuffer(forTexture: textureID))
      video.textures().textureFrameAvailable(textureID)
      XCTAssertEqual(events, ["frame", "flutter", "flutter"])
      XCTAssertEqual(original.registrar.textureRegistry.unregistered, [textureID])
      withExtendedLifetime((lastFrame, copiedFrame)) {
        texture = nil
        XCTAssertEqual(releaseCount.value, 0, "The two copied frames still own the buffer")
      }
      lastFrame = nil
      copiedFrame = nil
    }
    XCTAssertEqual(releaseCount.value, 1, "Each copy's retained reference must be consumed")
  }

  func testSoftwareTransitionPreservesLatestSizeAndCallbackOrder() throws {
    let original = TestPluginRegistry()
    let registry = KazumiPipPluginRegistry(registry: original) { _, _ in }
    let video = try XCTUnwrap(registry.registrar(forPlugin: "MediaKitVideoPlugin"))
    let plugin = TestVideoPlugin()
    video.addMethodCallDelegate(
      plugin,
      channel: FlutterMethodChannel(name: "test/video", binaryMessenger: video.messenger()))
    original.registrar.call("VideoOutputManager.Create", arguments: outputArguments)
    original.registrar.call(
      "VideoOutputManager.SetSize", arguments: ["handle": "7", "width": 1920, "height": 1080])

    var events: [String] = []
    plugin.onCall = { call in events.append(call.method) }
    registry.videoOutputWillChange = { handle, completion in
      XCTAssertEqual(handle, 7)
      events.append("will")
      completion(true)
    }
    registry.videoOutputDidChange = { handle, completion in
      XCTAssertEqual(handle, 7)
      events.append("did")
      completion(true)
    }
    registry.useSoftwareRendering(forHandle: 7) { ready in
      XCTAssertTrue(ready)
      events.append("complete")
    }

    XCTAssertEqual(
      events, ["will", "VideoOutputManager.Dispose", "VideoOutputManager.Create", "did", "complete"])
    let configuration = try XCTUnwrap(
      (plugin.calls.last?.arguments as? [String: Any])?["configuration"] as? [String: Any])
    XCTAssertEqual(configuration["enableHardwareAcceleration"] as? Bool, false)
    XCTAssertEqual(configuration["width"] as? Int, 1920)
    XCTAssertEqual(configuration["height"] as? Int, 1080)
  }

  func testRestorationWaitsForInFlightOutputAcknowledgement() throws {
    let original = TestPluginRegistry()
    let registry = KazumiPipPluginRegistry(registry: original) { _, _ in }
    let video = try XCTUnwrap(registry.registrar(forPlugin: "MediaKitVideoPlugin"))
    video.addMethodCallDelegate(
      TestVideoPlugin(),
      channel: FlutterMethodChannel(name: "test/video", binaryMessenger: video.messenger()))
    original.registrar.call("VideoOutputManager.Create", arguments: outputArguments)

    var suspendOutput: ((Bool) -> Void)?
    var acknowledgeOutput: ((Bool) -> Void)?
    registry.videoOutputWillChange = { _, completion in suspendOutput = completion }
    registry.videoOutputDidChange = { _, completion in acknowledgeOutput = completion }
    var entered = false
    registry.useSoftwareRendering(forHandle: 7) { entered = $0 }
    var restored = false
    registry.restoreRendering { restored = true }
    XCTAssertFalse(entered)
    XCTAssertFalse(restored)

    try XCTUnwrap(suspendOutput)(true)
    suspendOutput = nil
    XCTAssertFalse(restored, "Create's reply precedes the output-ready acknowledgement")
    try XCTUnwrap(acknowledgeOutput)(true)
    acknowledgeOutput = nil
    XCTAssertTrue(entered)
    XCTAssertTrue(restored)
  }

  private var outputArguments: [String: Any] {
    [
      "handle": "7",
      "configuration": ["enableHardwareAcceleration": true, "width": 640, "height": 360],
    ]
  }
}

private final class TestPluginRegistry: NSObject, FlutterPluginRegistry {
  let registrar = TestPluginRegistrar()
  private var registered: Set<String> = []

  func registrar(forPlugin pluginKey: String) -> FlutterPluginRegistrar? {
    registered.insert(pluginKey)
    return registrar
  }

  func hasPlugin(_ pluginKey: String) -> Bool { registered.contains(pluginKey) }
  func valuePublished(byPlugin pluginKey: String) -> NSObject? { registrar.published }
}

private final class TestPluginRegistrar: NSObject, FlutterPluginRegistrar {
  let binaryMessenger = TestBinaryMessenger()
  let textureRegistry = TestTextureRegistry()
  var published: NSObject?
  private var methodDelegate: FlutterPlugin?
  var viewController: UIViewController? { nil }

  func messenger() -> FlutterBinaryMessenger { binaryMessenger }
  func textures() -> FlutterTextureRegistry { textureRegistry }
  func publish(_ value: NSObject) { published = value }
  func addMethodCallDelegate(_ delegate: FlutterPlugin, channel: FlutterMethodChannel) {
    methodDelegate = delegate
  }
  func addApplicationDelegate(_ delegate: FlutterPlugin) {}
  func addSceneDelegate(_ delegate: FlutterSceneLifeCycleDelegate) {}
  func register(_ factory: FlutterPlatformViewFactory, withId factoryId: String) {}
  func register(
    _ factory: FlutterPlatformViewFactory, withId factoryId: String,
    gestureRecognizersBlockingPolicy policy: FlutterPlatformViewGestureRecognizersBlockingPolicy
  ) {}
  func lookupKey(forAsset asset: String) -> String { "asset/\(asset)" }
  func lookupKey(forAsset asset: String, fromPackage package: String) -> String { "\(package)/\(asset)" }
  func valuePublished(byPlugin pluginKey: String) -> NSObject? { published }

  func call(_ method: String, arguments: [String: Any]) {
    methodDelegate?.handle?(
      FlutterMethodCall(methodName: method, arguments: arguments), result: { _ in })
  }
}

private final class TestBinaryMessenger: NSObject, FlutterBinaryMessenger {
  func send(onChannel channel: String, message: Data?) {}
  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
    callback?(nil)
  }
  func setMessageHandlerOnChannel(
    _ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection { 1 }
  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}

private final class TestTextureRegistry: NSObject, FlutterTextureRegistry {
  var unregistered: [Int64] = []
  var onFrameAvailable: ((Int64) -> Void)?

  func register(_ texture: FlutterTexture) -> Int64 { 42 }
  func unregisterTexture(_ textureId: Int64) { unregistered.append(textureId) }
  func textureFrameAvailable(_ textureId: Int64) { onFrameAvailable?(textureId) }
}

private final class TestTexture: NSObject, FlutterTexture {
  let buffer: CVPixelBuffer
  init(buffer: CVPixelBuffer) { self.buffer = buffer }
  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? { .passRetained(buffer) }
}

private final class TestVideoPlugin: NSObject, FlutterPlugin {
  var calls: [FlutterMethodCall] = []
  var onCall: ((FlutterMethodCall) -> Void)?

  static func register(with registrar: FlutterPluginRegistrar) {}
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    calls.append(call)
    onCall?(call)
    result(nil)
  }
}

private final class PixelBufferReleaseCount {
  var value = 0
}

private func makePixelBuffer(_ releaseCount: PixelBufferReleaseCount) throws -> CVPixelBuffer {
  let bytes = UnsafeMutableRawPointer.allocate(byteCount: 16, alignment: 4)
  let context = Unmanaged.passRetained(releaseCount).toOpaque()
  var buffer: CVPixelBuffer?
  let status = CVPixelBufferCreateWithBytes(
    kCFAllocatorDefault, 2, 2, kCVPixelFormatType_32BGRA, bytes, 8,
    { context, bytes in
      guard let context else { return }
      Unmanaged<PixelBufferReleaseCount>.fromOpaque(context).takeRetainedValue().value += 1
      UnsafeMutableRawPointer(mutating: bytes)?.deallocate()
    }, context, nil, &buffer)
  if status != kCVReturnSuccess {
    Unmanaged<PixelBufferReleaseCount>.fromOpaque(context).release()
    bytes.deallocate()
  }
  return try XCTUnwrap(buffer, "CVPixelBufferCreateWithBytes failed: \(status)")
}
