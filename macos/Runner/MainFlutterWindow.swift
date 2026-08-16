import Cocoa
import FlutterMacOS
import window_manager

// FlutterView accepts the first mouse event even when its window is inactive.
// This view lets AppKit activate the window without forwarding that event.
private final class InactiveMouseBlockerView: NSView {
  override func hitTest(_ point: NSPoint) -> NSView? {
    guard window?.isKeyWindow == false, bounds.contains(point) else {
      return nil
    }
    return self
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    return false
  }
}

class MainFlutterWindow: NSWindow {
  private let inactiveMouseBlocker = InactiveMouseBlockerView()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.backgroundColor = NSColor.clear
    flutterViewController.backgroundColor = NSColor.clear
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    if let contentView = self.contentView,
      let contentContainer = contentView.superview
    {
      inactiveMouseBlocker.translatesAutoresizingMaskIntoConstraints = false
      contentContainer.addSubview(
        inactiveMouseBlocker,
        positioned: .above,
        relativeTo: contentView
      )
      NSLayoutConstraint.activate([
        inactiveMouseBlocker.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        inactiveMouseBlocker.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        inactiveMouseBlocker.topAnchor.constraint(equalTo: contentView.topAnchor),
        inactiveMouseBlocker.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      ])
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
