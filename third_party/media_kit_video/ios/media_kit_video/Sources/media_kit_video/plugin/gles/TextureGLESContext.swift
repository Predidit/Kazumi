import OpenGLES
import UIKit

public class TextureGLESContext {
  private let context: EAGLContext
  public let frameBuffer: GLuint
  public let texture: CVOpenGLESTexture
  public let pixelBuffer: CVPixelBuffer

  init(
    context: EAGLContext,
    textureCache: CVOpenGLESTextureCache,
    size: CGSize
  ) {
    self.context = context

    // Sometimes the frameBuffer created by `createFrameBuffer` has the status
    // `GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT`, which makes it unusable.
    // This seems to be because the pixelBuffer created by `createPixelBuffer`
    // appears to be invalid, with no way to prevent or detect this.
    // So we have to try several times to create a frameBuffer valid.
    // This is usually the case after the second attempt.
    for index in 0...3 {
      let pixelBuffer = OpenGLESHelpers.createPixelBuffer(size)

      let texture = OpenGLESHelpers.createTexture(
        textureCache,
        pixelBuffer,
        size
      )

      let frameBuffer = try? OpenGLESHelpers.createFrameBuffer(
        context: context,
        texture: texture,
        size: size
      )
      if frameBuffer != nil {
        self.pixelBuffer = pixelBuffer
        self.texture = texture
        self.frameBuffer = frameBuffer!
        return
      }

      OpenGLESHelpers.deletePixeBuffer(context, pixelBuffer)
      OpenGLESHelpers.deleteTexture(context, texture)
    }

    NSLog("TextureGLESContext: init: unable to create a valid frameBuffer")
    exit(1)
  }

  deinit {
    OpenGLESHelpers.deletePixeBuffer(context, pixelBuffer)
    OpenGLESHelpers.deleteTexture(context, texture)
    OpenGLESHelpers.deleteFrameBuffer(context, frameBuffer)
  }
}
