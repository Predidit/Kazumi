// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/video_output_manager.h"

struct _VideoOutputManager {
  GObject parent_instance;
  GHashTable* video_outputs;
  FlTextureRegistrar* texture_registrar;
  GLRenderThread* gl_render_thread; /* Shared by all |VideoOutput|s. */
};

G_DEFINE_TYPE(VideoOutputManager, video_output_manager, G_TYPE_OBJECT)

static void video_output_manager_init(VideoOutputManager* self) {
  self->video_outputs = g_hash_table_new_full(g_direct_hash, g_direct_equal,
                                              nullptr, g_object_unref);
  self->gl_render_thread = new GLRenderThread();
}

static void video_output_manager_dispose(GObject* object) {
  VideoOutputManager* self = VIDEO_OUTPUT_MANAGER(object);
  g_hash_table_unref(self->video_outputs);
  delete self->gl_render_thread;
  G_OBJECT_CLASS(video_output_manager_parent_class)->dispose(object);
}

static void video_output_manager_class_init(VideoOutputManagerClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = video_output_manager_dispose;
}

VideoOutputManager* video_output_manager_new(
    FlTextureRegistrar* texture_registrar) {
  VideoOutputManager* video_output_manager = VIDEO_OUTPUT_MANAGER(
      g_object_new(video_output_manager_get_type(), nullptr));
  video_output_manager->texture_registrar = texture_registrar;
  return video_output_manager;
}

void video_output_manager_create(VideoOutputManager* self,
                                 gint64 handle,
                                 VideoOutputConfiguration configuration,
                                 TextureUpdateCallback texture_update_callback,
                                 gpointer texture_update_callback_context) {
  if (!g_hash_table_contains(self->video_outputs, GINT_TO_POINTER(handle))) {
    g_autoptr(VideoOutput) video_output = video_output_new(
        self->texture_registrar, handle, configuration, self->gl_render_thread);
    video_output_set_texture_update_callback(
        video_output, texture_update_callback, texture_update_callback_context);
    g_hash_table_insert(self->video_outputs, GINT_TO_POINTER(handle),
                        g_object_ref(video_output));
  }
}

void video_output_manager_set_size(VideoOutputManager* self,
                                   gint64 handle,
                                   gint64 width,
                                   gint64 height) {
  if (g_hash_table_contains(self->video_outputs, GINT_TO_POINTER(handle))) {
    VideoOutput* video_output = VIDEO_OUTPUT(
        g_hash_table_lookup(self->video_outputs, GINT_TO_POINTER(handle)));
    video_output_set_size(video_output, width, height);
  }
}

void video_output_manager_dispose(VideoOutputManager* self, gint64 handle) {
  if (g_hash_table_contains(self->video_outputs, GINT_TO_POINTER(handle))) {
    g_hash_table_remove(self->video_outputs, GINT_TO_POINTER(handle));
  }
}
