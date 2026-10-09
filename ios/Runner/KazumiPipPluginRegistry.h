#import <Flutter/Flutter.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

// Give the app access to media-kit's rendered frames through Flutter's public
// texture API, including when the Flutter rasterizer is suspended in background.
@interface KazumiPipPluginRegistry : NSObject <FlutterPluginRegistry>
- (instancetype)initWithRegistry:(NSObject<FlutterPluginRegistry> *)registry
                    frameHandler:(void (^)(CVPixelBufferRef, int64_t))frameHandler
    NS_SWIFT_NAME(init(registry:frameHandler:));
- (nullable CVPixelBufferRef)copyPixelBufferForTexture:(int64_t)textureId
    CF_RETURNS_RETAINED NS_SWIFT_NAME(copyPixelBuffer(forTexture:));
- (void)useSoftwareRenderingForHandle:(int64_t)handle completion:(void (^)(BOOL))completion
    NS_SWIFT_NAME(useSoftwareRendering(forHandle:completion:));
- (void)restoreRenderingWithCompletion:(void (^)(void))completion
    NS_SWIFT_NAME(restoreRendering(completion:));
@property(nonatomic, copy, nullable) void (^videoOutputWillChange)(int64_t, void (^)(BOOL));
@property(nonatomic, copy, nullable) void (^videoOutputDidChange)(int64_t, void (^)(BOOL));
@end

NS_ASSUME_NONNULL_END
