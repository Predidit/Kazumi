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
    
    func findApplicationsByMimeType(mimeType: String) -> [URL] {
        
        let fileExtension = mimeType.components(separatedBy: "/").last ?? ""
        let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp.\(fileExtension)")
        
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
    
    private func openVideoWithMime(url: String, mimeType: String) {
        videoUrl = URL(string: url)
        
        let selectMenu = NSMenu()
        let appLists = findApplicationsByMimeType(mimeType: mimeType)
        
        /* AVPlayer menu item start */
        let menuItem = NSMenuItem()
        menuItem.attributedTitle = NSAttributedString(string: "AVPlayer", attributes: [.font: NSFont.systemFont(ofSize: 14)])
        menuItem.action = #selector(openWithAVPlayer)
        menuItem.toolTip = "macOS自带播放器，部分视频源有兼容问题"
        
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
            menuItem.action = #selector(openWithSelectedApp(_:))
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
