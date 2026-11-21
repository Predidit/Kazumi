/* Copyright 2026 Kazumi contributors. SPDX-License-Identifier: MIT */
#ifndef KAZUMI_FRAME_PLAN_H
#define KAZUMI_FRAME_PLAN_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Output does not resample the source timeline: original frames keep their
 * own timestamps. Each valid gap gets at most three strictly interior frames. */
typedef struct KazumiFramePlan {
    unsigned count;
    double pts[3];
    float position[3];
} KazumiFramePlan;

KazumiFramePlan kazumi_frame_plan(double previous_pts, double next_pts,
                                  unsigned multiplier, double max_fps,
                                  double max_gap, double source_fps);

typedef struct KazumiRealtimeBudget {
    unsigned samples, over_limit;
    double average_ratio;
} KazumiRealtimeBudget;

/* Observe one complete pair of inference work. Return the next long edge,
 * the existing edge to continue, or zero to keep the source cadence. */
int kazumi_realtime_edge(KazumiRealtimeBudget *state, double work, double gap,
                         int active_edge, int minimum_edge);

typedef struct KazumiFrameDifference {
    double mean_luma_delta;
    double changed_area;
    double mean_rgb_delta;
} KazumiFrameDifference;

/* Bounded 32x18 comparison, independent of frame size. Return false on
 * malformed row sizes. An optional frame-pair policy decides when to skip. */
int kazumi_frame_difference(const uint8_t *first, ptrdiff_t first_stride,
                            const uint8_t *second, ptrdiff_t second_stride,
                            unsigned width, unsigned height,
                            KazumiFrameDifference *result);

/* Native luma view, including 10/12/16-bit planar and P010-style formats. */
typedef struct KazumiLumaView {
    const uint8_t *data;
    ptrdiff_t stride;
    int bytes, shift, big_endian, pixel_stride;
} KazumiLumaView;

#define KAZUMI_DETAIL_TILE 16

enum KazumiTexture { KAZUMI_TEXTURE_NONE, KAZUMI_TEXTURE_SHARED, KAZUMI_TEXTURE_OPPOSED };

/* Write two ceil(width/16) * ceil(height/16) tile maps. The first protects
 * caption strokes present in either endpoint. The second classifies native gradients as shared,
 * opposed (would cancel in a temporal blend), or neither. Return 1 if captions were found,
 * 0 for a valid map without captions, or -1 for an invalid view. Optional
 * same-shot neighbors confirm screen-locked strokes for the three-frame path. */
int kazumi_detail_masks(KazumiLumaView first, KazumiLumaView second,
                        int width, int height, uint8_t *captions, uint8_t *texture,
                        const KazumiLumaView *before, const KazumiLumaView *after);

#ifdef __cplusplus
}
#endif
#endif
