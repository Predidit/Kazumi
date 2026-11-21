#ifndef MEDIA_KIT_MPV_H
#define MEDIA_KIT_MPV_H
#include "mpv/client.h"
#include "mpv/render.h"
#include "mpv/render_gl.h"
#ifdef __cplusplus
extern "C" {
#endif
// Bind to the same library that owns the Dart player's handle. Returns zero on
// success, -1 on a missing library/symbol, -2 if a different mpv is already bound.
int media_kit_mpv_initialize(const char *path);
const char *media_kit_mpv_error_string(int error);
void media_kit_mpv_free_node_contents(mpv_node *node);
int media_kit_mpv_get_property(mpv_handle *handle, const char *name, mpv_format format, void *data);
int media_kit_mpv_set_option_string(mpv_handle *handle, const char *name, const char *value);
int media_kit_mpv_render_context_create(mpv_render_context **context, mpv_handle *handle, mpv_render_param *params);
void media_kit_mpv_render_context_free(mpv_render_context *context);
int media_kit_mpv_render_context_render(mpv_render_context *context, mpv_render_param *params);
void media_kit_mpv_render_context_report_swap(mpv_render_context *context);
void media_kit_mpv_render_context_set_update_callback(mpv_render_context *context, mpv_render_update_fn callback, void *data);
#ifdef __cplusplus
}
#endif

#ifndef MEDIA_KIT_MPV_IMPLEMENTATION
#define mpv_error_string media_kit_mpv_error_string
#define mpv_free_node_contents media_kit_mpv_free_node_contents
#define mpv_get_property media_kit_mpv_get_property
#define mpv_set_option_string media_kit_mpv_set_option_string
#define mpv_render_context_create media_kit_mpv_render_context_create
#define mpv_render_context_free media_kit_mpv_render_context_free
#define mpv_render_context_render media_kit_mpv_render_context_render
#define mpv_render_context_report_swap media_kit_mpv_render_context_report_swap
#define mpv_render_context_set_update_callback media_kit_mpv_render_context_set_update_callback
#endif
#endif
