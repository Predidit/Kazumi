/* Copyright 2026 Kazumi contributors. SPDX-License-Identifier: MIT */
#include "rife_bridge.h"
#include <algorithm>
#include <cmath>

namespace {
struct Axis { int a, b; float fraction; };
Axis axis(float x, int size)
{
    x = std::clamp(x, 0.f, static_cast<float>(size - 1));
    int i = static_cast<int>(x);
    return {i, std::min(i + 1, size - 1), x - i};
}
float lerp(float a, float b, float t) { return a + t * (b - a); }
float bilerp(float a, float b, float c, float d, float x, float y)
{
    return lerp(lerp(a, b, x), lerp(c, d, x), y);
}
KrMotion interpolate(const KrMotion &a, const KrMotion &b, const KrMotion &c, const KrMotion &d,
                     float x, float y)
{
    return {bilerp(a.cx,b.cx,c.cx,d.cx,x,y), bilerp(a.cy,b.cy,c.cy,d.cy,x,y),
            bilerp(a.px,b.px,c.px,d.px,x,y), bilerp(a.py,b.py,c.py,d.py,x,y),
            bilerp(a.logit,b.logit,c.logit,d.logit,x,y)};
}
template<bool wide>
int read(const uint8_t *p, int x, const KrPlane &plane)
{
    p += x * plane.pixel_bytes;
    if (!wide) return *p;
    return ((p[!plane.big_endian] << 8) | p[!!plane.big_endian]) >> plane.padding;
}
template<bool wide>
float sample(const uint8_t *top, const uint8_t *bottom, Axis x, float fy, const KrPlane &plane)
{
    return bilerp(read<wide>(top,x.a,plane), read<wide>(top,x.b,plane),
                  read<wide>(bottom,x.a,plane), read<wide>(bottom,x.b,plane), x.fraction,fy);
}

template<bool wide>
void render(const KrMotion *grid, int gw, int gh, int model_w, int model_h,
            int image_w, int image_h, const KrPlane &p, int threads)
{
    const float scale_x = static_cast<float>(image_w) / (model_w * (1 << p.sub_x));
    const float scale_y = static_cast<float>(image_h) / (model_h * (1 << p.sub_y));
    const float gx = .25f / scale_x, gy = .25f / scale_y;
    #pragma omp parallel for num_threads(threads) if(p.width * p.height >= 65536)
    for (int y = 0; y < p.height; ++y) {
        const Axis v = axis((y + .5f) * gy - .5f, gh);
        const KrMotion *top = grid + v.a * gw, *bottom = grid + v.b * gw;
        uint8_t *dst = p.dst + y * p.dst_stride;
        for (int x = 0; x < p.width; ++x) {
            const Axis u = axis((x + .5f) * gx - .5f, gw);
            const KrMotion m = interpolate(top[u.a], top[u.b], bottom[u.a], bottom[u.b], u.fraction, v.fraction);
            // The reference interpolates the logit spatially before sigmoid.
            const float mask = 1.f / (1.f + std::exp(-m.logit));
            const Axis ax = axis(x + m.cx * scale_x, p.width), ay = axis(y + m.cy * scale_y, p.height);
            const Axis bx = axis(x + m.px * scale_x, p.width), by = axis(y + m.py * scale_y, p.height);
            for (int k = 0; k < p.pixel_bytes; k += p.sample_bytes) {
                const float a = sample<wide>(p.center + ay.a * p.center_stride + k,
                    p.center + ay.b * p.center_stride + k, ax, ay.fraction, p);
                const float b = sample<wide>(p.partner + by.a * p.partner_stride + k,
                    p.partner + by.b * p.partner_stride + k, bx, by.fraction, p);
                const int value = static_cast<int>(lerp(b, a, mask) + .5f);
                uint8_t *d = dst + x * p.pixel_bytes + k;
                if (wide) {
                    const auto bits = static_cast<unsigned>(value) << p.padding;
                    d[!!p.big_endian] = bits & 255;
                    d[!p.big_endian] = bits >> 8;
                } else *d = static_cast<uint8_t>(value);
            }
        }
    }
}
}

bool drba_warp_gpu(KrContext *, const KrMotion *, int, int, int, int, const KrPlane &);

int kr_warp_plane(KrContext *context, const KrMotion *grid, int mw, int mh, int w, int h, const KrPlane *p, int threads)
{
    if (!grid || !p || !p->dst || !p->center || !p->partner || mw <= 0 || mh <= 0 ||
        w <= 0 || h <= 0 || w > 4096 || h > 4096 || mw > w || mh > h ||
        p->sub_x < 0 || p->sub_x > 2 || p->sub_y < 0 || p->sub_y > 2 ||
        p->width != (w + (1 << p->sub_x) - 1) >> p->sub_x ||
        p->height != (h + (1 << p->sub_y) - 1) >> p->sub_y ||
        (p->sample_bytes != 1 && p->sample_bytes != 2) || p->pixel_bytes < p->sample_bytes ||
        p->pixel_bytes > 8 || p->pixel_bytes % p->sample_bytes || p->padding < 0 || p->padding > 8 ||
        threads < 1 || threads > 16) return KR_INVALID_ARGUMENT;
    for (const ptrdiff_t stride : {p->dst_stride, p->center_stride, p->partner_stride}) {
        const ptrdiff_t row = p->width * p->pixel_bytes;
        if ((stride > -row && stride < row) || stride > PTRDIFF_MAX / p->height ||
            stride < -(PTRDIFF_MAX / p->height)) return KR_INVALID_ARGUMENT;
    }
    if (p->width * p->height >= 65536 && drba_warp_gpu(context,grid,mw,mh,w,h,*p)) return KR_OK;
    const int gw = (mw+63)/64*16, gh = (mh+63)/64*16;
    if (p->sample_bytes == 2) render<true>(grid, gw, gh, mw, mh, w, h, *p, threads);
    else render<false>(grid, gw, gh, mw, mh, w, h, *p, threads);
    return KR_OK;
}
