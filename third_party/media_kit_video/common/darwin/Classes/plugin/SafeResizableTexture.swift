import CoreGraphics
import CoreVideo
import Foundation

#if canImport(Flutter)
  import Flutter
#elseif canImport(FlutterMacOS)
  import FlutterMacOS
#endif

// This class avoids data race when called from a thread
public class SafeResizableTexture:
  NSObject,
  FlutterTexture,
  ResizableTextureProtocol
{
  private let lock = NSRecursiveLock()
  private let child: ResizableTextureProtocol

  init(_ child: ResizableTextureProtocol) {
    self.child = child
  }

  public func dispose() {
    locked {
      child.dispose()
    }
  }

  public func resize(_ size: CGSize) {
    return locked {
      return child.resize(size)
    }
  }

  public func render(_ size: CGSize) {
    return locked {
      return child.render(size)
    }
  }

  public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    return child.copyPixelBuffer()
  }

  private func locked<T>(do block: () -> T) -> T {
    lock.lock()
    defer {
      lock.unlock()
    }

    return block()
  }
}
