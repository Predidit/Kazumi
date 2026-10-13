# Video binding

This C target binds the public mpv API in the module that created the player's
handle. It does not download, link or bundle a separate mpv binary. Windows/Linux
CMake and Apple CocoaPods/SwiftPM compile the same source.

The public headers in `include/mpv` come from the pinned Windows development
archive `mpv-dev-x86_64-20260915-git-0b7ed67.7z`, including this fork's DXGI render
extension. The upstream headers retain their ISC license notices. Update them
when the renderer uses a new API; downloaded import libraries are unnecessary.

The owning Dart player supplies its resolved module path to
`media_kit_mpv_initialize`. Initialization is serialized and publishes all symbols
at once. Every renderer must initialize before calling the binding. A successful
binding retains the library until process exit, independently of Flutter engine
lifetimes. Player/render-context teardown stays with the existing owners.
