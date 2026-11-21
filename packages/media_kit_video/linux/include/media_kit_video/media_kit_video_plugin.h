// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef MEDIA_KIT_VIDEO_PLUGIN_H_
#define MEDIA_KIT_VIDEO_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

typedef struct _MediaKitVideoPlugin MediaKitVideoPlugin;
typedef struct {
  GObjectClass parent_class;
} MediaKitVideoPluginClass;

FLUTTER_PLUGIN_EXPORT GType media_kit_video_plugin_get_type();

FLUTTER_PLUGIN_EXPORT void media_kit_video_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_MEDIA_KIT_VIDEO_PLUGIN_H_
