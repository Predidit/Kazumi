import Cocoa
import OpenGL.GL
import OpenGL.GL3

public class TextureGLContext {
  private let context: CGLContextObj
  private let renderBuffer: GLuint
  public let frameBuffer: GLuint
  public let texture: CVOpenGLTexture
  public let pixelBuffer: CVPixelBuffer

  init(
    context: CGLContextObj,
    textureCache: CVOpenGLTextureCache,
    size: CGSize
  ) {
    self.context = context

    self.pixelBuffer = OpenGLHelpers.createPixelBuffer(size)

    self.texture = OpenGLHelpers.createTexture(
      textureCache,
      pixelBuffer
    )

    self.renderBuffer = OpenGLHelpers.createRenderBuffer(
      context,
      size
    )

    self.frameBuffer = OpenGLHelpers.createFrameBuffer(
      context: context,
      renderBuffer: renderBuffer,
      texture: texture,
      size: size
    )
  }

  deinit {
    OpenGLHelpers.deletePixeBuffer(context, pixelBuffer)
    OpenGLHelpers.deleteTexture(context, texture)
    OpenGLHelpers.deleteRenderBuffer(context, renderBuffer)
    OpenGLHelpers.deleteFrameBuffer(context, frameBuffer)
  }
}
