// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/texture_gl.h"
#include "include/media_kit_video/gl_render_thread.h"

#include <epoxy/gl.h>
#include <epoxy/egl.h>
#include <atomic>
#include <mutex>
#include <vector>

#define NUM_BUFFERS 3

// One buffer of the mailbox model; each owns its full set of GPU resources.
typedef struct {
  guint32 fbo;              // FBO mpv renders into (mpv context)
  guint32 texture;          // Texture backing the FBO (mpv context)
  EGLImageKHR egl_image;    // Shares |texture| across contexts
  guint32 flutter_texture;  // Flutter-side texture bound to |egl_image|
  EGLContext flutter_context;  // Raster context |flutter_texture| was created in
  gboolean flutter_texture_valid;
  std::atomic<EGLSyncKHR> render_sync;  // Fence from producer, consumed cross-thread
} RenderBuffer;

/**
 * Mailbox triple buffering with a drain-only consumer (intentional design:
 * the producer may overwrite the mailbox frame; dropped frames are expected).
 *
 * Roles rotate via atomic index swaps:
 * - back:    producer (GL thread) renders here, owns back_index exclusively
 * - mailbox: latest complete frame + dirty flag
 * - front:   consumer (Flutter raster thread) displays, owns front_index
 *
 * mailbox_state packs both fields into ONE atomic — (dirty << 8) | index —
 * so checking dirty and swapping the index cannot race.
 *
 * Producer: render to back → exchange (dirty=1, back_index) into mailbox,
 * old mailbox index becomes the new back buffer.
 * Consumer (drain-only): CAS-swap only when dirty=1; otherwise keep
 * displaying the current front buffer.
 */
struct _TextureGL {
  FlTextureGL parent_instance;

  RenderBuffer buffers[NUM_BUFFERS];

  int back_index;                  // GL thread only
  int front_index;                 // Raster thread only
  std::atomic<int> mailbox_state;  // (dirty << 8) | index

  guint32 current_width;
  guint32 current_height;
  gboolean buffers_initialized;
  gboolean initialization_posted;
  std::atomic<gboolean> resizing;

  VideoOutput* video_output;
};

G_DEFINE_TYPE(TextureGL, texture_gl, fl_texture_gl_get_type())

// GL texture names are only meaningful inside the share group that created
// them. |flutter_texture|s are created in populate (Flutter's raster context),
// but dispose runs on the platform thread where that context is never
// current — deleting there would leak the real texture, or delete an
// unrelated same-named object in GDK's own context. So dispose parks the
// names here, tagged with their creating context, and the next populate of
// any |TextureGL| reclaims exactly those entries whose context is current.
// The tag is essential with multiple Flutter engines in one process: a bare
// name must never be deleted in another engine's context.
typedef struct {
  EGLContext context;  // Raster context the name was created in.
  guint32 texture;
} RetiredTexture;

static std::mutex retired_textures_mutex;
static std::vector<RetiredTexture> retired_textures;

static void retire_flutter_texture(EGLContext context, guint32 texture) {
  std::lock_guard<std::mutex> lock(retired_textures_mutex);
  retired_textures.push_back({context, texture});
}

// Must be called with a Flutter raster context current. Entries belonging to
// other contexts (other engines) are left for their own populate.
static void drain_retired_textures() {
  EGLContext current_context = eglGetCurrentContext();
  if (current_context == EGL_NO_CONTEXT) {
    return;
  }
  std::vector<guint32> reclaimable;
  {
    std::lock_guard<std::mutex> lock(retired_textures_mutex);
    auto it = retired_textures.begin();
    while (it != retired_textures.end()) {
      if (it->context == current_context) {
        reclaimable.push_back(it->texture);
        it = retired_textures.erase(it);
      } else {
        ++it;
      }
    }
  }
  for (guint32 texture : reclaimable) {
    glDeleteTextures(1, &texture);
  }
}

static void texture_gl_init(TextureGL* self) {
  for (int i = 0; i < NUM_BUFFERS; i++) {
    self->buffers[i].fbo = 0;
    self->buffers[i].texture = 0;
    self->buffers[i].egl_image = EGL_NO_IMAGE_KHR;
    self->buffers[i].flutter_texture = 0;
    self->buffers[i].flutter_context = EGL_NO_CONTEXT;
    self->buffers[i].flutter_texture_valid = FALSE;
    self->buffers[i].render_sync.store(EGL_NO_SYNC_KHR, std::memory_order_relaxed);
  }

  // back=0, front=1, mailbox=2 (not dirty).
  self->back_index = 0;
  self->front_index = 1;
  self->mailbox_state.store(2, std::memory_order_relaxed);

  self->current_width = 1;
  self->current_height = 1;
  self->buffers_initialized = FALSE;
  self->initialization_posted = FALSE;
  self->resizing.store(FALSE, std::memory_order_relaxed);
  self->video_output = NULL;
}

static void texture_gl_dispose(GObject* object) {
  TextureGL* self = TEXTURE_GL(object);
  VideoOutput* video_output = self->video_output;
  GLRenderThread* gl_thread = video_output_get_gl_render_thread(video_output);

  // Flutter-side textures belong to the raster context; park them for the
  // next populate instead of deleting in whatever context is current here.
  for (int i = 0; i < NUM_BUFFERS; i++) {
    if (self->buffers[i].flutter_texture != 0) {
      retire_flutter_texture(self->buffers[i].flutter_context,
                             self->buffers[i].flutter_texture);
      self->buffers[i].flutter_texture = 0;
      self->buffers[i].flutter_context = EGL_NO_CONTEXT;
    }
  }

  // Everything else must be released in the dedicated GL thread.
  if (video_output != NULL && gl_thread != NULL) {
    gl_thread->PostAndWait([self, video_output]() {
      EGLDisplay egl_display = video_output_get_egl_display(video_output);
      EGLContext egl_context = video_output_get_egl_context(video_output);

      for (int i = 0; i < NUM_BUFFERS; i++) {
        RenderBuffer* buf = &self->buffers[i];

        EGLSyncKHR sync = buf->render_sync.load(std::memory_order_acquire);
        if (sync != EGL_NO_SYNC_KHR) {
          eglDestroySyncKHR(egl_display, sync);
          buf->render_sync.store(EGL_NO_SYNC_KHR, std::memory_order_release);
        }

        if (buf->egl_image != EGL_NO_IMAGE_KHR) {
          eglDestroyImageKHR(egl_display, buf->egl_image);
          buf->egl_image = EGL_NO_IMAGE_KHR;
        }
      }

      // mpv-side GL objects live in the isolated context.
      if (egl_context != EGL_NO_CONTEXT) {
        eglMakeCurrent(egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, egl_context);

        for (int i = 0; i < NUM_BUFFERS; i++) {
          RenderBuffer* buf = &self->buffers[i];

          if (buf->texture != 0) {
            glDeleteTextures(1, &buf->texture);
            buf->texture = 0;
          }
          if (buf->fbo != 0) {
            glDeleteFramebuffers(1, &buf->fbo);
            buf->fbo = 0;
          }
        }
      }
    });
  }

  self->current_width = 1;
  self->current_height = 1;
  self->video_output = NULL;
  G_OBJECT_CLASS(texture_gl_parent_class)->dispose(object);
}

static void texture_gl_class_init(TextureGLClass* klass) {
  FL_TEXTURE_GL_CLASS(klass)->populate = texture_gl_populate_texture;
  G_OBJECT_CLASS(klass)->dispose = texture_gl_dispose;
}

TextureGL* texture_gl_new(VideoOutput* video_output) {
  TextureGL* self = TEXTURE_GL(g_object_new(texture_gl_get_type(), NULL));
  self->video_output = video_output;
  return self;
}

/**
 * Creates or resizes all three buffers. Runs in the dedicated GL thread.
 */
void texture_gl_check_and_resize(TextureGL* self, gint64 required_width, gint64 required_height) {
  VideoOutput* video_output = self->video_output;

  if (required_width < 1 || required_height < 1) {
    return;
  }

  gboolean first_frame = !self->buffers_initialized;
  gboolean resize = self->current_width != (guint32)required_width ||
                    self->current_height != (guint32)required_height;

  if (!first_frame && !resize) {
    return;
  }

  EGLDisplay egl_display = video_output_get_egl_display(video_output);
  EGLContext egl_context = video_output_get_egl_context(video_output);

  eglMakeCurrent(egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, egl_context);

  // Keep the consumer off the buffers while they are being recreated.
  self->resizing.store(TRUE, std::memory_order_release);

  for (int i = 0; i < NUM_BUFFERS; i++) {
    RenderBuffer* buf = &self->buffers[i];

    if (!first_frame) {
      // Wait for pending GPU work before destroying resources.
      EGLSyncKHR sync = buf->render_sync.load(std::memory_order_acquire);
      if (sync != EGL_NO_SYNC_KHR) {
        eglClientWaitSyncKHR(egl_display, sync,
                              EGL_SYNC_FLUSH_COMMANDS_BIT_KHR, EGL_FOREVER_KHR);
        eglDestroySyncKHR(egl_display, sync);
        buf->render_sync.store(EGL_NO_SYNC_KHR, std::memory_order_release);
      }

      if (buf->egl_image != EGL_NO_IMAGE_KHR) {
        eglDestroyImageKHR(egl_display, buf->egl_image);
        buf->egl_image = EGL_NO_IMAGE_KHR;
      }

      glDeleteTextures(1, &buf->texture);
      glDeleteFramebuffers(1, &buf->fbo);
    }

    glGenFramebuffers(1, &buf->fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, buf->fbo);

    glGenTextures(1, &buf->texture);
    glBindTexture(GL_TEXTURE_2D, buf->texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, required_width, required_height,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, buf->texture, 0);

    EGLint egl_image_attribs[] = { EGL_NONE };
    buf->egl_image = eglCreateImageKHR(
        egl_display,
        egl_context,
        EGL_GL_TEXTURE_2D_KHR,
        (EGLClientBuffer)(guintptr)buf->texture,
        egl_image_attribs);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);

    // Flutter-side texture must be recreated against the new EGLImage.
    buf->flutter_texture_valid = FALSE;
    buf->render_sync.store(EGL_NO_SYNC_KHR, std::memory_order_release);
  }

  glFlush();

  // Reset mailbox: back=0, front=1, mailbox=2 (not dirty).
  self->back_index = 0;
  self->front_index = 1;
  self->mailbox_state.store(2, std::memory_order_release);

  self->buffers_initialized = TRUE;
  self->current_width = required_width;
  self->current_height = required_height;

  self->resizing.store(FALSE, std::memory_order_release);
}

/**
 * Renders an mpv frame to the back buffer. Runs in the dedicated GL thread.
 */
gboolean texture_gl_render(TextureGL* self) {
  VideoOutput* video_output = self->video_output;
  EGLDisplay egl_display = video_output_get_egl_display(video_output);
  EGLContext egl_context = video_output_get_egl_context(video_output);
  mpv_render_context* render_context = video_output_get_render_context(video_output);

  if (!render_context || !self->buffers_initialized) {
    return FALSE;
  }

  RenderBuffer* back_buf = &self->buffers[self->back_index];
  if (back_buf->fbo == 0) {
    return FALSE;
  }

  // GPU must be done with this buffer before it is overwritten.
  EGLSyncKHR old_sync = back_buf->render_sync.exchange(EGL_NO_SYNC_KHR, std::memory_order_acq_rel);
  if (old_sync != EGL_NO_SYNC_KHR) {
    eglClientWaitSyncKHR(egl_display, old_sync, EGL_SYNC_FLUSH_COMMANDS_BIT_KHR, EGL_FOREVER_KHR);
    eglDestroySyncKHR(egl_display, old_sync);
  }

  eglMakeCurrent(egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, egl_context);

  glBindFramebuffer(GL_FRAMEBUFFER, back_buf->fbo);
  mpv_opengl_fbo fbo{(gint32)back_buf->fbo, (gint32)self->current_width,
                     (gint32)self->current_height, 0};
  int flip_y = 0;
  mpv_render_param params[] = {
      {MPV_RENDER_PARAM_OPENGL_FBO, &fbo},
      {MPV_RENDER_PARAM_FLIP_Y, &flip_y},
      {MPV_RENDER_PARAM_INVALID, NULL},
  };
  mpv_render_context_render(render_context, params);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);

  // Submit commands, then publish a fence the consumer synchronizes against.
  glFlush();
  EGLSyncKHR new_sync = eglCreateSyncKHR(egl_display, EGL_SYNC_FENCE_KHR, NULL);
  back_buf->render_sync.store(new_sync, std::memory_order_release);

  return TRUE;
}

/**
 * Publishes the rendered frame: atomically moves back_index into the mailbox
 * with dirty=1; the old mailbox buffer becomes the new back buffer.
 */
void texture_gl_swap_buffers(TextureGL* self) {
  int new_state = (1 << 8) | self->back_index;
  int old_state = self->mailbox_state.exchange(new_state, std::memory_order_acq_rel);
  self->back_index = old_state & 0xFF;
}

// 1x1 placeholder returned while buffers are unavailable. thread_local: each
// engine populates from its own raster thread, so the name never leaks into
// another engine's context.
static guint32 get_dummy_texture() {
  static thread_local guint32 dummy_texture = 0;
  if (dummy_texture == 0) {
    glGenTextures(1, &dummy_texture);
    glBindTexture(GL_TEXTURE_2D, dummy_texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glBindTexture(GL_TEXTURE_2D, 0);
  }
  return dummy_texture;
}

/**
 * Consumer side of the mailbox. Called from Flutter's raster thread.
 */
gboolean texture_gl_populate_texture(FlTextureGL* texture,
                                     guint32* target,
                                     guint32* name,
                                     guint32* width,
                                     guint32* height,
                                     GError** error) {
  TextureGL* self = TEXTURE_GL(texture);
  VideoOutput* video_output = self->video_output;
  GLRenderThread* gl_thread = video_output_get_gl_render_thread(video_output);
  EGLDisplay egl_display = video_output_get_egl_display(video_output);

  // populate is the only place the FlTextureGL contract guarantees Flutter's
  // raster context is current — reclaim parked texture names here.
  drain_retired_textures();

  // Kick off buffer initialization on first call.
  if (!self->initialization_posted && !self->buffers_initialized) {
    gint64 required_width = video_output_get_width(video_output);
    gint64 required_height = video_output_get_height(video_output);

    if (required_width > 0 && required_height > 0 && gl_thread) {
      self->initialization_posted = TRUE;
      video_output_notify_render(video_output);
    }
  }

  if (self->resizing.load(std::memory_order_acquire)) {
    *target = GL_TEXTURE_2D;
    *name = get_dummy_texture();
    *width = 1;
    *height = 1;
    return TRUE;
  }

  // Drain-only: CAS-swap our front buffer into the mailbox only when it holds
  // a new frame (dirty bit 8 set); otherwise keep the current front buffer.
  int current_state = self->mailbox_state.load(std::memory_order_acquire);
  while (current_state & 0x100) {
    int new_state = self->front_index;  // dirty=0, index=front_index
    if (self->mailbox_state.compare_exchange_weak(current_state, new_state,
                                                   std::memory_order_acq_rel,
                                                   std::memory_order_acquire)) {
      self->front_index = current_state & 0xFF;
      break;
    }
  }

  RenderBuffer* front_buf = &self->buffers[self->front_index];

  // Take ownership of the producer's fence and wait on it — GPU-side when
  // possible (queues the wait in Flutter's command stream without blocking).
  EGLSyncKHR sync = front_buf->render_sync.exchange(EGL_NO_SYNC_KHR, std::memory_order_acq_rel);
  if (sync != EGL_NO_SYNC_KHR) {
    if (epoxy_has_egl_extension(egl_display, "EGL_KHR_wait_sync")) {
      eglWaitSyncKHR(egl_display, sync, 0);
    } else {
      eglClientWaitSyncKHR(egl_display, sync, EGL_SYNC_FLUSH_COMMANDS_BIT_KHR, EGL_FOREVER_KHR);
    }
    eglDestroySyncKHR(egl_display, sync);
  }

  // (Re)bind Flutter's texture to this buffer's EGLImage if invalidated.
  if (!front_buf->flutter_texture_valid && front_buf->egl_image != EGL_NO_IMAGE_KHR) {
    if (front_buf->flutter_texture != 0) {
      if (front_buf->flutter_context == eglGetCurrentContext()) {
        glDeleteTextures(1, &front_buf->flutter_texture);
      } else {
        retire_flutter_texture(front_buf->flutter_context,
                               front_buf->flutter_texture);
      }
    }

    glGenTextures(1, &front_buf->flutter_texture);
    front_buf->flutter_context = eglGetCurrentContext();
    glBindTexture(GL_TEXTURE_2D, front_buf->flutter_texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, front_buf->egl_image);
    glBindTexture(GL_TEXTURE_2D, 0);

    front_buf->flutter_texture_valid = TRUE;

    video_output_notify_texture_update(video_output);
  }

  *target = GL_TEXTURE_2D;
  *name = front_buf->flutter_texture;
  *width = self->current_width;
  *height = self->current_height;

  if (!front_buf->flutter_texture_valid) {
    *name = get_dummy_texture();
    *width = 1;
    *height = 1;
  }

  return TRUE;
}
