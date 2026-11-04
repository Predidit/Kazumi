import CoreVideo
import Flutter
import UIKit
import XCTest
import media_kit_video
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

  func testMethodCallDelegateAndArgumentsAreForwardedUnchanged() throws {
    let original = TestPluginRegistry()
    let rendering = TestPipRendering()
    let registry = KazumiPipPluginRegistry(registry: original, rendering: rendering) { _, _ in }
    let video = try XCTUnwrap(registry.registrar(forPlugin: "MediaKitVideoPlugin"))
    let plugin = TestVideoPlugin()
    let channel = FlutterMethodChannel(name: "test/video", binaryMessenger: video.messenger())
    video.addMethodCallDelegate(plugin, channel: channel)

    XCTAssertTrue(original.registrar.methodDelegate === plugin)
    XCTAssertTrue(original.registrar.methodChannel === channel)
    let arguments: [String: Any] = [
      "handle": "7",
      "configuration": ["enableHardwareAcceleration": true, "width": 640, "height": 360],
    ]
    original.registrar.call("VideoOutputManager.Create", arguments: arguments)
    XCTAssertEqual(plugin.calls.count, 1)
    XCTAssertEqual(plugin.calls.first?.method, "VideoOutputManager.Create")
    XCTAssertEqual(plugin.calls.first?.arguments as? NSDictionary, arguments as NSDictionary)
    XCTAssertTrue(rendering.requests.isEmpty, "Normal method calls must not invoke the PiP renderer API")
  }

  func testSoftwareTransitionWaitsForSuspensionAndTextureAcknowledgement() throws {
    let rendering = TestPipRendering()
    let registry = KazumiPipPluginRegistry(
      registry: TestPluginRegistry(), rendering: rendering, isForeground: { true }
    ) { _, _ in }
    var events: [String] = []
    var suspend: ((Bool) -> Void)?
    var resume: ((Bool) -> Void)?
    registry.videoOutputWillChange = { handle, completion in
      XCTAssertEqual(handle, 7)
      events.append("suspend")
      suspend = completion
    }
    rendering.onRequest = { handle, enabled in
      XCTAssertEqual(handle, 7)
      XCTAssertTrue(enabled)
      events.append("render")
    }
    registry.videoOutputDidChange = { handle, waitForTexture, completion in
      XCTAssertEqual(handle, 7)
      XCTAssertTrue(waitForTexture)
      events.append("resume")
      resume = completion
    }
    registry.useSoftwareRendering(forHandle: 7) { ready in
      XCTAssertTrue(ready)
      events.append("complete")
    }

    XCTAssertEqual(events, ["suspend"])
    try XCTUnwrap(suspend)(true)
    suspend = nil
    XCTAssertEqual(events, ["suspend", "render"])
    try rendering.completeNext(.changed)
    XCTAssertEqual(events, ["suspend", "render", "resume"])
    try XCTUnwrap(resume)(true)
    resume = nil
    XCTAssertEqual(events, ["suspend", "render", "resume", "complete"])
  }

  func testRejectedSuspensionDoesNotChangeOutputOrResumeTrack() {
    let rendering = TestPipRendering()
    let registry = KazumiPipPluginRegistry(
      registry: TestPluginRegistry(), rendering: rendering, isForeground: { true }
    ) { _, _ in }
    registry.videoOutputWillChange = { _, completion in completion(false) }
    registry.videoOutputDidChange = { _, _, _ in XCTFail("No track was suspended") }
    var ready: Bool?
    registry.useSoftwareRendering(forHandle: 7) { ready = $0 }

    XCTAssertEqual(ready, false)
    XCTAssertTrue(rendering.requests.isEmpty)
  }

  func testUnchangedRenderingRestoresTrackWithoutWaitingForAnotherTexture() throws {
    try assertRenderingResultRestoresTrack(.unchanged, expectedReady: true)
  }

  func testFailedRenderingRestoresTrackWithoutWaitingForAnotherTexture() throws {
    try assertRenderingResultRestoresTrack(.failed, expectedReady: false)
  }

  private func assertRenderingResultRestoresTrack(
    _ result: VideoOutputRenderingResult, expectedReady: Bool
  ) throws {
    let rendering = TestPipRendering()
    let registry = KazumiPipPluginRegistry(
      registry: TestPluginRegistry(), rendering: rendering, isForeground: { true }
    ) { _, _ in }
    registry.videoOutputWillChange = { _, completion in completion(true) }
    var resume: ((Bool) -> Void)?
    registry.videoOutputDidChange = { handle, waitForTexture, completion in
      XCTAssertEqual(handle, 7)
      XCTAssertFalse(waitForTexture, "The texture ID remains unchanged")
      resume = completion
    }
    var ready: Bool?
    registry.useSoftwareRendering(forHandle: 7) { ready = $0 }
    try rendering.completeNext(result)
    XCTAssertNil(ready, "Even a failed transition must wait until the track is restored")
    try XCTUnwrap(resume)(true)
    resume = nil
    XCTAssertEqual(ready, expectedReady)
  }

  func testFailedTrackResumptionMakesChangedOutputNotReady() throws {
    let rendering = TestPipRendering()
    let registry = KazumiPipPluginRegistry(
      registry: TestPluginRegistry(), rendering: rendering, isForeground: { true }
    ) { _, _ in }
    registry.videoOutputWillChange = { _, completion in completion(true) }
    registry.videoOutputDidChange = { _, waitForTexture, completion in
      XCTAssertTrue(waitForTexture)
      completion(false)
    }
    var ready: Bool?
    registry.useSoftwareRendering(forHandle: 7) { ready = $0 }
    try rendering.completeNext(.changed)
    XCTAssertEqual(ready, false)
  }

  func testForegroundCloseDuringEntryWaitsForBothCompleteTransitions() throws {
    let rendering = TestPipRendering()
    let registry = KazumiPipPluginRegistry(
      registry: TestPluginRegistry(), rendering: rendering, isForeground: { true }
    ) { _, _ in }
    var events: [String] = []
    var suspend: ((Bool) -> Void)?
    var resume: ((Bool) -> Void)?
    registry.videoOutputWillChange = { _, completion in
      events.append("suspend")
      suspend = completion
    }
    rendering.onRequest = { _, enabled in events.append(enabled ? "software" : "hardware") }
    registry.videoOutputDidChange = { _, waitForTexture, completion in
      XCTAssertTrue(waitForTexture)
      events.append("resume")
      resume = completion
    }
    var entered = false
    registry.useSoftwareRendering(forHandle: 7) { ready in
      entered = ready
      events.append("entered")
    }
    var restored = false
    registry.restoreRendering {
      restored = true
      events.append("restored")
    }
    XCTAssertFalse(restored)

    try XCTUnwrap(suspend)(true)
    suspend = nil
    try rendering.completeNext(.changed)
    XCTAssertFalse(entered)
    XCTAssertFalse(restored)
    try XCTUnwrap(resume)(true)
    resume = nil
    XCTAssertTrue(entered)
    XCTAssertFalse(restored, "Closing must also wait for the queued foreground restoration")
    XCTAssertEqual(events, ["suspend", "software", "resume", "entered", "suspend"])

    try XCTUnwrap(suspend)(true)
    suspend = nil
    try rendering.completeNext(.changed)
    XCTAssertFalse(restored, "Hardware output acknowledgement must restore the track first")
    try XCTUnwrap(resume)(true)
    resume = nil
    XCTAssertTrue(restored)
    XCTAssertEqual(
      events, ["suspend", "software", "resume", "entered", "suspend", "hardware", "resume", "restored"])
    XCTAssertTrue(rendering.softwareRenderingHandles.isEmpty)
    XCTAssertEqual(rendering.newOutputOverrides.first, true)
    XCTAssertEqual(rendering.newOutputOverrides.last, false)
  }

  func testBackgroundCloseKeepsSoftwareOverrideUntilNextForeground() throws {
    let rendering = TestPipRendering()
    var foreground = true
    let registry = KazumiPipPluginRegistry(
      registry: TestPluginRegistry(), rendering: rendering, isForeground: { foreground }
    ) { _, _ in }
    registry.videoOutputWillChange = { _, completion in completion(true) }
    registry.videoOutputDidChange = { _, _, completion in completion(true) }
    registry.useSoftwareRendering(forHandle: 7) { XCTAssertTrue($0) }
    try rendering.completeNext(.changed)
    XCTAssertEqual(rendering.softwareRenderingHandles, [7])
    XCTAssertEqual(rendering.newOutputOverrides, [true])

    foreground = false
    var closed = false
    registry.restoreRendering { closed = true }
    XCTAssertTrue(closed, "Background close must not block waiting for the app to return")
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    XCTAssertTrue(rendering.pending.isEmpty)
    XCTAssertEqual(rendering.softwareRenderingHandles, [7])
    XCTAssertEqual(rendering.newOutputOverrides.last, true, "New outputs must still avoid GL in background")

    foreground = true
    NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)
    XCTAssertEqual(rendering.newOutputOverrides.last, false)
    XCTAssertEqual(rendering.pending.count, 1)
    XCTAssertEqual(rendering.pending.first?.handle, 7)
    XCTAssertEqual(rendering.pending.first?.enabled, false)
    try rendering.completeNext(.changed)
    XCTAssertTrue(rendering.softwareRenderingHandles.isEmpty)
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    XCTAssertTrue(rendering.pending.isEmpty, "Repeated activation must not recreate a restored output")
  }

  func testBackgroundDuringRestorationSuspensionDefersGpuUntilNextForeground() throws {
    let rendering = TestPipRendering()
    var foreground = true
    let registry = KazumiPipPluginRegistry(
      registry: TestPluginRegistry(), rendering: rendering, isForeground: { foreground }
    ) { _, _ in }
    registry.videoOutputWillChange = { _, completion in completion(true) }
    registry.videoOutputDidChange = { _, _, completion in completion(true) }
    registry.useSoftwareRendering(forHandle: 7) { XCTAssertTrue($0) }
    try rendering.completeNext(.changed)

    var suspend: ((Bool) -> Void)?
    var resume: ((Bool) -> Void)?
    var textureWaits: [Bool] = []
    registry.videoOutputWillChange = { _, completion in suspend = completion }
    registry.videoOutputDidChange = { _, waitForTexture, completion in
      textureWaits.append(waitForTexture)
      resume = completion
    }
    var closed = false
    registry.restoreRendering { closed = true }
    XCTAssertEqual(rendering.newOutputOverrides.last, false)
    XCTAssertFalse(closed)

    foreground = false
    NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    XCTAssertEqual(rendering.newOutputOverrides.last, true)
    try XCTUnwrap(suspend)(true)
    suspend = nil
    XCTAssertTrue(rendering.pending.isEmpty, "A late suspension must not authorize GPU work in background")
    XCTAssertEqual(rendering.requests.count, 1)
    XCTAssertEqual(textureWaits, [false])
    XCTAssertFalse(closed, "The suspended track must be restored before closing")
    try XCTUnwrap(resume)(true)
    resume = nil
    XCTAssertTrue(closed)
    XCTAssertEqual(rendering.softwareRenderingHandles, [7])

    foreground = true
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    XCTAssertEqual(rendering.newOutputOverrides.last, false)
    try XCTUnwrap(suspend)(true)
    suspend = nil
    XCTAssertEqual(rendering.pending.first?.enabled, false)
    try rendering.completeNext(.changed)
    XCTAssertEqual(textureWaits, [false, true])
    try XCTUnwrap(resume)(true)
    resume = nil
    XCTAssertTrue(rendering.softwareRenderingHandles.isEmpty)
  }

  func testForegroundActivationKeepsNewOutputsInSoftwareWhilePipIsActive() throws {
    let rendering = TestPipRendering()
    let registry = KazumiPipPluginRegistry(
      registry: TestPluginRegistry(), rendering: rendering, isForeground: { true }
    ) { _, _ in }
    registry.videoOutputWillChange = { _, completion in completion(true) }
    registry.videoOutputDidChange = { _, _, completion in completion(true) }
    registry.useSoftwareRendering(forHandle: 7) { XCTAssertTrue($0) }
    try rendering.completeNext(.changed)

    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)
    XCTAssertEqual(rendering.newOutputOverrides, [true])
    XCTAssertTrue(rendering.pending.isEmpty)
    XCTAssertEqual(rendering.softwareRenderingHandles, [7])
  }

  func testTextureRegistrationRetriesForegroundRestorationAfterBusyOutput() throws {
    let rendering = TestPipRendering()
    let registry = KazumiPipPluginRegistry(
      registry: TestPluginRegistry(), rendering: rendering, isForeground: { true }
    ) { _, _ in }
    let video = try XCTUnwrap(registry.registrar(forPlugin: "MediaKitVideoPlugin"))
    registry.videoOutputWillChange = { _, completion in completion(true) }
    registry.videoOutputDidChange = { _, _, completion in completion(true) }
    registry.useSoftwareRendering(forHandle: 7) { XCTAssertTrue($0) }
    try rendering.completeNext(.changed)

    var textureWaits: [Bool] = []
    registry.videoOutputDidChange = { _, waitForTexture, completion in
      textureWaits.append(waitForTexture)
      completion(true)
    }
    var closed = false
    registry.restoreRendering { closed = true }
    try rendering.completeNext(.notReady)
    XCTAssertTrue(closed)
    XCTAssertEqual(rendering.softwareRenderingHandles, [7])
    XCTAssertEqual(textureWaits, [false])

    let retried = expectation(description: "Retry after the new output registers its texture")
    var outputReady = false
    rendering.onRequest = { handle, enabled in
      XCTAssertEqual(handle, 7)
      XCTAssertFalse(enabled)
      XCTAssertTrue(outputReady, "Registration must return before retrying the initialized output")
      retried.fulfill()
    }
    let texture = TestTexture(buffer: try makePixelBuffer(PixelBufferReleaseCount()))
    let textureID = video.textures().register(texture)
    XCTAssertTrue(rendering.pending.isEmpty, "Do not retry synchronously inside texture registration")
    // The plugin finishes its initialization in the same main-thread turn.
    outputReady = true
    wait(for: [retried], timeout: 1)

    XCTAssertEqual(rendering.pending.count, 1)
    try rendering.completeNext(.changed)
    XCTAssertEqual(textureWaits, [false, true])
    XCTAssertTrue(rendering.softwareRenderingHandles.isEmpty)
    video.textures().unregisterTexture(textureID)
  }

  func testRegistrationBeforeBusyRestorationAcknowledgementStillRetries() throws {
    let rendering = TestPipRendering()
    let registry = KazumiPipPluginRegistry(
      registry: TestPluginRegistry(), rendering: rendering, isForeground: { true }
    ) { _, _ in }
    let video = try XCTUnwrap(registry.registrar(forPlugin: "MediaKitVideoPlugin"))
    registry.videoOutputWillChange = { _, completion in completion(true) }
    registry.videoOutputDidChange = { _, _, completion in completion(true) }
    registry.useSoftwareRendering(forHandle: 7) { XCTAssertTrue($0) }
    try rendering.completeNext(.changed)

    var resume: ((Bool) -> Void)?
    var textureWaits: [Bool] = []
    registry.videoOutputDidChange = { _, waitForTexture, completion in
      textureWaits.append(waitForTexture)
      resume = completion
    }
    var closed = false
    registry.restoreRendering { closed = true }
    try rendering.completeNext(.notReady)
    XCTAssertFalse(closed)
    XCTAssertEqual(textureWaits, [false])

    let texture = TestTexture(buffer: try makePixelBuffer(PixelBufferReleaseCount()))
    let textureID = video.textures().register(texture)
    let registrationDelivered = expectation(description: "Process the queued registration notification")
    DispatchQueue.main.async { registrationDelivered.fulfill() }
    wait(for: [registrationDelivered], timeout: 1)
    XCTAssertTrue(rendering.pending.isEmpty, "The first track restoration must finish before retrying")
    XCTAssertEqual(rendering.requests.count, 2)

    try XCTUnwrap(resume)(true)
    resume = nil
    XCTAssertFalse(closed, "The registration seen during acknowledgement must keep the retry in flight")
    XCTAssertEqual(rendering.pending.count, 1)
    XCTAssertEqual(rendering.pending.first?.enabled, false)
    try rendering.completeNext(.changed)
    XCTAssertEqual(textureWaits, [false, true])
    try XCTUnwrap(resume)(true)
    resume = nil
    XCTAssertTrue(closed)
    XCTAssertTrue(rendering.softwareRenderingHandles.isEmpty)
    video.textures().unregisterTexture(textureID)
  }

  func testTextureRegistrationDoesNotRetryFailedRestoration() throws {
    let rendering = TestPipRendering()
    let registry = KazumiPipPluginRegistry(
      registry: TestPluginRegistry(), rendering: rendering, isForeground: { true }
    ) { _, _ in }
    let video = try XCTUnwrap(registry.registrar(forPlugin: "MediaKitVideoPlugin"))
    registry.videoOutputWillChange = { _, completion in completion(true) }
    registry.videoOutputDidChange = { _, _, completion in completion(true) }
    registry.useSoftwareRendering(forHandle: 7) { XCTAssertTrue($0) }
    try rendering.completeNext(.changed)

    var closed = false
    registry.restoreRendering { closed = true }
    try rendering.completeNext(.failed)
    XCTAssertTrue(closed)
    XCTAssertEqual(rendering.softwareRenderingHandles, [7])
    XCTAssertEqual(rendering.requests.count, 2)

    let texture = TestTexture(buffer: try makePixelBuffer(PixelBufferReleaseCount()))
    let textureID = video.textures().register(texture)
    let registrationDelivered = expectation(description: "Process the queued registration notification")
    DispatchQueue.main.async { registrationDelivered.fulfill() }
    wait(for: [registrationDelivered], timeout: 1)
    XCTAssertTrue(rendering.pending.isEmpty, "A GPU failure must not restart on every replacement texture")
    XCTAssertEqual(rendering.requests.count, 2)
    XCTAssertEqual(rendering.softwareRenderingHandles, [7])
    video.textures().unregisterTexture(textureID)
  }

  func testRestorationWaitsForEverySoftwareOutput() throws {
    let rendering = TestPipRendering()
    let registry = KazumiPipPluginRegistry(
      registry: TestPluginRegistry(), rendering: rendering, isForeground: { true }
    ) { _, _ in }
    registry.videoOutputWillChange = { _, completion in completion(true) }
    registry.videoOutputDidChange = { _, _, completion in completion(true) }
    for handle: Int64 in [7, 9] {
      registry.useSoftwareRendering(forHandle: handle) { XCTAssertTrue($0) }
      try rendering.completeNext(.changed)
    }
    var restored = false
    registry.restoreRendering { restored = true }
    XCTAssertEqual(rendering.pending.map { $0.handle }, [7, 9])
    XCTAssertFalse(restored)
    try rendering.completeNext(.changed)
    XCTAssertFalse(restored)
    try rendering.completeNext(.changed)
    XCTAssertTrue(restored)
    XCTAssertTrue(rendering.softwareRenderingHandles.isEmpty)
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
  private(set) var methodDelegate: FlutterPlugin?
  private(set) var methodChannel: FlutterMethodChannel?
  var viewController: UIViewController? { nil }

  func messenger() -> FlutterBinaryMessenger { binaryMessenger }
  func textures() -> FlutterTextureRegistry { textureRegistry }
  func publish(_ value: NSObject) { published = value }
  func addMethodCallDelegate(_ delegate: FlutterPlugin, channel: FlutterMethodChannel) {
    methodDelegate = delegate
    methodChannel = channel
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

private final class TestPipRendering: KazumiPipRendering {
  struct Request {
    let handle: Int64
    let enabled: Bool
    let completion: (VideoOutputRenderingResult) -> Void
  }

  private var softwareHandles: Set<Int64> = []
  var softwareRenderingHandles: [Int64] { softwareHandles.sorted() }
  private(set) var newOutputOverrides: [Bool] = []
  private(set) var requests: [(handle: Int64, enabled: Bool)] = []
  private(set) var pending: [Request] = []
  var onRequest: ((Int64, Bool) -> Void)?

  func setSoftwareRenderingForNewOutputs(_ enabled: Bool) {
    newOutputOverrides.append(enabled)
  }

  func setSoftwareRendering(
    handle: Int64, enabled: Bool, completion: @escaping (VideoOutputRenderingResult) -> Void
  ) {
    let request = Request(handle: handle, enabled: enabled, completion: completion)
    requests.append((handle, enabled))
    pending.append(request)
    onRequest?(handle, enabled)
  }

  func completeNext(_ result: VideoOutputRenderingResult) throws {
    let request = try XCTUnwrap(pending.first, "Expected a renderer transition")
    pending.removeFirst()
    if result == .changed {
      if request.enabled {
        softwareHandles.insert(request.handle)
      } else {
        softwareHandles.remove(request.handle)
      }
    }
    request.completion(result)
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
