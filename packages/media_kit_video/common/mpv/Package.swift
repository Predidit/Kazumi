// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "MediaKitMpv",
    products: [.library(name: "Mpv", targets: ["Mpv"])],
    targets: [.target(name: "Mpv", path: ".", sources: ["media_kit_mpv.c"], publicHeadersPath: "include")]
)
