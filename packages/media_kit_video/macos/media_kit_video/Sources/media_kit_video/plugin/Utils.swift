import FlutterMacOS

public class Utils: NSObject, UtilsProtocol {
  private let registrar: FlutterPluginRegistrar

  init(_ registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  private var window: NSWindow? {
    registrar.view?.window
  }

  public func enterNativeFullscreen() {
    guard let window = window else {
      return printWarning()
    }

    if !window.styleMask.contains(.fullScreen) {
      window.toggleFullScreen(nil)
    }
  }

  public func exitNativeFullscreen() {
    guard let window = window else {
      return printWarning()
    }

    if window.styleMask.contains(.fullScreen) {
      window.toggleFullScreen(nil)
    }
  }

  private func printWarning() {
    NSLog("Utils: warning: unable to find the window")
  }
}
