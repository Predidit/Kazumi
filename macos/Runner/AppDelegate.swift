import Cocoa
import FlutterMacOS
import SwiftUI
import AVKit

@main
class AppDelegate: FlutterAppDelegate {
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    var playerView: AVPlayerView!
    var player: AVPlayer?
    var videoUrl: URL?
    
    override func applicationDidFinishLaunching(_ notification: Notification) {
        let controller : FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
        let channel = FlutterMethodChannel.init(name: "com.predidit.kazumi/intent", binaryMessenger: controller.engine.binaryMessenger)
        channel.setMethodCallHandler({
            (_ call: FlutterMethodCall, _ result: FlutterResult) -> Void in
            if call.method == "openWithMime" {
                guard let args = call.arguments else { return }
                if let myArgs = args as? [String: Any],
                   let url = myArgs["url"] as? String,
                   let mimeType = myArgs["mimeType"] as? String {
                    self.openVideoWithMime(url: url, mimeType: mimeType)
                }
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        });
    }
    
    private func openVideoWithMime(url: String, mimeType: String) {
        videoUrl = URL(string: url)
        
        let selectMenu = NSMenu()
        
        /* AVPlayer menu item sample start */
        let menuItem = NSMenuItem()
        menuItem.attributedTitle = NSAttributedString(string: "AVPlayer", attributes: [.font: NSFont.systemFont(ofSize: 14)])
        menuItem.action = #selector(openWithAVPlayer)
        menuItem.toolTip = "macOS自带播放器，部分视频源有兼容问题"
        
        let icon = NSWorkspace.shared.icon(forFile: "/System/Applications/Preview.app")
        icon.size = NSSize(width: 16, height: 16)
        menuItem.image = icon
        
        selectMenu.addItem(menuItem)
        /* AVPlayer menu item sample end */
        
        /* IINA menu item start */
        if let iinaPath = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.colliderli.iina") {
            let menuItem = NSMenuItem()
            menuItem.attributedTitle = NSAttributedString(string: "IINA.app", attributes: [.font: NSFont.systemFont(ofSize: 14)])
            menuItem.action = #selector(openWithSelectedApp(_:))
            menuItem.representedObject = "/Applications/IINA.app/Contents/MacOS/IINA"
            
            let icon = NSWorkspace.shared.icon(forFile: "/Applications/IINA.app")
            icon.size = NSSize(width: 16, height: 16)
            menuItem.image = icon

            selectMenu.addItem(menuItem)
        }
        /* IINA menu item end */
        
        /* Add more app to menu item here start */

        /* Add more app to menu item here end */
        
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
        
        player = AVPlayer(url: videoUrl!)
        playerView.player = player
        playerView.player?.play()
    }
    
    @objc func openWithSelectedApp (_ sender: NSMenuItem) {
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
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        player?.pause()
        player = nil
    }
}
