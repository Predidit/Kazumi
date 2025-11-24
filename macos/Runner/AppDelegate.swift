import Cocoa
import FlutterMacOS
import SwiftUI
import AVKit

@main
class AppDelegate: FlutterAppDelegate {
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    var playerView: AVPlayerView!
    var player: AVPlayer?
    var videoUrl: URL?
    var httpReferer: String = ""
    
    override func applicationDidFinishLaunching(_ notification: Notification) {
        setPlayerMenuEnabled(false)
        let controller : FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
        let channel = FlutterMethodChannel.init(name: "com.predidit.kazumi/intent", binaryMessenger: controller.engine.binaryMessenger)
        channel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method{
            case "openWithReferer":
                guard let args = call.arguments else { return }
                if let myArgs = args as? [String: Any],
                let url = myArgs["url"] as? String,
                let referer = myArgs["referer"] as? String {
                    self.openVideoWithReferer(url: url, referer: referer)
                }
                result(nil)
            case "enablePlayerMenu":
                self.setPlayerMenuEnabled(true)
                result(nil)
            case "disablePlayerMenu":
                self.setPlayerMenuEnabled(false)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
        }
        });
    }
    
    func findApplicationsByMimeType() -> [URL] {
        let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp.mp4")
        
        FileManager.default.createFile(atPath: tempFileURL.path, contents: nil, attributes: nil)
        
        if #available(macOS 12.0, *) {
            let listOfExternalApps = NSWorkspace.shared.urlsForApplications(toOpen: tempFileURL)
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                do {
                    try FileManager.default.removeItem(atPath: tempFileURL.path)
                } catch {
                    print("Delete error: \(error.localizedDescription)")
                }
            }
            return listOfExternalApps
        } else {
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                do {
                    try FileManager.default.removeItem(atPath: tempFileURL.path)
                } catch {
                    print("Delete error: \(error.localizedDescription)")
                }
            }
            return []
        }
    }
    
    private func openVideoWithReferer(url: String, referer: String) {
        videoUrl = URL(string: url)
        httpReferer = referer
        
        let selectMenu = NSMenu()
        let appLists = findApplicationsByMimeType()
        
        /* AVPlayer menu item start */
        let menuItem = NSMenuItem()
        menuItem.attributedTitle = NSAttributedString(string: "AVPlayer", attributes: [.font: NSFont.systemFont(ofSize: 14)])
        menuItem.action = #selector(openWithAVPlayer)
        
        let icon = NSWorkspace.shared.icon(forFile: "/System/Applications/Preview.app")
        icon.size = NSSize(width: 16, height: 16)
        menuItem.image = icon
        
        selectMenu.addItem(menuItem)
        /* AVPlayer menu item end */
        
        /* Applications menu item start */
        for appList in appLists {
            let appBundle = Bundle(url: appList)
            let appName = appBundle?.infoDictionary?["CFBundleName"] as? String ?? ""
            if appName == "QuickTime Player" || appName == "Books" {
                continue
            }
            
            let menuItem = NSMenuItem()
            menuItem.attributedTitle = NSAttributedString(string: "\(appName).app", attributes: [.font: NSFont.systemFont(ofSize: 14)])
            if appName == "VLC" {
                menuItem.action = #selector(openWithVLC(_:))
            } else {
                menuItem.action = #selector(openWithSelectedApp(_:))
            }
            menuItem.representedObject = "/Applications/\(appName).app/Contents/MacOS/\(appName)"
            
            let icon = NSWorkspace.shared.icon(forFile: "/Applications/\(appName).app")
            icon.size = NSSize(width: 16, height: 16)
            menuItem.image = icon

            selectMenu.addItem(menuItem)
        }
        /* Applications menu item end */
        
        selectMenu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @objc func openWithAVPlayer () {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 860),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        playerView = AVPlayerView(frame: window.contentView!.bounds)
        playerView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(playerView)
        window.delegate = self
        
        let headers: [String: String] = [
            "Referer": httpReferer,
        ]
        let asset = AVURLAsset(url: videoUrl!, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        playerView.player = player
        playerView.player?.play()
    }
    
    @objc func openWithSelectedApp (_ sender: NSMenuItem) {
        if !httpReferer.isEmpty {
            let alert = NSAlert()
            alert.messageText = "打开应用失败"
            alert.informativeText = "该应用不支持 Referer 请求头，打开失败。请使用 AVPlayer/VLC 打开或更换规则。"
            alert.runModal()
            return
        }
        if let selectedApp = sender.representedObject {
            let process = Process()
            process.launchPath = selectedApp as? String
            process.arguments = [videoUrl!.absoluteString]

            do {
                try process.run()
            } catch {
                print("Failed to open app: \(error)")
            }
        }
    }
    
    @objc func openWithVLC (_ sender: NSMenuItem) {
        if let selectedApp = sender.representedObject {
            let process = Process()
            process.launchPath = selectedApp as? String
            process.arguments = [videoUrl!.absoluteString, ":http-referrer=" + httpReferer]

            do {
                try process.run()
            } catch {
                print("Failed to open app: \(error)")
            }
        }
    }

    var isPlayerActive: Bool = false

    func sendToFlutter(_ command: String){
        guard
            let window = NSApp.mainWindow,
            let controller = window.contentViewController as? FlutterViewController
        else {
            print("Flutter controller not found.")
            return
        }
        let channel = FlutterMethodChannel(
            name: "macOS/player",
            binaryMessenger: controller.engine.binaryMessenger
        )
        channel.invokeMethod(command, arguments: nil)
    }
    @IBAction func menuPlayPause(_ sender: Any) { sendToFlutter("menuPlayPause") }
    @IBAction func menuNext(_ sender: Any) { sendToFlutter("menuNext") }
    @IBAction func menuPrevious(_ sender: Any) { sendToFlutter("menuPrevious") }
    @IBAction func menuForward(_ sender: Any) { sendToFlutter("menuForward") }
    @IBAction func menuRewind(_ sender: Any) { sendToFlutter("menuRewind") }
    @IBAction func menuVolumeUp(_ sender: Any) { sendToFlutter("menuVolumeUp") }
    @IBAction func menuVolumeDown(_ sender: Any) { sendToFlutter("menuVolumeDown") }
    @IBAction func menuToggleMute(_ sender: Any) { sendToFlutter("menuToggleMute") }
    @IBAction func menuToggleDanmaku(_ sender: Any) { sendToFlutter("menuToggleDanmaku") }
    @IBAction func menuSkip(_ sender: Any) { sendToFlutter("menuSkip") }
    @IBAction func menuSpeed1(_ sender: Any) { sendToFlutter("menuSpeed1") }
    @IBAction func menuSpeed2(_ sender: Any) { sendToFlutter("menuSpeed2") }
    @IBAction func menuSpeed3(_ sender: Any) { sendToFlutter("menuSpeed3") }
    @IBAction func menuSpeedUp(_ sender: Any) { sendToFlutter("menuSpeedUp") }
    @IBAction func menuSpeedDown(_ sender: Any) { sendToFlutter("menuSpeedDown") }


    func setPlayerMenuEnabled(_ enabled: Bool){
        if let playerMenuItem = NSApp.mainMenu?.items.first(where: { $0.identifier?.rawValue == "PlayerMenu" }) {
            playerMenuItem.isEnabled = enabled
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        player?.pause()
        player = nil
    }
}
