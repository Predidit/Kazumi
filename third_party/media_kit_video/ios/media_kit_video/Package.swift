// swift-tools-version: 5.9
import PackageDescription
import Foundation

// Flutter links this package into its generated Packages directory. Resolve the
// manifest's real location before locating the shared native bindings.
let mpvPackagePath = URL(fileURLWithPath: #filePath)
    .resolvingSymlinksInPath()
    .deletingLastPathComponent()
    .appendingPathComponent("../../common/mpv")
    .standardizedFileURL.path

let package = Package(
    name: "media_kit_video",
    platforms: [.iOS("13.0")],
    products: [.library(name: "media-kit-video", targets: ["media_kit_video"])],
    dependencies: [.package(name: "MediaKitMpv", path: mpvPackagePath)],
    targets: [.target(
        name: "media_kit_video",
        dependencies: [.product(name: "Mpv", package: "MediaKitMpv")],
        sources: ["plugin"],
        resources: [.process("PrivacyInfo.xcprivacy")]
    )]
)
