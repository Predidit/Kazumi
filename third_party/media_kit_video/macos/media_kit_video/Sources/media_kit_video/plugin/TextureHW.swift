import FlutterMacOS
import OpenGL.GL
import OpenGL.GL3

#if SWIFT_PACKAGE
  import Mpv
#endif

public class TextureHW: NSObject, FlutterTexture, ResizableTextureProtocol {
  public typealias UpdateCallback = () -> Void

  private let handle: OpaquePointer
  private let updateCallback: UpdateCallback
  private let pixelFormat: CGLPixelFormatObj
  private let context: CGLContextObj
  private let textureCache: CVOpenGLTextureCache
  private var renderContext: OpaquePointer?
  private var textureContexts = SwappableObjectManager<TextureGLContext>(
    objects: [],
    skipCheckArgs: true
  )

  init?(
    handle: OpaquePointer,
    updateCallback: @escaping UpdateCallback
  ) {
    guard let pixelFormat = OpenGLHelpers.createPixelFormat() else { return nil }
    guard let context = OpenGLHelpers.createContext(pixelFormat) else {
      OpenGLHelpers.deletePixelFormat(pixelFormat)
      return nil
    }
    guard let textureCache = OpenGLHelpers.createTextureCache(context, pixelFormat) else {
      OpenGLHelpers.deleteContext(context)
      OpenGLHelpers.deletePixelFormat(pixelFormat)
      return nil
    }
    self.handle = handle
    self.updateCallback = updateCallback
    self.pixelFormat = pixelFormat
    self.context = context
    self.textureCache = textureCache

    super.init()

    self.initMPV()
  }

  deinit {
    disposePixelBuffer()
    disposeMPV()
    OpenGLHelpers.deleteTextureCache(textureCache)
    OpenGLHelpers.deletePixelFormat(pixelFormat)

    // Deleting the context may cause potential RAM or VRAM memory leaks, as it
    // is used in the `deinit` method of the `TextureGLContext`.
    // Potential fix: use a counter, and delete it only when the counter reaches
    // zero
    OpenGLHelpers.deleteContext(context)
  }

  public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    let textureContext = textureContexts.current
    if textureContext == nil {
      return nil
    }

    return Unmanaged.passRetained(textureContext!.pixelBuffer)
  }

  public func dispose() {
    disposeMPV()
  }

  private func initMPV() {
    CGLSetCurrentContext(context)
    defer {
      OpenGLHelpers.checkError("initMPV")
      CGLSetCurrentContext(nil)
    }

    let api = UnsafeMutableRawPointer(
      mutating: (MPV_RENDER_API_TYPE_OPENGL as NSString).utf8String
    )
    var procAddress = mpv_opengl_init_params(
      get_proc_address: {
        (ctx, name) in
        return TextureHW.getProcAddress(ctx, name)
      },
      get_proc_address_ctx: nil
    )

    var params: [mpv_render_param] = withUnsafeMutableBytes(of: &procAddress) {
      procAddress in
      return [
        mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: api),
        mpv_render_param(
          type: MPV_RENDER_PARAM_OPENGL_INIT_PARAMS,
          data: procAddress.baseAddress.map {
            UnsafeMutableRawPointer($0)
          }
        ),
        mpv_render_param(),
      ]
    }

    MPVHelpers.checkError(
      media_kit_mpv_render_context_create(&renderContext, handle, &params)
    )

    media_kit_mpv_render_context_set_update_callback(
      renderContext,
      { (ctx) in
        let that = unsafeBitCast(ctx, to: TextureHW.self)
        DispatchQueue.main.async {
          that.updateCallback()
        }
      },
      UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    )
  }

  private func disposeMPV() {
    guard let renderContext = renderContext else { return }
    CGLSetCurrentContext(context)
    defer {
      OpenGLHelpers.checkError("disposeMPV")
      CGLSetCurrentContext(nil)
    }

    media_kit_mpv_render_context_set_update_callback(renderContext, nil, nil)
    media_kit_mpv_render_context_free(renderContext)
    self.renderContext = nil
  }

  public func resize(_ size: CGSize) {
    if size.width == 0 || size.height == 0 {
      return
    }

    NSLog("TextureGL: resize: \(size.width)x\(size.height)")
    createPixelBuffer(size)
  }

  private func createPixelBuffer(_ size: CGSize) {
    disposePixelBuffer()

    textureContexts.reinit(
      objects: [
        TextureGLContext(
          context: context,
          textureCache: textureCache,
          size: size
        ),
        TextureGLContext(
          context: context,
          textureCache: textureCache,
          size: size
        ),
        TextureGLContext(
          context: context,
          textureCache: textureCache,
          size: size
        ),
      ],
      skipCheckArgs: true
    )
  }

  private func disposePixelBuffer() {
    textureContexts.reinit(objects: [], skipCheckArgs: true)
  }

  public func render(_ size: CGSize) {
    guard renderContext != nil else { return }
    let textureContext = textureContexts.nextAvailable()
    if textureContext == nil {
      return
    }

    CGLSetCurrentContext(context)
    defer {
      OpenGLHelpers.checkError("render")
      CGLSetCurrentContext(nil)
    }

    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), textureContext!.frameBuffer)
    defer {
      glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
    }

    var fbo = mpv_opengl_fbo(
      fbo: Int32(textureContext!.frameBuffer),
      w: Int32(size.width),
      h: Int32(size.height),
      internal_format: 0
    )
    let fboPtr = withUnsafeMutablePointer(to: &fbo) { $0 }

    var params: [mpv_render_param] = [
      mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_FBO, data: fboPtr),
      mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil),
    ]
    media_kit_mpv_render_context_render(renderContext, &params)

    glFlush()

    textureContexts.pushAsReady(textureContext!)
  }

  static private func getProcAddress(
    _ ctx: UnsafeMutableRawPointer?,
    _ name: UnsafePointer<Int8>?
  ) -> UnsafeMutableRawPointer? {
    let symbol: CFString = CFStringCreateWithCString(
      kCFAllocatorDefault,
      name,
      kCFStringEncodingASCII
    )
    let indentifier = CFBundleGetBundleWithIdentifier(
      "com.apple.opengl" as CFString
    )
    let addr = CFBundleGetFunctionPointerForName(indentifier, symbol)

    if addr == nil {
      NSLog("Cannot get OpenGL function pointer!")
    }
    return addr
  }
}
