import Cocoa
import OpenGL.GL
import OpenGL.GL3

public class OpenGLHelpers {
  static public func createPixelFormat() -> CGLPixelFormatObj? {
    // from mpv
    let attributes: [CGLPixelFormatAttribute] = [
      kCGLPFAOpenGLProfile,
      CGLPixelFormatAttribute(kCGLOGLPVersion_3_2_Core.rawValue),
      kCGLPFAAccelerated,
      kCGLPFADoubleBuffer,
      kCGLPFAColorSize, _CGLPixelFormatAttribute(rawValue: 64),
      kCGLPFAColorFloat,
      kCGLPFABackingStore,
      kCGLPFAAllowOfflineRenderers,
      kCGLPFASupportsAutomaticGraphicsSwitching,
      _CGLPixelFormatAttribute(rawValue: 0),
    ]

    var npix: GLint = 0
    var pixelFormat: CGLPixelFormatObj?
    guard CGLChoosePixelFormat(attributes, &pixelFormat, &npix) == kCGLNoError else {
      return nil
    }
    return pixelFormat
  }

  static public func createContext(
    _ pixelFormat: CGLPixelFormatObj
  ) -> CGLContextObj? {
    var context: CGLContextObj?
    let error = CGLCreateContext(pixelFormat, nil, &context)
    if error != kCGLNoError {
      let errS = String(cString: CGLErrorString(error))
      NSLog(errS)
      return nil
    }

    return context
  }

  static public func createTextureCache(
    _ context: CGLContextObj,
    _ pixelFormat: CGLPixelFormatObj
  ) -> CVOpenGLTextureCache? {
    var textureCache: CVOpenGLTextureCache?

    let cvret: CVReturn = CVOpenGLTextureCacheCreate(
      kCFAllocatorDefault,
      nil,
      context,
      pixelFormat,
      nil,
      &textureCache
    )
    guard cvret == kCVReturnSuccess else { return nil }
    return textureCache
  }

  static public func createPixelBuffer(_ size: CGSize) -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?

    let attrs =
      [
        kCVPixelBufferMetalCompatibilityKey: true
      ] as CFDictionary

    let cvret: CVReturn = CVPixelBufferCreate(
      kCFAllocatorDefault,
      Int(size.width),
      Int(size.height),
      kCVPixelFormatType_32BGRA,
      attrs,
      &pixelBuffer
    )
    assert(cvret == kCVReturnSuccess, "CVPixelBufferCreate")

    return pixelBuffer!
  }

  static public func createTexture(
    _ textureCache: CVOpenGLTextureCache,
    _ pixelBuffer: CVPixelBuffer
  ) -> CVOpenGLTexture {
    var texture: CVOpenGLTexture?

    let cvret: CVReturn = CVOpenGLTextureCacheCreateTextureFromImage(
      kCFAllocatorDefault,
      textureCache,
      pixelBuffer,
      nil,
      &texture
    )
    assert(
      cvret == kCVReturnSuccess,
      "CVOpenGLTextureCacheCreateTextureFromImage"
    )

    return texture!
  }

  static public func createRenderBuffer(
    _ context: CGLContextObj,
    _ size: CGSize
  ) -> GLuint {
    CGLSetCurrentContext(context)
    defer {
      OpenGLHelpers.checkError("createRenderBuffer")
      CGLSetCurrentContext(nil)
    }

    var renderBuffer: GLuint = GLuint()
    glGenRenderbuffers(1, &renderBuffer)
    glBindRenderbuffer(GLenum(GL_RENDERBUFFER), renderBuffer)
    defer {
      glBindRenderbuffer(GLenum(GL_RENDERBUFFER), 0)
    }

    glRenderbufferStorage(
      GLenum(GL_RENDERBUFFER),
      GLenum(GL_DEPTH24_STENCIL8),
      GLsizei(size.width),
      GLsizei(size.height)
    )

    return renderBuffer
  }

  static public func createFrameBuffer(
    context: CGLContextObj,
    renderBuffer: GLuint,
    texture: CVOpenGLTexture,
    size: CGSize
  ) -> GLuint {
    CGLSetCurrentContext(context)
    defer {
      OpenGLHelpers.checkError("createFrameBuffer")
      CGLSetCurrentContext(nil)
    }

    let textureName: GLuint = CVOpenGLTextureGetName(texture)
    glBindTexture(GLenum(GL_TEXTURE_RECTANGLE), textureName)
    defer {
      glBindTexture(GLenum(GL_TEXTURE_RECTANGLE), 0)
    }

    glTexParameteri(
      GLenum(GL_TEXTURE_RECTANGLE),
      GLenum(GL_TEXTURE_MAG_FILTER),
      GL_LINEAR
    )
    glTexParameteri(
      GLenum(GL_TEXTURE_RECTANGLE),
      GLenum(GL_TEXTURE_MIN_FILTER),
      GL_LINEAR
    )

    glViewport(0, 0, GLsizei(size.width), GLsizei(size.height))

    var frameBuffer: GLuint = 0
    glGenFramebuffers(1, &frameBuffer)
    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameBuffer)
    defer {
      glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
    }

    glFramebufferTexture2D(
      GLenum(GL_FRAMEBUFFER),
      GLenum(GL_COLOR_ATTACHMENT0),
      GLenum(GL_TEXTURE_RECTANGLE),
      textureName,
      0
    )

    glFramebufferRenderbuffer(
      GLenum(GL_FRAMEBUFFER),
      GLenum(GL_DEPTH_ATTACHMENT),
      GLenum(GL_RENDERBUFFER),
      renderBuffer
    )

    return frameBuffer
  }

  static public func deletePixelFormat(_ pixelFormat: CGLPixelFormatObj) {
    CGLReleasePixelFormat(pixelFormat)
  }

  static public func deleteContext(_ context: CGLContextObj) {
    CGLSetCurrentContext(nil)
    CGLReleaseContext(context)
  }

  static public func deleteTextureCache(_ textureCache: CVOpenGLTextureCache) {
    CVOpenGLTextureCacheFlush(textureCache, 0)

    // 'CVOpenGLTextureCacheRelease' is unavailable: Core Foundation objects are
    // automatically memory managed
  }

  static public func deletePixeBuffer(
    _ context: CGLContextObj,
    _ pixelBuffer: CVPixelBuffer
  ) {
    // 'CVPixelBufferRelease' is unavailable: Core Foundation objects are
    // automatically memory managed
  }

  // BUG: `glDeleteTextures` does not release `CVOpenGLTexture`.
  // `CVOpenGLTextureCache` retains a direct or indirect reference to
  // `IOSurface`, which causes a memory leak until `CVOpenGLTextureCache` is
  // released.
  static public func deleteTexture(
    _ context: CGLContextObj,
    _ texture: CVOpenGLTexture
  ) {
    CGLSetCurrentContext(context)
    defer {
      OpenGLHelpers.checkError("deleteTexture")
      CGLSetCurrentContext(nil)
    }

    var textureName: GLuint = CVOpenGLTextureGetName(texture)
    glDeleteTextures(1, &textureName)
  }

  static public func deleteRenderBuffer(
    _ context: CGLContextObj,
    _ renderBuffer: GLuint
  ) {
    CGLSetCurrentContext(context)
    defer {
      OpenGLHelpers.checkError("deleteRenderBuffer")
      CGLSetCurrentContext(nil)
    }

    var renderBuffer = renderBuffer
    glDeleteRenderbuffers(1, &renderBuffer)
  }

  static public func deleteFrameBuffer(
    _ context: CGLContextObj,
    _ frameBuffer: GLuint
  ) {
    CGLSetCurrentContext(context)
    defer {
      OpenGLHelpers.checkError("deleteFrameBuffer")
      CGLSetCurrentContext(nil)
    }

    var frameBuffer = frameBuffer
    glDeleteFramebuffers(1, &frameBuffer)
  }

  static public func checkError(_ message: String) {
    let error = glGetError()
    if error == GL_NO_ERROR {
      return
    }

    NSLog("OpenGLHelpers: error: \(message): \(error)")
  }
}
