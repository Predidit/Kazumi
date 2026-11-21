/* Copyright 2026 Kazumi contributors. SPDX-License-Identifier: MIT */
#include "frame_plan.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

KazumiFramePlan kazumi_frame_plan(double previous_pts, double next_pts,
                                  unsigned multiplier, double max_fps,
                                  double max_gap, double source_fps)
{
    KazumiFramePlan result = {0};
    const double step = next_pts - previous_pts;
    if (!isfinite(previous_pts) || !isfinite(next_pts) || !isfinite(max_fps) ||
        !isfinite(max_gap) || max_fps <= 0 || max_gap <= 0 ||
        step <= 0 || step > max_gap || multiplier < 2 || multiplier > 4)
        return result;

    /* Keep the budget local to each gap so variable-rate playback does not
     * invent timestamps or lose A/V sync. An input > max_fps is untouched. */
    // Millisecond containers alternate e.g. 33/34 ms at 30 fps. Use the
    // source cadence for the cap when the measured gap is within one tick.
    // The timestamps below always use the actual bounding frames.
    double budget_step = step;
    if (source_fps > 0 && isfinite(source_fps) &&
        fabs(step - 1.0 / source_fps) <= fmin(0.001001, step * 0.05))
        budget_step = 1.0 / source_fps;
    /* Container timestamps often round a nominal 30 fps step to 33 ms. Keep
     * those pairs on the same 60 fps output cadence instead of alternating
     * between an inserted frame and the source frame rate. */
    while (multiplier > 1 && multiplier / budget_step > max_fps * 1.015)
        --multiplier;
    for (unsigned i = 1; i < multiplier; ++i) {
        const double t = (double)i / multiplier;
        const double pts = previous_pts + t * step;
        const double last = i == 1 ? previous_pts : result.pts[i - 2];
        if (!isfinite(pts) || pts <= last || pts >= next_pts)
            return (KazumiFramePlan){0};
        result.pts[i - 1] = pts;
        result.position[i - 1] = (float)t;
    }
    result.count = multiplier - 1;
    return result;
}

int kazumi_realtime_edge(KazumiRealtimeBudget *state, double work, double gap,
                         int active_edge, int minimum_edge)
{
    if (!isfinite(work) || !isfinite(gap) || work < 0 || gap <= 0)
        return active_edge;

    // Allow each new inference size to warm up. Pipeline allocation and
    // GPU compilation are not steady-state costs.
    if (state->samples == 0) {
        state->samples = 1;
        return active_edge;
    }
    const double ratio = work / gap;
    if (state->samples == 1) {
        state->average_ratio = ratio;
        state->samples = 2;
    } else {
        state->average_ratio = 0.75 * state->average_ratio + 0.25 * ratio;
    }

    const int can_reduce = active_edge > minimum_edge;
    // Leave room for decode and rendering when we can shrink. Being slightly
    // above that target does not justify disabling interpolation at the floor.
    const double limit = can_reduce ? 0.68 : 0.90;
    if (ratio > limit && state->average_ratio > limit)
        ++state->over_limit;
    else
        state->over_limit = 0;
    if (state->over_limit < (can_reduce ? 3u : 6u)) return active_edge;

    *state = (KazumiRealtimeBudget){0};
    if (!can_reduce) return 0;
    const int smaller = active_edge * 3 / 4;
    return smaller > minimum_edge ? smaller : minimum_edge;
}

static int luma(const uint8_t *p)
{
    /* Approximate BT.709, inputs are RGB24 (range 0..255). */
    return (54 * p[0] + 183 * p[1] + 19 * p[2] + 128) >> 8;
}

static int valid_stride(ptrdiff_t stride, unsigned width, unsigned height, unsigned bytes)
{
    return width > 0 && height > 0 && width <= 16384 && height <= 16384 &&
           stride >= (ptrdiff_t)width * bytes && stride <= PTRDIFF_MAX / height;
}

int kazumi_frame_difference(const uint8_t *first, ptrdiff_t first_stride,
                            const uint8_t *second, ptrdiff_t second_stride,
                            unsigned width, unsigned height,
                            KazumiFrameDifference *result)
{
    if (!result || !first || !second || !valid_stride(first_stride, width, height, 3) ||
        !valid_stride(second_stride, width, height, 3))
        return 0;

    const unsigned columns = width < 32 ? width : 32;
    const unsigned rows = height < 18 ? height : 18;
    unsigned y_delta = 0, rgb_delta = 0, changed = 0;
    for (unsigned y = 0; y < rows; ++y) {
        const unsigned source_y = ((2 * y + 1) * height) / (2 * rows);
        const uint8_t *a = first + first_stride * source_y;
        const uint8_t *b = second + second_stride * source_y;
        for (unsigned x = 0; x < columns; ++x) {
            const unsigned i = 3 * ((2 * x + 1) * width / (2 * columns));
            const unsigned d = (unsigned)abs(luma(a + i) - luma(b + i));
            const unsigned color = (unsigned)(abs(a[i] - b[i]) +
                abs(a[i + 1] - b[i + 1]) + abs(a[i + 2] - b[i + 2]));
            y_delta += d;
            rgb_delta += color;
            changed += d >= 24 || color >= 108;
        }
    }
    const double samples = (double)columns * rows;
    result->mean_luma_delta = y_delta / (samples * 255.0);
    result->mean_rgb_delta = rgb_delta / (samples * 765.0);
    result->changed_area = changed / samples;
    return 1;
}

static unsigned luma_at(KazumiLumaView view, int x, int y)
{
    const uint8_t *p = view.data + view.stride * y + view.pixel_stride * x;
    if (view.bytes == 1) return *p;
    unsigned value = view.big_endian ? (unsigned)p[0] << 8 | p[1]
                                     : (unsigned)p[1] << 8 | p[0];
    return (value >> view.shift) & 255u;
}

/* A vertical stem differs from the background on both sides. Using local
 * contrast accommodates dark, tinted and unoutlined text. A single edge
 * (or a long horizontal anime line) is not a stem. */
static int caption_stroke(KazumiLumaView view, int x, int y, int radius)
{
    const int center = luma_at(view, x, y);
    for (int d = radius; d <= radius * 2; d += radius) {
        const int left = center - (int)luma_at(view, x - d, y);
        const int right = center - (int)luma_at(view, x + d, y);
        if ((left >= 20 && right >= 20) || (left <= -20 && right <= -20))
            return 1;
    }
    return 0;
}

static int valid_luma(KazumiLumaView view, int w, int h)
{
    if (!view.data || (view.bytes != 1 && view.bytes != 2) ||
        view.pixel_stride < view.bytes || view.pixel_stride > 8 || view.stride == PTRDIFF_MIN ||
        view.shift < 0 || view.shift > 8 || (view.bytes == 1 && view.shift != 0)) return 0;
    return valid_stride(view.stride < 0 ? -view.stride : view.stride, w, h, view.pixel_stride);
}

// A temporal dissolve can turn a panning grating into a flat gray flash.
// Compare the signed unit gradients of the native endpoints. Require strong
// *opposite* gradients across the tile, not just a single moving contour.
static int classify_texture(KazumiLumaView a, KazumiLumaView b, int x, int y,
                              int end_x, int end_y)
{
    int samples = 0, shared = 0, opposed = 0;
    for (int row = y; row + 1 < end_y; row += 3) {
        for (int col = x; col + 1 < end_x; col += 3) {
            const int left = luma_at(a, col, row), right = luma_at(b, col, row);
            const int ax = left - (int)luma_at(a, col + 1, row);
            const int bx = right - (int)luma_at(b, col + 1, row);
            const int ay = left - (int)luma_at(a, col, row + 1);
            const int by = right - (int)luma_at(b, col, row + 1);
            shared += abs(left - right) <= 16 &&
                ((abs(ax) >= 32 && abs(ax - bx) <= 8) || (abs(ay) >= 32 && abs(ay - by) <= 8));
            opposed += (abs(ax - bx) >= 64 && abs(ax + bx) * 3 < abs(ax - bx)) ||
                       (abs(ay - by) >= 64 && abs(ay + by) * 3 < abs(ay - by));
            ++samples;
        }
    }
    if (samples >= 4 && opposed * 2 >= samples) return KAZUMI_TEXTURE_OPPOSED;
    if (samples >= 4 && shared * 3 >= samples) return KAZUMI_TEXTURE_SHARED;
    return KAZUMI_TEXTURE_NONE;
}

// A screen full of texture produces stems too, but spans many tile rows.
static void prune_tall_runs(uint8_t *votes, int columns, int rows, int max_rows)
{
    for (int x = 0; x < columns; ++x) {
        for (int y = 0; y < rows;) {
            const int start = y;
            while (y < rows && votes[y * columns + x] >= 2) ++y;
            if (y - start > max_rows) {
                for (int i = start; i < y; ++i) votes[i * columns + x] = 0;
            }
            ++y;
        }
    }
}

// Stems in an animation drawing can be bright and narrow too. A third
// frame can confirm a screen-fixed stroke even when a cue starts or ends.
static int same_stroke(KazumiLumaView a, const KazumiLumaView *b, int x, int y, int radius)
{
    return b && abs((int)luma_at(a,x,y) - (int)luma_at(*b,x,y)) <= 2 &&
           caption_stroke(*b,x,y,radius);
}

int kazumi_detail_masks(KazumiLumaView first, KazumiLumaView second,
                         int width, int height, uint8_t *mask, uint8_t *scratch,
                        const KazumiLumaView *before, const KazumiLumaView *after)
{
    if (!mask || !scratch || !valid_luma(first, width, height) ||
        !valid_luma(second, width, height))
        return -1;
    if ((before && !valid_luma(*before, width, height)) || (after && !valid_luma(*after, width, height)))
        return -1;
    const int contextual = before || after;
    const int t = KAZUMI_DETAIL_TILE;
    const int columns = (width + t - 1) / t, rows = (height + t - 1) / t;
    memset(mask, 0, (size_t)columns * rows);
    memset(scratch, 0, (size_t)columns * rows);
    int radius = (height + 89) / 180;
    if (radius < 2) radius = 2;
    if (radius > 10) radius = 10;
    const int step = height >= 1440 ? 3 : height >= 720 ? 2 : 1;

    // Keep independent votes for possible stems (either endpoint, including
    // a cue change) and screen-locked stems (both endpoints). Moving texture
    // behind a line must not disqualify the stationary text along with it.
    for (int y = 0; y < height; y += step) {
        const int row = y / t * columns;
        for (int x = 2 * radius; x < width - 2 * radius; x += step) {
            const int i = row + x / t;
            if (mask[i] == 2) continue; // both vote counts are saturated
            const int a = caption_stroke(first, x, y, radius);
            const int b = caption_stroke(second, x, y, radius);
            const int locked = a && b && abs((int)luma_at(first,x,y) - (int)luma_at(second,x,y)) <= 2;
            if (contextual) {
                if (locked || (a && same_stroke(first, before, x, y, radius)) ||
                              (b && same_stroke(second, after, x, y, radius)))
                    ++mask[i];
            } else {
                if (scratch[i] < 2 && (a || b)) ++scratch[i];
                if (locked) ++mask[i];
            }
        }
    }
    const int max_rows = 2 + (height / 12) / t;
    prune_tall_runs(scratch, columns, rows, max_rows);
    prune_tall_runs(mask, columns, rows, max_rows);
    for (int i = 0; i < rows * columns; ++i)
        scratch[i] = scratch[i] >= 2 || mask[i] >= 2;
    memset(mask, 0, (size_t)columns * rows);

    int found = 0;
    for (int y = 0; y < rows; ++y) {
        for (int x = 0; x < columns; ++x) {
            if (!scratch[y * columns + x]) continue;
            // Captions run across a line. Ignore isolated highlights and
            // edges with no neighboring strokes in another column.
            int adjacent = 0;
            for (int xx = x - 3; xx <= x + 3; ++xx) {
                if (xx < 0 || xx >= columns || xx == x) continue;
                for (int yy = y - 1; yy <= y + 1; ++yy) {
                    if (yy >= 0 && yy < rows && scratch[yy * columns + xx]) {
                        ++adjacent;
                        break;
                    }
                }
            }
            if (adjacent < 2) continue;
            // Include the outline, antialiasing and a margin for miswarps.
            for (int yy = y - 1; yy <= y + 1; ++yy) {
                if (yy < 0 || yy >= rows) continue;
                for (int xx = x - 1; xx <= x + 1; ++xx) {
                    if (xx >= 0 && xx < columns) mask[yy * columns + xx] = 1;
                }
            }
            found = 1;
        }
    }
    // The second grid is no longer needed for counting stems. Reuse it for
    // pair-wide texture holds so all fractional times make the same choice.
    for (int y = 0; y < height; y += t) {
        for (int x = 0; x < width; x += t) {
            scratch[y / t * columns + x / t] = classify_texture(first, second, x, y,
                x + t < width ? x + t : width, y + t < height ? y + t : height);
        }
    }
    return found;
}
