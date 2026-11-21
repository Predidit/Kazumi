// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef VIDEO_OUTPUT_MANAGER_H_
#define VIDEO_OUTPUT_MANAGER_H_

#include "video_output.h"
#include "gl_render_thread.h"

#define VIDEO_OUTPUT_MANAGER_TYPE (video_output_manager_get_type())

// Creates & disposes |VideoOutput| instances for video embedding.
G_DECLARE_FINAL_TYPE(VideoOutputManager,
                     video_output_manager,
                     VIDEO_OUTPUT_MANAGER,
                     VIDEO_OUTPUT_MANAGER,
                     GObject)

#define VIDEO_OUTPUT_MANAGER(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), video_output_manager_get_type(), \
                              VideoOutputManager))

VideoOutputManager* video_output_manager_new(
    FlTextureRegistrar* texture_registrar);

// Creates a new |VideoOutput| instance for given |handle|.
void video_output_manager_create(VideoOutputManager* self,
                                 gint64 handle,
                                 VideoOutputConfiguration configuration,
                                 TextureUpdateCallback texture_update_callback,
                                 gpointer texture_update_callback_context);

// Sets the required video output size. Pass 0 to size the texture based on
// the video's own resolution.
void video_output_manager_set_size(VideoOutputManager* self,
                                   gint64 handle,
                                   gint64 width,
                                   gint64 height);

// Disposes |VideoOutput| instance for given |handle|.
void video_output_manager_dispose(VideoOutputManager* self, gint64 handle);

#endif
