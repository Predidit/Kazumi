// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef TEXTURE_SW_H_
#define TEXTURE_SW_H_

#include <flutter_linux/flutter_linux.h>

#include "video_output.h"

#define TEXTURE_SW_TYPE (texture_sw_get_type())

G_DECLARE_FINAL_TYPE(TextureSW,
                     texture_sw,
                     TEXTURE_SW,
                     TEXTURE_SW,
                     FlPixelBufferTexture)

#define TEXTURE_SW(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), texture_sw_get_type(), TextureSW))

TextureSW* texture_sw_new(VideoOutput* video_output);

gboolean texture_sw_copy_pixels(FlPixelBufferTexture* texture,
                                const guint8** buffer,
                                guint32* width,
                                guint32* height,
                                GError** error);

// Limit the frame size to 1080p in software rendering.
// This is for performance reasons & to avoid allocating too much memory.
#define SW_RENDERING_MAX_WIDTH 1920
#define SW_RENDERING_MAX_HEIGHT 1080
#define SW_RENDERING_PIXEL_BUFFER_SIZE \
  (SW_RENDERING_MAX_WIDTH) * (SW_RENDERING_MAX_HEIGHT) * (4)

#endif  // TEXTURE_SW_H_
