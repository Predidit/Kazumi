/* Copyright 2026 Kazumi contributors. SPDX-License-Identifier: MIT */
#ifndef KAZUMI_RIFE_BRIDGE_H
#define KAZUMI_RIFE_BRIDGE_H
#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32) && defined(KAZUMI_RIFE_EXPORTS)
#define KR_API __declspec(dllexport)
#elif defined(_WIN32)
#define KR_API __declspec(dllimport)
#else
#define KR_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif
#define KR_ABI_VERSION 4

typedef struct KrContext KrContext;
enum KrStatus {
    KR_OK, KR_INVALID_ARGUMENT, KR_NO_GPU, KR_MODEL_ERROR, KR_INFERENCE_ERROR,
};

typedef struct KrOptions {
    uint32_t abi;
    /* A hash-verified bundled model directory.
     * UTF-8, copied upon load. Do not pass a path from media metadata. */
    const char *model_directory;
    /* Null/empty = Vulkan Auto; otherwise DXGI LUID or Vulkan UUID. */
    const char *device_id;
    int cpu;  /* CPU backend is opt-in; never silently use it on GPU failure. */
    int cpu_threads;
} KrOptions;

KR_API uint32_t kr_abi(void);
KR_API int kr_create(const KrOptions *options, KrContext **result);
KR_API void kr_destroy(KrContext *context);

/* All buffers are RGB24, with positive row strides in bytes. Source and
 * destination are caller-owned. Use a context from one decoder thread only. */
/* Three chronological RGB24 frames. Time is measured about the central drawing
 * (1), within [0.5, 1.5] excluding 1. Output grid is ceil(w/64)*16 by
 * ceil(h/64)*16. Its stride is measured in KrMotion records, not bytes. */
typedef struct KrRgbView { const uint8_t *data; ptrdiff_t stride; } KrRgbView;
typedef struct KrMotion { float cx, cy, px, py, logit; } KrMotion;
KR_API int kr_predict_motion(KrContext *context, const KrRgbView frames[3], int w, int h,
                             float time, KrMotion *output, ptrdiff_t stride);
/* Warp one native plane with a grid produced by kr_predict_motion. */
typedef struct KrPlane {
    const uint8_t *center, *partner;
    uint8_t *dst;
    ptrdiff_t center_stride, partner_stride, dst_stride;
    int width, height, sub_x, sub_y, pixel_bytes, sample_bytes, padding, big_endian;
} KrPlane;
KR_API int kr_warp_plane(KrContext *context, const KrMotion *grid, int model_w, int model_h, int image_w, int image_h,
                         const KrPlane *plane, int threads);
#ifdef __cplusplus
}
#endif
#endif
