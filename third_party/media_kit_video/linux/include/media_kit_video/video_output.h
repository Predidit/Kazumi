// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef VIDEO_OUTPUT_H_
#define VIDEO_OUTPUT_H_

#include <flutter_linux/flutter_linux.h>
#include <epoxy/egl.h>

#include "media_kit_mpv.h"
#include "gl_render_thread.h"

typedef struct _VideoOutputConfiguration {
  gint64 width;
  gint64 height;
  bool enable_hardware_acceleration;

  _VideoOutputConfiguration(gint64 width = NULL,
                            gint64 height = NULL,
                            bool enable_hardware_acceleration = true)
      : width(width),
        height(height),
        enable_hardware_acceleration(enable_hardware_acceleration) {}
} VideoOutputConfiguration;

// Callback invoked when the texture ID updates i.e. video dimensions changes.
typedef void (*TextureUpdateCallback)(gint64 id,
                                      gint64 width,
                                      gint64 height,
                                      gpointer context);

#define VIDEO_OUTPUT_TYPE (video_output_get_type())

G_DECLARE_FINAL_TYPE(VideoOutput,
                     video_output,
                     VIDEO_OUTPUT,
                     VIDEO_OUTPUT,
                     GObject)

#define VIDEO_OUTPUT(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), video_output_get_type(), VideoOutput))

// Creates a new |VideoOutput| for given |handle| (|mpv_handle| casted to
// gint64). Falls back to S/W rendering if no usable EGL display is found.
VideoOutput* video_output_new(FlTextureRegistrar* texture_registrar,
                              gint64 handle,
                              VideoOutputConfiguration configuration,
                              GLRenderThread* gl_render_thread);

// Sets the callback invoked when the texture ID updates i.e. video
// dimensions change.
void video_output_set_texture_update_callback(
    VideoOutput* self,
    TextureUpdateCallback texture_update_callback,
    gpointer texture_update_callback_context);

// Sets the required video output size. Pass 0 to size the texture based on
// the video's own resolution.
void video_output_set_size(VideoOutput* self, gint64 width, gint64 height);

mpv_render_context* video_output_get_render_context(VideoOutput* self);

EGLDisplay video_output_get_egl_display(VideoOutput* self);

EGLContext video_output_get_egl_context(VideoOutput* self);

GLRenderThread* video_output_get_gl_render_thread(VideoOutput* self);

guint8* video_output_get_pixel_buffer(VideoOutput* self);

gint64 video_output_get_width(VideoOutput* self);

gint64 video_output_get_height(VideoOutput* self);

gint64 video_output_get_texture_id(VideoOutput* self);

void video_output_notify_texture_update(VideoOutput* self);

// Schedules resize-check + render on the dedicated GL thread.
void video_output_notify_render(VideoOutput* self);

#endif  // VIDEO_OUTPUT_H_
