# Kazumi media_kit_video overlay

Imported from `Predidit/media-kit@cd75bcfe94ba45ebb6f6b940c68e072d079aee14`
(MIT), excluding its example and monorepo-only overrides. The core
`media_kit` package and its native artifacts remain at the same revision.
Keeping the video package's native and Dart changes together avoids
reverting the current D3D11 render API or changing unrelated platforms.

Windows adapter selection is informed by [media-kit PR #42](https://github.com/Predidit/media-kit/pull/42) by ZeroL (DXGI LUID selection and staging copy). The implementation here uses the later upstream D3D11 render API and retains each Flutter GPU mailbox across texture replacement. Android accepts an optional Vulkan device UUID and both targets support a viewport-driven output size.
