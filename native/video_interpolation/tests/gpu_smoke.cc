/* Copyright 2026 Kazumi contributors. SPDX-License-Identifier: MIT */
#include "rife_bridge.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdio>
#include <memory>
#include <vector>

static bool check_frames(KrContext *context, int w, int h)
{
    std::array<std::vector<uint8_t>, 3> rgb;
    KrRgbView views[3];
    for (int f = 0; f < 3; ++f) {
        rgb[f].resize(w * h * 3);
        for (int y = 0; y < h; ++y) {
            for (int x = 0; x < w; ++x) {
                const int sx = x + 4 * f;
                for (int c = 0; c < 3; ++c) {
                    rgb[f][(y * w + x) * 3 + c] = sx < w / 2
                        ? 32 + ((sx / 3 + y / 4 + c * 7) % 128)
                        : 160 + ((y / 4 + c * 7) % 64);
                }
            }
        }
        views[f] = {rgb[f].data(), w * 3};
    }

    constexpr int width = 1280, height = 720;
    std::vector<uint8_t> center(width * height), partner(width * height), out(width * height);
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            center[y * width + x] = 32 + (x % 53) + (y % 101);
            partner[y * width + x] = 32 + ((x + 12) % 53) + (y % 101);
        }
    }
    const KrPlane plane = {center.data(), partner.data(), out.data(),
        width, width, width, width, height, 0, 0, 1, 1, 0, 0};
    const int gw = (w + 63) / 64 * 16, gh = (h + 63) / 64 * 16;
    std::vector<KrMotion> motion(gw * gh);
    std::array<std::vector<KrMotion>, 2> reference;
    for (int i = 0; i < 8; ++i) {
        const int side = i % 2;
        int rc = kr_predict_motion(context, views, w, h, side ? .5f : 1.5f,
                                   motion.data(), gw);
        if (rc != KR_OK) {
            std::fprintf(stderr, "%dx%d prediction %d: status %d\n", w, h, i, rc);
            return false;
        }
        const auto &expected = reference[side];
        if (!expected.empty() && !std::equal(motion.begin(), motion.end(), expected.begin(),
            [](const KrMotion &a, const KrMotion &b) {
                constexpr float tolerance = .02f;
                return std::abs(a.cx - b.cx) < tolerance && std::abs(a.cy - b.cy) < tolerance &&
                       std::abs(a.px - b.px) < tolerance && std::abs(a.py - b.py) < tolerance &&
                       std::abs(a.logit - b.logit) < tolerance;
            })) {
            std::fprintf(stderr, "%dx%d prediction %d changed for identical inputs\n", w, h, i);
            return false;
        }
        if (expected.empty()) reference[side] = motion;
        std::fill(out.begin(), out.end(), 0);
        rc = kr_warp_plane(context, motion.data(), w, h, width, height, &plane, 4);
        // Interpolation of these inputs cannot go outside this range. A
        // partially dispatched shader leaves unwritten pixels in the plane.
        if (rc != KR_OK || !std::all_of(out.begin(), out.end(),
            [](uint8_t sample) { return sample >= 31 && sample <= 185; })) {
            std::fprintf(stderr, "%dx%d warp %d: incomplete/invalid output (status %d)\n", w, h, i, rc);
            return false;
        }
    }
    std::printf("%dx%d: eight repeated Vulkan predictions and whole-plane warps passed\n", w, h);
    return true;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        std::fprintf(stderr, "Usage: kazumi_drba_gpu_smoke <model directory>\n");
        return 2;
    }
    const KrOptions config = {KR_ABI_VERSION, argv[1], nullptr, 0, 4};
    KrContext *raw = nullptr;
    const int rc = kr_create(&config, &raw);
    std::unique_ptr<KrContext, decltype(&kr_destroy)> context(raw, kr_destroy);
    if (rc != KR_OK || !context) {
        std::fprintf(stderr, "Vulkan DRBA initialization failed (status %d)\n", rc);
        return 1;
    }
    return check_frames(raw, 480, 270) && check_frames(raw, 640, 360) &&
           check_frames(raw, 960, 540) ? 0 : 1;
}
