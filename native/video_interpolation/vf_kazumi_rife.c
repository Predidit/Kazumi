/* Copyright 2026 Kazumi contributors. SPDX-License-Identifier: MIT */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <math.h>
#include <stdint.h>
#include <string.h>
#include <libavutil/pixdesc.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <dlfcn.h>
#endif

#include "common/common.h"
#include "filters/filter.h"
#include "filters/filter_internal.h"
#include "filters/user_filters.h"
#include "options/m_option.h"
#include "osdep/timer.h"
#include "video/img_format.h"
#include "video/mp_image.h"
#include "video/fmt-conversion.h"
#include "video/sws_utils.h"
#include "frame_plan.h"
#include "neural_runtime.h"

struct opts {
    char *model, *device;
    int multiplier, maximum_edge, starting_edge, threads;
    double maximum_fps, maximum_gap, scene_threshold, static_threshold;
    bool cpu, realtime_guard;
};

struct priv {
    struct opts *opts;
    struct api api;
    KrContext *context;
    struct mp_sws_context *convert_input;
    struct mp_image *previous, *pending, *rgb_previous, *rgb_pending;
    struct mp_image *history, *lookahead, *rgb_history, *rgb_lookahead;
    bool awaiting_context, use_history, use_lookahead, same_shot;
    double preceding_gap;
    KrMotion *motion;
    size_t motion_capacity;
    KazumiFramePlan plan;
    unsigned index;
    bool over_budget, hold_pair;
    int64_t pair_work_ns;
    int adaptive_edge;
    KazumiRealtimeBudget budget;
    bool inference_failed;
    uint8_t *caption_storage;
    size_t caption_capacity;
    bool captions;
    uint8_t *texture_map;
    int sample_bytes, sample_padding;
    bool sample_big_endian;
};

static void reset(struct mp_filter *f)
{
    struct priv *p = f->priv;
    mp_image_unrefp(&p->previous);
    mp_image_unrefp(&p->pending);
    mp_image_unrefp(&p->rgb_previous);
    mp_image_unrefp(&p->rgb_pending);
    mp_image_unrefp(&p->history);
    mp_image_unrefp(&p->lookahead);
    mp_image_unrefp(&p->rgb_history);
    mp_image_unrefp(&p->rgb_lookahead);
    p->awaiting_context = p->use_history = p->use_lookahead = p->same_shot = false;
    p->preceding_gap = 0;
    p->plan = (KazumiFramePlan){0};
    p->index = 0;
    p->budget = (KazumiRealtimeBudget){0};
    p->over_budget = false;
    p->adaptive_edge = p->opts->realtime_guard && p->opts->starting_edge > 0
        ? MPMIN(p->opts->maximum_edge, p->opts->starting_edge) : p->opts->maximum_edge;
}

static void destroy(struct mp_filter *f)
{
    struct priv *p = f->priv;
    reset(f);
    if (p->context) p->api.destroy(p->context);
    close_runtime(&p->api);
}

static bool allow_format(const struct mp_image *image)
{
    if (!image || !image->planes[0] || image->hwctx ||
        (image->fields & MP_IMGFIELD_INTERLACED) ||
        (image->fmt.flags & MP_IMGFLAG_ALPHA) || image->dovi ||
        image->params.color.transfer == PL_COLOR_TRC_PQ ||
        image->params.color.transfer == PL_COLOR_TRC_HLG)
        return false;
    return image->w > 0 && image->h > 0 && image->w <= 4096 &&
           image->h <= 4096 && image->w * image->h <= 3840 * 2160;
}

static bool convert_rgb(struct mp_sws_context *sws, struct mp_image **slot,
                        struct mp_image *source, int width, int height)
{
    if (!*slot || (*slot)->w != width || (*slot)->h != height) {
        mp_image_unrefp(slot);
        *slot = mp_image_alloc(IMGFMT_RGB24, width, height);
    }
    if (!*slot) return false;
    struct mp_image *rgb = *slot;
    rgb->params.color = source->params.color;
    rgb->params.repr.sys = PL_COLOR_SYSTEM_RGB;
    rgb->params.repr.levels = PL_COLOR_LEVELS_FULL;
    return mp_sws_scale(sws, rgb, source) >= 0;
}

static int caption_grid(int size)
{
    return (size + KAZUMI_DETAIL_TILE - 1) / KAZUMI_DETAIL_TILE;
}

// Establish the storage layout once per pair. In particular P010 stores a
// 10-bit sample in the high bits and NV12 interleaves U and V in one plane.
static bool native_samples(struct priv *p, const AVPixFmtDescriptor *fmt)
{
    const struct mp_image *image = p->previous;
    if (!fmt || (image->fmt.flags & MP_IMGFLAG_TYPE_MASK) != MP_IMGFLAG_TYPE_UINT ||
        (image->fmt.flags & MP_IMGFLAG_PACKED_SS_YUV))
        return false;
    const AVComponentDescriptor first = fmt->comp[0];
    if (first.depth < 8 || first.depth > 16 || first.shift < 0) return false;
    const int bytes = (first.depth + first.shift + 7) / 8;
    if (bytes != 1 && bytes != 2) return false;
    for (int i = 0; i < fmt->nb_components; ++i) {
        const AVComponentDescriptor c = fmt->comp[i];
        if (c.depth != first.depth || c.shift != first.shift || c.offset < 0 ||
            c.offset % bytes || c.offset + bytes > c.step || c.step % bytes ||
            image->fmt.bpp[c.plane] != c.step * 8)
            return false;
    }
    p->sample_bytes = bytes;
    p->sample_padding = first.shift;
    p->sample_big_endian = !!(fmt->flags & AV_PIX_FMT_FLAG_BE);
    return true;
}

static bool find_captions(struct priv *p, const AVPixFmtDescriptor *fmt)
{
    const struct mp_image *a = p->previous, *b = p->pending;
    // Native Y in YUV/gray, or green as a luminance proxy in integer RGB.
    const AVComponentDescriptor c = fmt->comp[!!(fmt->flags & AV_PIX_FMT_FLAG_RGB)];
    const size_t size = (size_t)caption_grid(a->w) * caption_grid(a->h);
    if (size > p->caption_capacity) {
        uint8_t *storage = talloc_realloc(p, p->caption_storage, uint8_t, size * 2);
        if (!storage) return false;
        p->caption_storage = storage;
        p->caption_capacity = size;
    }
    const int shift = c.shift + c.depth - 8;
    const struct mp_image *frames[4] = {a, b, p->use_history ? p->history : NULL,
                                       p->use_lookahead ? p->lookahead : NULL};
    KazumiLumaView views[4] = {0};
    for (int i = 0; i < 4; ++i) {
        if (frames[i]) views[i] = (KazumiLumaView){frames[i]->planes[c.plane] + c.offset,
            frames[i]->stride[c.plane], p->sample_bytes, shift, p->sample_big_endian, c.step};
    }
    uint8_t *texture = p->caption_storage + size;
    const int found = kazumi_detail_masks(views[0], views[1], a->w, a->h, p->caption_storage, texture,
                                         frames[2] ? &views[2] : NULL, frames[3] ? &views[3] : NULL);
    if (found >= 0) p->texture_map = texture;
    return found > 0;
}

static bool cut(const struct opts *o, const KazumiFrameDifference *d)
{
    return o->scene_threshold > 0 && d->changed_area >= .75 && d->mean_rgb_delta >= o->scene_threshold;
}

// Three-frame model times assume approximately uniform sampling. A seek,
// cut, format change or VFR discontinuity becomes a new context boundary.
static bool comparable_gap(double a, double b)
{
    return a > 0 && b > 0 && fabs(a - b) <= fmax(.0011, .08 * fmin(a, b));
}

static void prepare_context(struct priv *p)
{
    struct mp_image *next = p->lookahead;
    struct mp_image *b = p->rgb_pending;
    double gap = p->pending->pts - p->previous->pts;
    if (!allow_format(next) || !mp_image_params_static_equal(&p->pending->params, &next->params) ||
        !comparable_gap(gap, next->pts - p->pending->pts) || next->pts - p->pending->pts > p->opts->maximum_gap)
        return;
    if (!convert_rgb(p->convert_input, &p->rgb_lookahead, next, b->w, b->h)) {
        mp_image_unrefp(&p->rgb_lookahead);
        return;
    }
    struct mp_image *c = p->rgb_lookahead;
    KazumiFrameDifference d;
    p->use_lookahead = kazumi_frame_difference(b->planes[0], b->stride[0], c->planes[0], c->stride[0],
                                               b->w, b->h, &d) && !cut(p->opts, &d);
}

static void prepare_pair(struct priv *p)
{
    p->plan = (KazumiFramePlan){0};
    p->index = 0;
    p->hold_pair = false;
    p->same_shot = p->use_history = p->use_lookahead = false;
    p->captions = false;
    p->texture_map = NULL;
    p->pair_work_ns = 0;
    const int64_t start = mp_time_ns();
    if (p->over_budget || p->inference_failed || !allow_format(p->previous) || !allow_format(p->pending) ||
        !mp_image_params_static_equal(&p->previous->params, &p->pending->params))
        return;
    const struct opts *o = p->opts;
    KazumiFramePlan candidate = kazumi_frame_plan(
        p->previous->pts, p->pending->pts, o->multiplier, o->maximum_fps, o->maximum_gap,
        p->previous->nominal_fps);
    if (!candidate.count) return;
    const AVPixFmtDescriptor *fmt = av_pix_fmt_desc_get(imgfmt2pixfmt(p->previous->imgfmt));
    if (!native_samples(p, fmt)) return;

    int w = p->pending->w, h = p->pending->h;
    const int edge = MPMAX(w, h);
    if (edge > p->adaptive_edge) {
        w = MPMAX(1, w * p->adaptive_edge / edge);
        h = MPMAX(1, h * p->adaptive_edge / edge);
    }
    if ((!p->rgb_previous || p->rgb_previous->w != w || p->rgb_previous->h != h) &&
        !convert_rgb(p->convert_input, &p->rgb_previous, p->previous, w, h)) {
        mp_image_unrefp(&p->rgb_previous);
        return;
    }
    if ((!p->rgb_pending || p->rgb_pending->w != w || p->rgb_pending->h != h) &&
        !convert_rgb(p->convert_input, &p->rgb_pending, p->pending, w, h)) {
        mp_image_unrefp(&p->rgb_pending);
        return;
    }
    KazumiFrameDifference d;
    if (!kazumi_frame_difference(p->rgb_previous->planes[0], p->rgb_previous->stride[0],
                                  p->rgb_pending->planes[0], p->rgb_pending->stride[0],
                                  w, h, &d)) return;
    // Keep the output cadence through repeated cels and hard cuts without
    // mixing unrelated drawings or inventing motion in a held exposure. A
    // broad but modest luminance change is usually a fade and must remain
    // interpolable. Require widespread, high-amplitude RGB change before
    // treating a pair as a cut.
    const bool static_pair = o->static_threshold > 0 &&
        d.mean_rgb_delta <= o->static_threshold && d.changed_area <= 0.005;
    const bool scene_cut = cut(o, &d);
    p->same_shot = !scene_cut;
    if (static_pair || scene_cut) {
        p->hold_pair = true;
        p->plan = candidate;
        return;
    }
    const size_t count = (size_t)((w + 63) / 64 * 16) * ((h + 63) / 64 * 16);
    if (count > p->motion_capacity) {
        KrMotion *grid = talloc_realloc(p, p->motion, KrMotion, count);
        if (!grid) return;
        p->motion = grid;
        p->motion_capacity = count;
    }
    if (p->history && comparable_gap(p->preceding_gap, p->pending->pts - p->previous->pts)) {
        p->use_history = (p->rgb_history && p->rgb_history->w == w && p->rgb_history->h == h) ||
            convert_rgb(p->convert_input, &p->rgb_history, p->history, w, h);
    }
    p->awaiting_context = true;
    p->plan = candidate;
    p->pair_work_ns = mp_time_ns() - start;

}

static void restore_caption_tile(struct priv *p, struct mp_image *out, int x, int y)
{
    const int t = KAZUMI_DETAIL_TILE;
    const int columns = caption_grid(out->w), rows = caption_grid(out->h);
    const int col = x / t, row = y / t;
    const uint8_t *mask = p->caption_storage + row * columns + col;
    const bool left = col > 0 && !mask[-1], right = col + 1 < columns && !mask[1];
    const bool top = row > 0 && !mask[-columns], bottom = row + 1 < rows && !mask[columns];
    const int end_x = MPMIN(x + t, out->w), end_y = MPMIN(y + t, out->h);
    // Hold original caption pixels until the next real timestamp. The added
    // halo allows feathering at the outside edge, not over the glyph itself.
    for (int plane = 0; plane < out->num_planes; ++plane) {
        const int sx = out->fmt.xs[plane], sy = out->fmt.ys[plane];
        const int bytes = out->fmt.bpp[plane] / 8;
        const int component = p->sample_bytes;
        if (bytes < component || bytes % component || out->fmt.bpp[plane] % 8) continue;
        const int begin = x >> sx, end = (end_x + (1 << sx) - 1) >> sx;
        const int last = (end_y + (1 << sy) - 1) >> sy;
        for (int i = y >> sy; i < last; ++i) {
            const uint8_t *src = p->previous->planes[plane] + i * p->previous->stride[plane];
            uint8_t *dst = out->planes[plane] + i * out->stride[plane];
            if (!(left || right || top || bottom)) {
                memcpy(dst + begin * bytes, src + begin * bytes, (end - begin) * bytes);
                continue;
            }
            const int v = (i << sy) - y + 1;
            int vertical = t;
            if (top) vertical = v;
            if (bottom) vertical = MPMIN(vertical, t + 1 - v);
            for (int j = begin; j < end; ++j) {
                const int u = (j << sx) - x + 1;
                int weight = vertical;
                if (left) weight = MPMIN(weight, u);
                if (right) weight = MPMIN(weight, t + 1 - u);
                if (weight == t) {
                    memcpy(dst + j * bytes, src + j * bytes, bytes);
                    continue;
                }
                for (int c = j * bytes; c < (j + 1) * bytes; c += component) {
                    if (component == 1) {
                        dst[c] = (src[c] * weight + dst[c] * (t - weight) + t / 2) / t;
                    } else {
                        const int hi = c + !p->sample_big_endian;
                        const int lo = c + p->sample_big_endian;
                        const int a = (src[hi] << 8 | src[lo]) >> p->sample_padding;
                        const int b = (dst[hi] << 8 | dst[lo]) >> p->sample_padding;
                        const int value = ((a * weight + b * (t - weight) + t / 2) / t) << p->sample_padding;
                        dst[hi] = value >> 8;
                        dst[lo] = value & 255;
                    }
                }
            }
        }
    }
}

static void mix_native_row(struct priv *p, uint8_t *dst, const uint8_t *a,
                           const uint8_t *b, int length, unsigned weight)
{
    if (memcmp(a, b, length) == 0) {
        memcpy(dst, a, length);
    } else if (p->sample_bytes == 1) {
        for (int k = 0; k < length; ++k)
            dst[k] = (a[k] * (256 - weight) + b[k] * weight + 128) >> 8;
    } else {
        const int lo = p->sample_big_endian, hi = 1 - lo, shift = p->sample_padding;
        for (int k = 0; k < length; k += 2) {
            unsigned av = (a[k + hi] << 8 | a[k + lo]) >> shift;
            unsigned bv = (b[k + hi] << 8 | b[k + lo]) >> shift;
            unsigned value = ((av * (256 - weight) + bv * weight + 128) >> 8) << shift;
            dst[k + hi] = value >> 8;
            dst[k + lo] = value & 255;
        }
    }
}

static void compose_native(struct priv *p, struct mp_image *out, float position)
{
    const unsigned weight = lroundf(position * 256);
    const int t = KAZUMI_DETAIL_TILE, columns = caption_grid(out->w);
    for (int y = 0; y < out->h; y += t) {
        for (int x = 0; x < out->w; x += t) {
            const int end_x = MPMIN(x + t, out->w), end_y = MPMIN(y + t, out->h);
            const int tile = y / t * columns + x / t;
            const bool caption = p->captions && p->caption_storage[tile];
            const int texture = p->texture_map ? p->texture_map[tile] : KAZUMI_TEXTURE_NONE;
            if (texture != KAZUMI_TEXTURE_NONE) {
                const bool hold = texture == KAZUMI_TEXTURE_OPPOSED;
                for (int plane = 0; plane < out->num_planes; ++plane) {
                    const int sx = out->fmt.xs[plane], sy = out->fmt.ys[plane];
                    const int bytes = out->fmt.bpp[plane] / 8;
                    const int begin = (x >> sx) * bytes;
                    const int end = mp_chroma_div_up(end_x, sx) * bytes;
                    const int last = mp_chroma_div_up(end_y, sy);
                    for (int row = y >> sy; row < last; ++row) {
                        uint8_t *dst = out->planes[plane] + row * out->stride[plane] + begin;
                        const uint8_t *a = p->previous->planes[plane] + row * p->previous->stride[plane] + begin;
                        const uint8_t *b = p->pending->planes[plane] + row * p->pending->stride[plane] + begin;
                        if (hold) memcpy(dst, a, end - begin);
                        else mix_native_row(p, dst, a, b, end - begin, weight);
                    }
                }
            }
            // Apply after initializing every sample, including the feathered halo.
            if (caption) restore_caption_tile(p, out, x, y);
        }
    }
}

static struct mp_image *stamp_intermediate(struct priv *p, struct mp_image *image)
{
    if (image) {
        image->pts = p->plan.pts[p->index];
        image->dts = MP_NOPTS_VALUE;
        image->pkt_duration = (p->pending->pts - p->previous->pts) / (1 + p->plan.count);
    }
    return image;
}

static int drba_frame(struct mp_filter *f, float t, struct mp_image *out)
{
    struct priv *p = f->priv;
    const int64_t start = mp_time_ns();
    // The nearer drawing is the center. For the exact midpoint prefer the
    // center with a real adjacent drawing. Replicate only at a boundary.
    const bool earlier = t < .5f || (t == .5f && (p->use_history || !p->use_lookahead));
    struct mp_image *a = p->rgb_previous, *b = p->rgb_pending;
    struct mp_image *images[3] = {
        earlier ? (p->use_history ? p->rgb_history : a) : a,
        earlier ? a : b,
        earlier ? b : (p->use_lookahead ? p->rgb_lookahead : b),
    };
    KrRgbView views[3];
    for (int i = 0; i < 3; ++i) views[i] = (KrRgbView){images[i]->planes[0], images[i]->stride[0]};
    int status = p->api.predict_motion(p->context, views, a->w, a->h, earlier ? 1.f+t : t,
                                       p->motion, (a->w+63)/64*16);
    if (status != KR_OK) return status;
    const int64_t inferred = mp_time_ns();
    const struct mp_image *center = earlier ? p->previous : p->pending;
    const struct mp_image *partner = earlier ? p->pending : p->previous;
    for (int i = 0; i < out->num_planes; ++i) {
        const KrPlane plane = {center->planes[i], partner->planes[i], out->planes[i],
            center->stride[i], partner->stride[i], out->stride[i], mp_image_plane_w(out,i), mp_image_plane_h(out,i),
            out->fmt.xs[i], out->fmt.ys[i], out->fmt.bpp[i]/8, p->sample_bytes, p->sample_padding, p->sample_big_endian};
        status = p->api.warp_plane(p->context, p->motion, a->w, a->h, out->w, out->h, &plane, p->opts->threads);
        if (status != KR_OK) return status;
    }
    const int64_t warped = mp_time_ns();
    compose_native(p, out, t);
    MP_TRACE(f, "DRBA work (ms): prepare %.2f, model %.2f, warp %.2f, detail %.2f\n",
             p->pair_work_ns / 1e6, (inferred-start) / 1e6, (warped-inferred) / 1e6,
             (mp_time_ns()-warped) / 1e6);
    return KR_OK;
}

static struct mp_image *synthesize(struct mp_filter *f)
{
    struct priv *p = f->priv;
    struct mp_image *a = p->rgb_previous;
    if (p->hold_pair)
        return stamp_intermediate(p, mp_image_new_ref(p->previous));
    const int64_t start = mp_time_ns();
    const float position = p->plan.position[p->index];
    struct mp_image *out = mp_image_alloc(p->previous->imgfmt, p->previous->w, p->previous->h);
    if (!out) return NULL;
    mp_image_copy_attributes(out, p->previous);
    const int result = drba_frame(f, position, out);
    if (result != KR_OK) {
        MP_WARN(f, "KAZUMI_DRBA_INFERENCE_FAILED: %d; passing original frames\n", result);
        p->inference_failed = true;
        talloc_free(out);
        return NULL;
    }
    // Charge actual work rather than wall time between filter calls: the
    // display can consume a generated frame before asking for the next one.
    // Counting that wait as inference cost caused spurious budget fallbacks.
    p->pair_work_ns += mp_time_ns() - start;
    if (p->opts->realtime_guard && p->index + 1 == p->plan.count) {
        const double cost = p->pair_work_ns / 1e9;
        const double gap = p->pending->pts - p->previous->pts;
        const int active = MPMIN(p->adaptive_edge, MPMAX(a->w, a->h));
        // A modest final step can keep low-resolution streams real-time;
        // do not shrink larger sources below the existing 320 px floor.
        const int floor = MPMAX(p->pending->w, p->pending->h) <= 640 ? 256 : 320;
        const int next = kazumi_realtime_edge(&p->budget, cost, gap, active, floor);
        if (next == 0) {
            // Stay at the source cadence until a seek or a profile change.
            p->over_budget = true;
            MP_WARN(f, "KAZUMI_DRBA_OVER_BUDGET: keeping source cadence (%.1f ms work for %.1f ms gap at %d px)\n",
                    cost * 1000, gap * 1000, active);
        } else if (next < active) {
            p->adaptive_edge = next;
            MP_VERBOSE(f, "DRBA realtime budget: limiting inference to %d px (%.1f/%.1f ms)\n",
                       next, cost * 1000, gap * 1000);
        }
    }
    // Keep format/FPS hints consistent even if this intermediate is held.
    return stamp_intermediate(p, out);
}

static void process(struct mp_filter *f)
{
    struct priv *p = f->priv;
    if (!mp_pin_in_needs_data(f->ppins[1])) return;
    if (p->pending) {
        if (p->awaiting_context) {
            struct mp_frame next = mp_pin_out_read(f->ppins[0]);
            if (next.type == MP_FRAME_NONE) return;
            p->awaiting_context = false;
            const int64_t start = mp_time_ns();
            if (next.type == MP_FRAME_VIDEO) {
                p->lookahead = next.data;
                prepare_context(p);
            } else {
                mp_pin_out_unread(f->ppins[0], next);
            }
            p->captions = find_captions(p, av_pix_fmt_desc_get(imgfmt2pixfmt(p->previous->imgfmt)));
            p->pair_work_ns += mp_time_ns() - start;
        }
        while (p->index < p->plan.count) {
            struct mp_image *derived = synthesize(f);
            ++p->index;
            if (!derived) p->index = p->plan.count;
            if (derived) {
                mp_pin_in_write(f->ppins[1], MAKE_FRAME(MP_FRAME_VIDEO, derived));
                return;
            }
        }
        struct mp_image *image = p->pending;
        p->pending = NULL;
        mp_image_unrefp(&p->history);
        mp_image_unrefp(&p->rgb_history);
        if (p->same_shot && !p->over_budget && !p->inference_failed) {
            p->history = p->previous;
            p->previous = NULL;
            p->rgb_history = p->rgb_previous;
            p->rgb_previous = NULL;
            p->preceding_gap = image->pts - p->history->pts;
        }
        mp_image_unrefp(&p->previous);
        p->previous = mp_image_new_ref(image);
        mp_image_unrefp(&p->rgb_previous);
        p->rgb_previous = p->rgb_pending;
        p->rgb_pending = NULL;
        mp_pin_in_write(f->ppins[1], MAKE_FRAME(MP_FRAME_VIDEO, image));
        return;
    }

    struct mp_frame frame;
    if (p->lookahead) {
        frame = MAKE_FRAME(MP_FRAME_VIDEO, p->lookahead);
        p->lookahead = NULL;
        p->rgb_pending = p->rgb_lookahead;
        p->rgb_lookahead = NULL;
    } else {
        frame = mp_pin_out_read(f->ppins[0]);
    }
    if (frame.type == MP_FRAME_NONE) return;
    if (frame.type != MP_FRAME_VIDEO) {
        reset(f);
        mp_pin_in_write(f->ppins[1], frame);
        return;
    }
    if (!p->previous) {
        p->previous = mp_image_new_ref(frame.data);
        mp_pin_in_write(f->ppins[1], frame);
        return;
    }
    p->pending = frame.data;
    prepare_pair(p);
    mp_filter_internal_mark_progress(f);
}

static const struct mp_filter_info filter = {
    .name = "kazumi-drba", .priv_size = sizeof(struct priv),
    .process = process, .reset = reset, .destroy = destroy,
};

static struct mp_filter *create(struct mp_filter *parent, void *options)
{
    struct mp_filter *f = mp_filter_create(parent, &filter);
    if (!f) {
        talloc_free(options);
        return NULL;
    }
    struct priv *p = f->priv;
    const struct opts *o = p->opts = talloc_steal(p, options);
    if (!o->model || !o->model[0] || !open_runtime(&p->api)) {
        MP_ERR(f, "KAZUMI_DRBA_RUNTIME_MISSING: no model or compatible inference library\n");
        talloc_free(f);
        return NULL;
    }
    const KrOptions config = {
        .abi = KR_ABI_VERSION, .model_directory = o->model, .device_id = o->device,
        .cpu = o->cpu, .cpu_threads = o->threads,
    };
    const int status = p->api.create(&config, &p->context);
    if (status != KR_OK) {
        MP_ERR(f, "KAZUMI_DRBA_INIT_FAILED: %d\n", status);
        talloc_free(f);
        return NULL;
    }
    p->adaptive_edge = o->realtime_guard && o->starting_edge > 0
        ? MPMIN(o->maximum_edge, o->starting_edge) : o->maximum_edge;
    p->convert_input = mp_sws_alloc(p);
    p->convert_input->flags = mp_sws_fast_flags;
    mp_filter_add_pin(f, MP_PIN_IN, "in");
    mp_filter_add_pin(f, MP_PIN_OUT, "out");
    return f;
}

#define OPT_BASE_STRUCT struct opts
static const struct m_option filter_options[] = {
    {"model", OPT_STRING(model)},
    {"device", OPT_STRING(device)},
    {"factor", OPT_INT(multiplier), M_RANGE(2, 4)},
    {"max-edge", OPT_INT(maximum_edge), M_RANGE(320, 4096)},
    {"start-edge", OPT_INT(starting_edge), M_RANGE(0, 4096)},
    {"max-fps", OPT_DOUBLE(maximum_fps), M_RANGE(24, 144)},
    {"max-gap", OPT_DOUBLE(maximum_gap), M_RANGE(0.05, 0.5)},
    {"scene-threshold", OPT_DOUBLE(scene_threshold), M_RANGE(0, 1)},
    {"static-threshold", OPT_DOUBLE(static_threshold), M_RANGE(0, 0.1)},
    {"cpu", OPT_BOOL(cpu)},
    {"threads", OPT_INT(threads), M_RANGE(1, 16)},
    {"realtime-guard", OPT_BOOL(realtime_guard)},
    {0}
};

static const struct opts defaults = {
    .multiplier = 2, .maximum_edge = 1280, .maximum_fps = 60, .maximum_gap = 0.25,
    .scene_threshold = 0.23, .static_threshold = 0.002, .threads = 4,
    .realtime_guard = true,
};

const struct mp_user_filter_entry vf_kazumi_rife = {
    .desc = {
        .name = "kazumi-drba",
        .description = "DRBA_Distill lite Vulkan/CPU video frame interpolation",
        .priv_size = sizeof(struct opts), .priv_defaults = &defaults,
        .options = filter_options,
    },
    .create = create,
};
