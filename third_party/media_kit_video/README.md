# [package:media_kit_video](https://github.com/media-kit/media-kit)

[![](https://img.shields.io/discord/1079685977523617792?color=33cd57&label=Discord&logo=discord&logoColor=discord)](https://discord.gg/h7qf2R9n57) [![Github Actions](https://github.com/media-kit/media-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/media-kit/media-kit/actions/workflows/ci.yml)

Native implementation for video playback in [package:media_kit](https://pub.dev/packages/media_kit).

## Kazumi Windows adapter changes

This vendored copy is based on Predidit's `media-kit` commit
`6b188ae978808a63e5b58b7ce61f7725238c04c5`. It adds Windows D3D11 adapter
discovery and selection. Auto retains the upstream Flutter-adapter renderer;
selecting another adapter stages each frame through system memory and uploads
it to the Flutter adapter, avoiding unsupported cross-adapter DXGI shared
handles. Keep the app's `media_kit` dependency and this package at compatible
upstream revisions when updating the vendored plugin.

## License

Copyright © 2021 & onwards, Hitesh Kumar Saini <<saini123hitesh@gmail.com>>

This project & the work under this repository is governed by MIT license that can be found in the [LICENSE](./LICENSE) file.
