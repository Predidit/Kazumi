# Video binding

This C target binds the public mpv API in the module that created the player's
handle. It does not download, link or bundle a separate mpv binary. Windows/Linux
CMake and Apple CocoaPods/SwiftPM compile the same source.

The public headers in `include/mpv` are the unmodified upstream headers at mpv
commit `bcde6b9` (client API 2.6), including the Direct3D 11 render backend in
`render_d3d11.h` used by the Windows renderer. They retain their ISC license
notices. Update them when the renderer uses a new API; downloaded import
libraries are unnecessary.

The owning Dart player supplies its resolved module path to
`media_kit_mpv_initialize`. Initialization is serialized and publishes all symbols
at once. Every renderer must initialize before calling the binding. A successful
binding retains the library until process exit, independently of Flutter engine
lifetimes. Player/render-context teardown stays with the existing owners.
