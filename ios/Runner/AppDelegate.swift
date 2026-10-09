import UIKit
import Flutter
import AVKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var pipController: NSObject?
    private var pipPluginRegistry: KazumiPipPluginRegistry?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        if #available(iOS 15.0, *) {
            let pip = IosPictureInPictureController(messenger: engineBridge.applicationRegistrar.messenger())
            let registry = KazumiPipPluginRegistry(registry: engineBridge.pluginRegistry) {
                [weak pip] buffer, textureId in
                pip?.onVideoFrame(buffer, textureId: textureId)
            }
            pip.copyPixelBuffer = { [weak registry] textureId in
                registry?.copyPixelBuffer(forTexture: textureId)
            }
            pip.useSoftwareRendering = { [weak registry] handle, completion in
                guard let registry = registry else { completion(false); return }
                registry.useSoftwareRendering(forHandle: handle, completion: completion)
            }
            pip.restoreRendering = { [weak registry] completion in
                guard let registry = registry else { completion(); return }
                registry.restoreRendering(completion: completion)
            }
            registry.videoOutputWillChange = { [weak pip] handle, completion in
                guard let pip = pip else { completion(false); return }
                pip.videoOutputWillChange(handle, completion: completion)
            }
            registry.videoOutputDidChange = { [weak pip] handle, completion in
                guard let pip = pip else { completion(false); return }
                pip.videoOutputDidChange(handle, completion: completion)
            }
            pipController = pip
            pipPluginRegistry = registry
            GeneratedPluginRegistrant.register(with: registry)
        } else {
            GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
            let pipChannel = FlutterMethodChannel(name: "com.predidit.kazumi/ios_pip",
                                                  binaryMessenger: engineBridge.applicationRegistrar.messenger())
            pipChannel.setMethodCallHandler { _, result in result(false) }
        }

        let channel = FlutterMethodChannel(
            name: "com.predidit.kazumi/intent",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "openWithReferer" {
                guard let args = call.arguments else { return }
                if let myArgs = args as? [String: Any],
                   let url = myArgs["url"] as? String,
                   let referer = myArgs["referer"] as? String {
                    self?.openVideoWithReferer(url: url, referer: referer)
                }
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        let storageChannel = FlutterMethodChannel(
            name: "com.predidit.kazumi/storage",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        storageChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "getAvailableStorage" {
                do {
                    let attrs = try FileManager.default.attributesOfFileSystem(
                        forPath: NSHomeDirectory()
                    )
                    if let freeSize = attrs[.systemFreeSize] as? Int64 {
                        result(freeSize)
                    } else {
                        result(-1)
                    }
                } catch {
                    result(-1)
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // TODO: ADD VLC SUPPORT
    // VLC can be downloaded from iOS App Store, but don't know how to build selectable app lists, while checking if it is installled.
    // VLC supports more video formats than AVPlayer but does not support referer while AVPlayer does
    private func openVideoWithReferer(url: String, referer: String) {
        guard let videoUrl = URL(string: url) else { return }

        let headers: [String: String] = [
            "Referer": referer,
        ]
        let asset = AVURLAsset(url: videoUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.videoGravity = AVLayerVideoGravity.resizeAspect

        // Use UIScene API instead of deprecated keyWindow
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        rootViewController.present(playerViewController, animated: true) {
            playerViewController.player?.play()
        }

//        guard let appURL = URL(string: "vlc-x-callback://x-callback-url/stream?url=" + url) else {
//            return
//        }
//        if UIApplication.shared.canOpenURL(appURL) && referer.isEmpty {
//            UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
//        }
    }
}
