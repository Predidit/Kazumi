import UIKit
import Flutter
import AVKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    private var localVideoAccess: LocalVideoAccess?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        localVideoAccess = LocalVideoAccess(messenger: engineBridge.applicationRegistrar.messenger())

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

/// The Files provider is scoped only while importing. Copies are streamed off
/// the UI thread into Application Support, never the purgeable picker cache.
private final class LocalVideoAccess: NSObject, UIDocumentPickerDelegate {
    private var pending: FlutterResult?
    private var picker: UIDocumentPickerViewController?
    private let lock = NSLock()
    private var generation = 0
    private let worker = DispatchQueue(label: "kazumi.local-video-import", qos: .userInitiated)
    init(messenger: FlutterBinaryMessenger) {
        super.init()
        let channel = FlutterMethodChannel(name: "com.predidit.kazumi/local_video", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { result(nil); return }
            switch call.method {
            case "pick":
                guard self.pending == nil else { result(FlutterError(code: "BUSY", message: "正在准备文件", details: nil)); return }
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      var presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                    result(FlutterError(code: "PICK", message: "无法打开文件选择器", details: nil)); return
                }
                while let presented = presenter.presentedViewController { presenter = presented }
                let picker = UIDocumentPickerViewController(documentTypes: ["public.movie", "public.video", "org.matroska.mkv"], in: .open)
                picker.allowsMultipleSelection = false
                picker.delegate = self
                self.pending = result
                self.picker = picker
                presenter.present(picker, animated: true)
            case "cancel":
                self.lock.lock(); self.generation += 1; self.lock.unlock()
                self.picker?.dismiss(animated: true)
                self.picker = nil
                self.pending?(nil); self.pending = nil
                result(nil)
            default: result(FlutterMethodNotImplemented)
            }
        }
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        guard controller === picker else { return }
        pending?(nil); pending = nil; picker = nil
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard controller === picker else { return }
        guard let source = urls.first, let result = pending else { return }
        picker = nil
        lock.lock(); let token = generation; lock.unlock()
        worker.async { [self] in
            var destination: URL?
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            func cancelled() -> Bool { lock.lock(); defer { lock.unlock() }; return token != generation }
            do {
                let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("local_videos", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let target = directory.appendingPathComponent(UUID().uuidString + "." + source.pathExtension)
                destination = target
                var copyingError: Error?
                var coordinationError: NSError?
                var bytes: Int64 = 0
                NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { readable in
                    do {
                        guard let input = InputStream(url: readable), let output = OutputStream(url: target, append: false) else { throw CocoaError(.fileReadUnknown) }
                        input.open(); output.open()
                        defer { input.close(); output.close() }
                        var buffer = [UInt8](repeating: 0, count: 1024 * 1024)
                        while !cancelled() {
                            let count = input.read(&buffer, maxLength: buffer.count)
                            if count < 0 { throw input.streamError ?? CocoaError(.fileReadUnknown) }
                            if count == 0 { break }
                            try buffer.withUnsafeBufferPointer { pointer in
                                var offset = 0
                                while offset < count {
                                    if cancelled() { throw CocoaError(.userCancelled) }
                                    let written = output.write(pointer.baseAddress!.advanced(by: offset), maxLength: count - offset)
                                    if written <= 0 { throw output.streamError ?? CocoaError(.fileWriteUnknown) }
                                    offset += written
                                }
                            }
                            bytes += Int64(count)
                        }
                    } catch { copyingError = error }
                }
                if let error = coordinationError { throw error }
                if let error = copyingError { throw error }
                if cancelled() { throw CocoaError(.userCancelled) }
                guard bytes > 0 else { throw CocoaError(.fileReadCorruptFile) }
                var excluded = target
                var values = URLResourceValues(); values.isExcludedFromBackup = true
                try excluded.setResourceValues(values)
                let attrs = try FileManager.default.attributesOfItem(atPath: source.path)
                let modifiedDate = attrs[.modificationDate] as? Date ?? Date()
                try FileManager.default.setAttributes([.modificationDate: modifiedDate], ofItemAtPath: target.path)
                // modifiedMs is left to Dart's stat() of the copy so later comparisons use one clock.
                let map: [String: Any] = ["source": source.absoluteString, "name": source.lastPathComponent, "location": "导入的视频", "size": bytes, "ownedPath": target.lastPathComponent]
                DispatchQueue.main.async {
                    if cancelled() { try? FileManager.default.removeItem(at: target); return }
                    self.pending = nil; result(map)
                }
            } catch {
                if let destination = destination { try? FileManager.default.removeItem(at: destination) }
                DispatchQueue.main.async {
                    if cancelled() { return }
                    self.pending = nil
                    result(FlutterError(code: "IMPORT", message: "导入失败，请检查文件访问权限及可用空间", details: nil))
                }
            }
        }
    }
}
