import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.backgroundColor = NSColor.clear
    flutterViewController.backgroundColor = NSColor.clear
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }

  override func sendEvent(_ event: NSEvent) {
    if !isKeyWindow,
       event.type == .leftMouseDown || event.type == .rightMouseDown || event.type == .otherMouseDown,
       let contentView = self.contentView,
       let hit = contentView.superview?.hitTest(event.locationInWindow),
       hit == contentView || hit.isDescendant(of: contentView) {
      NSApp.activate(ignoringOtherApps: true)
      self.makeKeyAndOrderFront(nil)
      return
    }
    super.sendEvent(event)
  }
}
