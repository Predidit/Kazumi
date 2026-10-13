// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/video_output.h"
#include "include/media_kit_video/texture_gl.h"
#include "include/media_kit_video/texture_sw.h"
#include "include/media_kit_video/gl_render_thread.h"
#include "../common/video_dimensions.h"

#include <epoxy/egl.h>
#include <gdk/gdkwayland.h>
#include <gdk/gdkx.h>

struct _VideoOutput {
  GObject parent_instance;
  TextureGL* texture_gl;
  EGLDisplay egl_display; /* Same EGLDisplay the Flutter engine renders on. */
  EGLConfig egl_config;
  EGLContext egl_context; /* Isolated (non-shared) context for mpv. */
  guint8* pixel_buffer;
  TextureSW* texture_sw;
  GMutex mutex; /* Only used in S/W rendering. */
  mpv_handle* handle;
  mpv_render_context* render_context;
  gint64 width;
  gint64 height;
  VideoOutputConfiguration configuration;
  TextureUpdateCallback texture_update_callback;
  gpointer texture_update_callback_context;
  FlTextureRegistrar* texture_registrar;
  GLRenderThread* gl_render_thread;
  gboolean destroyed;
};

G_DEFINE_TYPE(VideoOutput, video_output, G_TYPE_OBJECT)

static void video_output_dispose(GObject* object) {
  VideoOutput* self = VIDEO_OUTPUT(object);
  self->destroyed = TRUE;

  // Make sure that no more callbacks are invoked from mpv.
  if (self->render_context) {
    mpv_render_context_set_update_callback(self->render_context, NULL, NULL);
  }

  // H/W
  if (self->texture_gl) {
    fl_texture_registrar_unregister_texture(self->texture_registrar,
                                            FL_TEXTURE(self->texture_gl));

    // EGL resources must be released in the dedicated GL thread.
    if (self->render_context != NULL || self->egl_context != EGL_NO_CONTEXT) {
      self->gl_render_thread->PostAndWait([self]() {
        if (self->render_context != NULL) {
          if (self->egl_context != EGL_NO_CONTEXT) {
            eglMakeCurrent(self->egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, self->egl_context);
          }
          mpv_render_context_free(self->render_context);
          self->render_context = NULL;
        }
        if (self->egl_context != EGL_NO_CONTEXT) {
          eglDestroyContext(self->egl_display, self->egl_context);
          self->egl_context = EGL_NO_CONTEXT;
        }
      });
    }

    g_object_unref(self->texture_gl);
  }
  // S/W
  if (self->texture_sw) {
    fl_texture_registrar_unregister_texture(self->texture_registrar,
                                            FL_TEXTURE(self->texture_sw));
    g_free(self->pixel_buffer);
    g_object_unref(self->texture_sw);
    if (self->render_context != NULL) {
      mpv_render_context_free(self->render_context);
      self->render_context = NULL;
    }
  }

  g_mutex_clear(&self->mutex);
  G_OBJECT_CLASS(video_output_parent_class)->dispose(object);
}

static void video_output_class_init(VideoOutputClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = video_output_dispose;
}

static void video_output_init(VideoOutput* self) {
  self->texture_gl = NULL;
  self->egl_display = EGL_NO_DISPLAY;
  self->egl_config = NULL;
  self->egl_context = EGL_NO_CONTEXT;
  self->texture_sw = NULL;
  self->pixel_buffer = NULL;
  self->handle = NULL;
  self->render_context = NULL;
  self->width = 0;
  self->height = 0;
  self->configuration = VideoOutputConfiguration{};
  self->texture_update_callback = NULL;
  self->texture_update_callback_context = NULL;
  self->texture_registrar = NULL;
  self->gl_render_thread = NULL;
  self->destroyed = FALSE;
  g_mutex_init(&self->mutex);
}

VideoOutput* video_output_new(FlTextureRegistrar* texture_registrar,
                              gint64 handle,
                              VideoOutputConfiguration configuration,
                              GLRenderThread* gl_render_thread) {
  VideoOutput* self = VIDEO_OUTPUT(g_object_new(video_output_get_type(), NULL));
  self->texture_registrar = texture_registrar;
  self->gl_render_thread = gl_render_thread;
  self->handle = (mpv_handle*)handle;
  self->width = configuration.width;
  self->height = configuration.height;
  self->configuration = configuration;
#ifndef MPV_RENDER_API_TYPE_SW
  // MPV_RENDER_API_TYPE_SW must be available for S/W rendering.
  if (!self->configuration.enable_hardware_acceleration) {
    g_printerr("media_kit: VideoOutput: S/W rendering is not supported.\n");
  }
  self->configuration.enable_hardware_acceleration = TRUE;
#endif

  gboolean hardware_acceleration_supported = FALSE;

  if (self->configuration.enable_hardware_acceleration) {
    // The GTK embedder (FlOpenGLManager) renders with EGL + GLES2 on both
    // X11 and Wayland, but its contexts are never current on the platform
    // thread. EGL returns the same EGLDisplay for the same native display,
    // so derive the engine's display from the GDK display — same-display is
    // all EGLImage/EGLSync sharing requires (mpv's context is non-shared).
    GdkDisplay* display = gdk_display_get_default();
    EGLDisplay egl_display = EGL_NO_DISPLAY;
    if (epoxy_has_egl_extension(EGL_NO_DISPLAY, "EGL_EXT_platform_base")) {
      if (GDK_IS_WAYLAND_DISPLAY(display)) {
        egl_display = eglGetPlatformDisplayEXT(
            EGL_PLATFORM_WAYLAND_EXT, gdk_wayland_display_get_wl_display(display), NULL);
      } else if (GDK_IS_X11_DISPLAY(display)) {
        egl_display = eglGetPlatformDisplayEXT(
            EGL_PLATFORM_X11_EXT, gdk_x11_display_get_xdisplay(display), NULL);
      }
    }

    // eglQueryString(EGL_VERSION) != NULL means the engine already
    // initialized this display. Otherwise this is not the EGL-based embedder
    // (legacy GLX embedders are unsupported); fall through to S/W rendering.
    if (egl_display != EGL_NO_DISPLAY &&
        eglQueryString(egl_display, EGL_VERSION) != NULL) {
      // mpv renders into an FBO in a surfaceless context; any GLES2 config
      // works since it never backs an actual surface.
      const EGLint config_attribs[] = {
          EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
          EGL_RED_SIZE, 8,
          EGL_GREEN_SIZE, 8,
          EGL_BLUE_SIZE, 8,
          EGL_ALPHA_SIZE, 8,
          EGL_NONE,
      };
      EGLint num_configs = 0;
      if (eglChooseConfig(egl_display, config_attribs, &self->egl_config, 1, &num_configs) &&
          num_configs > 0) {
        self->egl_display = egl_display;
        g_print("media_kit: VideoOutput: Got engine EGL display (%p) with GLES2 config.\n",
                egl_display);
      } else {
        g_printerr("media_kit: VideoOutput: Failed to choose EGL config.\n");
        self->egl_config = NULL;
      }
    } else {
      g_printerr(
          "media_kit: VideoOutput: H/W rendering requires the EGL-based "
          "Flutter embedder.\n");
    }

    if (self->egl_display != EGL_NO_DISPLAY && self->egl_config != NULL) {
      self->texture_gl = texture_gl_new(self);
      if (!fl_texture_registrar_register_texture(
              texture_registrar, FL_TEXTURE(self->texture_gl))) {
        g_printerr("media_kit: VideoOutput: Failed to register texture.\n");
        g_object_unref(self->texture_gl);
        self->texture_gl = NULL;
        self->egl_config = NULL;
      }
    }
  }

  // Initialize mpv in dedicated GL render thread
  gl_render_thread->PostAndWait([self, &hardware_acceleration_supported]() {
    mpv_set_option_string(self->handle, "video-sync", "audio");
    // Causes frame drops with `pulse` audio output. (SlotSun/dart_simple_live#42)
    // mpv_set_option_string(self->handle, "video-timing-offset", "0");

    if (self->texture_gl != NULL &&
        self->egl_display != EGL_NO_DISPLAY &&
        self->egl_config != NULL) {
      eglBindAPI(EGL_OPENGL_ES_API);

      // Isolated (non-shared) GLES2 context; frames are shared with Flutter
      // via EGLImage on the same display, not via context share lists.
      const EGLint context_attribs[] = {
          EGL_CONTEXT_CLIENT_VERSION, 2,
          EGL_NONE
      };
      self->egl_context = eglCreateContext(self->egl_display, self->egl_config,
                                           EGL_NO_CONTEXT, context_attribs);

      if (self->egl_context != EGL_NO_CONTEXT) {
        // Surfaceless: mpv only ever renders into FBOs.
        if (eglMakeCurrent(self->egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, self->egl_context)) {
          mpv_opengl_init_params gl_init_params{
              [](auto, auto name) {
                return (void*)eglGetProcAddress(name);
              },
              NULL,
          };

          mpv_render_param params[] = {
              {MPV_RENDER_PARAM_API_TYPE, (void*)MPV_RENDER_API_TYPE_OPENGL},
              {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, (void*)&gl_init_params},
              {MPV_RENDER_PARAM_INVALID, (void*)0},
              {MPV_RENDER_PARAM_INVALID, (void*)0},
          };

          // VAAPI acceleration requires passing X11/Wayland display.
          GdkDisplay* display = gdk_display_get_default();
          if (GDK_IS_WAYLAND_DISPLAY(display)) {
            params[2].type = MPV_RENDER_PARAM_WL_DISPLAY;
            params[2].data = gdk_wayland_display_get_wl_display(display);
          } else if (GDK_IS_X11_DISPLAY(display)) {
            params[2].type = MPV_RENDER_PARAM_X11_DISPLAY;
            params[2].data = gdk_x11_display_get_xdisplay(display);
          }

          if (mpv_render_context_create(&self->render_context, self->handle, params) == 0) {
            mpv_render_context_set_update_callback(
                self->render_context,
                [](void* data) {
                  VideoOutput* self = (VideoOutput*)data;
                  if (self->destroyed) {
                    return;
                  }
                  // Asynchronous: must not block mpv's thread.
                  video_output_notify_render(self);
                },
                self);
            hardware_acceleration_supported = TRUE;
            g_print("media_kit: VideoOutput: H/W rendering with isolated EGL context in dedicated thread.\n");
          } else {
            g_printerr("media_kit: VideoOutput: Failed to create mpv_render_context.\n");
            eglDestroyContext(self->egl_display, self->egl_context);
            self->egl_context = EGL_NO_CONTEXT;
          }
        } else {
          g_printerr("media_kit: VideoOutput: Failed to make isolated EGL context current. Error: 0x%x\n", eglGetError());
          eglDestroyContext(self->egl_display, self->egl_context);
          self->egl_context = EGL_NO_CONTEXT;
        }
      } else {
        g_printerr("media_kit: VideoOutput: Failed to create isolated EGL context. Error: 0x%x\n", eglGetError());
      }
    }
  });

  if (!hardware_acceleration_supported && self->texture_gl != NULL) {
    fl_texture_registrar_unregister_texture(texture_registrar,
                                            FL_TEXTURE(self->texture_gl));
    g_object_unref(self->texture_gl);
    self->texture_gl = NULL;
  }
#ifdef MPV_RENDER_API_TYPE_SW
  // H/W rendering unavailable; fall back to S/W rendering.
  if (!hardware_acceleration_supported) {
    g_printerr("media_kit: VideoOutput: S/W rendering.\n");
    self->pixel_buffer = g_new0(guint8, SW_RENDERING_PIXEL_BUFFER_SIZE);
    self->texture_sw = texture_sw_new(self);
    if (fl_texture_registrar_register_texture(texture_registrar,
                                              FL_TEXTURE(self->texture_sw))) {
      mpv_render_param params[] = {
          {MPV_RENDER_PARAM_API_TYPE, (void*)MPV_RENDER_API_TYPE_SW},
          {MPV_RENDER_PARAM_INVALID, (void*)0},
      };
      if (mpv_render_context_create(&self->render_context, self->handle,
                                    params) == 0) {
        mpv_render_context_set_update_callback(
            self->render_context,
            [](void* data) {
              gdk_threads_add_idle(
                  [](gpointer data) -> gboolean {
                    VideoOutput* self = (VideoOutput*)data;
                    if (self->destroyed) {
                      return FALSE;
                    }
                    g_mutex_lock(&self->mutex);
                    gint64 width = video_output_get_width(self);
                    gint64 height = video_output_get_height(self);
                    if (width > 0 && height > 0) {
                      gint32 size[]{(gint32)width, (gint32)height};
                      gint32 pitch = 4 * (gint32)width;
                      mpv_render_param params[]{
                          {MPV_RENDER_PARAM_SW_SIZE, size},
                          {MPV_RENDER_PARAM_SW_FORMAT, (void*)"rgb0"},
                          {MPV_RENDER_PARAM_SW_STRIDE, &pitch},
                          {MPV_RENDER_PARAM_SW_POINTER, self->pixel_buffer},
                          {MPV_RENDER_PARAM_INVALID, (void*)0},
                      };
                      mpv_render_context_render(self->render_context, params);
                      fl_texture_registrar_mark_texture_frame_available(
                          self->texture_registrar,
                          FL_TEXTURE(self->texture_sw));
                    }
                    g_mutex_unlock(&self->mutex);
                    return FALSE;
                  },
                  data);
            },
            self);
      }
    }
  }
#endif
  return self;
}

void video_output_set_texture_update_callback(
    VideoOutput* self,
    TextureUpdateCallback texture_update_callback,
    gpointer texture_update_callback_context) {
  self->texture_update_callback = texture_update_callback;
  self->texture_update_callback_context = texture_update_callback_context;
  // Notify initial dimensions as (1, 1) if |width| & |height| are 0 i.e.
  // texture & video frame size is based on playing file's resolution. This
  // will make sure that `Texture` widget on Flutter's widget tree is actually
  // mounted & |fl_texture_registrar_mark_texture_frame_available| actually
  // invokes the |TextureGL| or |TextureSW| callbacks. Otherwise it will be a
  // never ending deadlock where no video frames are ever rendered.
  gint64 texture_id = video_output_get_texture_id(self);
  if (self->width == 0 || self->height == 0) {
    self->texture_update_callback(texture_id, 1, 1,
                                  self->texture_update_callback_context);
  } else {
    self->texture_update_callback(texture_id, self->width, self->height,
                                  self->texture_update_callback_context);
  }
}

void video_output_set_size(VideoOutput* self, gint64 width, gint64 height) {
  // Ideally, a mutex should be used here & |video_output_get_width| +
  // |video_output_get_height|. However, that is throwing everything into a
  // deadlock. Flutter itself seems to have some synchronization mechanism in
  // rendering & platform channels AFAIK.

  // H/W
  if (self->texture_gl) {
    self->width = width;
    self->height = height;
  }
  // S/W
  if (self->texture_sw) {
    self->width = CLAMP(width, 0, SW_RENDERING_MAX_WIDTH);
    self->height = CLAMP(height, 0, SW_RENDERING_MAX_HEIGHT);
  }
}

mpv_render_context* video_output_get_render_context(VideoOutput* self) {
  return self->render_context;
}

EGLDisplay video_output_get_egl_display(VideoOutput* self) {
  return self->egl_display;
}

EGLContext video_output_get_egl_context(VideoOutput* self) {
  return self->egl_context;
}

GLRenderThread* video_output_get_gl_render_thread(VideoOutput* self) {
  return self->gl_render_thread;
}

guint8* video_output_get_pixel_buffer(VideoOutput* self) {
  return self->pixel_buffer;
}

gint64 video_output_get_width(VideoOutput* self) {
  // Fixed width.
  if (self->width) {
    return self->width;
  }

  const auto [width, height] = media_kit::GetVideoDimensions(self->handle);

  if (self->texture_sw != NULL) {
    // Clamp to S/W rendering limits while maintaining aspect ratio.
    if (width >= SW_RENDERING_MAX_WIDTH) {
      return SW_RENDERING_MAX_WIDTH;
    }
    if (height >= SW_RENDERING_MAX_HEIGHT) {
      return width / height * SW_RENDERING_MAX_HEIGHT;
    }
  }

  return width;
}

gint64 video_output_get_height(VideoOutput* self) {
  // Fixed height.
  if (self->width) {
    return self->height;
  }

  const auto [width, height] = media_kit::GetVideoDimensions(self->handle);

  if (self->texture_sw != NULL) {
    // Clamp to S/W rendering limits while maintaining aspect ratio.
    if (height >= SW_RENDERING_MAX_HEIGHT) {
      return SW_RENDERING_MAX_HEIGHT;
    }
    if (width >= SW_RENDERING_MAX_WIDTH) {
      return height / width * SW_RENDERING_MAX_WIDTH;
    }
  }

  return height;
}

gint64 video_output_get_texture_id(VideoOutput* self) {
  // H/W
  if (self->texture_gl) {
    return (gint64)self->texture_gl;
  }
  // S/W
  if (self->texture_sw) {
    return (gint64)self->texture_sw;
  }
  g_assert_not_reached();
  return -1;
}

void video_output_notify_texture_update(VideoOutput* self) {
  gint64 id = video_output_get_texture_id(self);
  gint64 width = video_output_get_width(self);
  gint64 height = video_output_get_height(self);
  gpointer context = self->texture_update_callback_context;
  if (self->texture_update_callback != NULL) {
    self->texture_update_callback(id, width, height, context);
  }
}

// Both run in the dedicated GL thread.
static void video_output_check_and_resize(VideoOutput* self) {
  if (self->destroyed || !self->texture_gl) {
    return;
  }

  gint64 required_width = video_output_get_width(self);
  gint64 required_height = video_output_get_height(self);
  if (required_width < 1 || required_height < 1) {
    return;
  }

  texture_gl_check_and_resize(self->texture_gl, required_width, required_height);
}

static void video_output_render(VideoOutput* self) {
  if (self->destroyed) {
    return;
  }

  if (self->texture_gl && self->render_context) {
    if (texture_gl_render(self->texture_gl)) {
      texture_gl_swap_buffers(self->texture_gl);
      fl_texture_registrar_mark_texture_frame_available(
          self->texture_registrar, FL_TEXTURE(self->texture_gl));
    }
  }
}

void video_output_notify_render(VideoOutput* self) {
  if (self->destroyed || !self->gl_render_thread) {
    return;
  }
  self->gl_render_thread->Post([self]() {
    video_output_check_and_resize(self);
    video_output_render(self);
  });
}
