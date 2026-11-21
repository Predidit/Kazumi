/* Copyright 2026 Kazumi contributors. SPDX-License-Identifier: MIT */
#ifndef KAZUMI_DISTILDRBA_H
#define KAZUMI_DISTILDRBA_H
#include "rife_bridge.h"
#include <net.h>
#include <filesystem>
#include <memory>
#include <pipeline.h>

class DistilDrba {
public:
    DistilDrba() = default;
    ~DistilDrba();
    bool warp_gpu(const KrMotion *grid, int model_w, int model_h, int image_w, int image_h, const KrPlane &plane);
    bool load(const std::filesystem::path &path, int gpu, int threads);
    int predict(const KrRgbView frames[3], int w, int h, float time,
                KrMotion *output, ptrdiff_t stride) const;
private:
    ncnn::Net net;
    std::unique_ptr<ncnn::Pipeline> warp_pipeline;
    const ncnn::VulkanDevice *device = nullptr;
    ncnn::Option transfer;
    bool disable_gpu_warp = false;
};
#endif
