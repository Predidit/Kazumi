/* Copyright 2026 Kazumi contributors. SPDX-License-Identifier: MIT */
#include "distildrba.h"
#include "rife_ops.h"
#include "drba_warp.comp.hex.h"
#include <command.h>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>

namespace {
DEFINE_LAYER_CREATOR(Warp)

FILE *open_binary(const std::filesystem::path &path)
{
#ifdef _WIN32
    return _wfopen(path.c_str(), L"rb");
#else
    return std::fopen(path.c_str(), "rb");
#endif
}

// Match PyTorch bilinear interpolate(align_corners=False, antialias=False)
// at an even integer downscale. Replicate-pad to the model stride at the edge.
ncnn::Mat pyramid(const KrRgbView frames[3], int w, int h, int pw, int ph, int scale)
{
    ncnn::Mat out(pw / scale, ph / scale, 9);
    if (out.empty()) return out;
    for (int f = 0; f < 3; ++f) {
        for (int y = 0; y < out.h; ++y) {
            const int sy = y * scale + scale / 2 - 1;
            const uint8_t *a = frames[f].data + std::min(sy, h - 1) * frames[f].stride;
            const uint8_t *b = frames[f].data + std::min(sy + 1, h - 1) * frames[f].stride;
            float *dst[3];
            for (int c = 0; c < 3; ++c) dst[c] = out.channel(3 * f + c).row(y);
            for (int x = 0; x < out.w; ++x) {
                const int sx = x * scale + scale / 2 - 1;
                const int l = std::min(sx, w - 1) * 3, r = std::min(sx + 1, w - 1) * 3;
                for (int c = 0; c < 3; ++c)
                    dst[c][x] = (a[l+c] + b[r+c] + a[r+c] + b[l+c]) * (1.f / 1020.f);
            }
        }
    }
    return out;
}
}

DistilDrba::~DistilDrba()
{
    warp_pipeline.reset();
    if (device) {
        if (transfer.blob_vkallocator) device->reclaim_blob_allocator(transfer.blob_vkallocator);
        if (transfer.staging_vkallocator) device->reclaim_staging_allocator(transfer.staging_vkallocator);
    }
}

bool DistilDrba::load(const std::filesystem::path &path, int gpu, int threads)
{
    net.opt.num_threads = threads;
    net.opt.use_vulkan_compute = gpu >= 0;
    net.opt.use_fp16_arithmetic = false;
    if (gpu >= 0) {
        net.set_vulkan_device(gpu);
        device = ncnn::get_gpu_device(gpu);
        transfer.blob_vkallocator = device->acquire_blob_allocator();
        transfer.workspace_vkallocator = transfer.blob_vkallocator;
        transfer.staging_vkallocator = device->acquire_staging_allocator();
        transfer.use_fp16_packed = transfer.use_fp16_storage = transfer.use_fp16_arithmetic = false;
        std::vector<uint32_t> spirv;
        warp_pipeline = std::make_unique<ncnn::Pipeline>(device);
        warp_pipeline->set_optimal_local_size_xyz(16, 8, 1);
        if (!transfer.blob_vkallocator || !transfer.staging_vkallocator ||
            ncnn::compile_spirv_module(drba_warp_comp_data, sizeof(drba_warp_comp_data), transfer, spirv) ||
            warp_pipeline->create(spirv.data(), spirv.size() * sizeof(uint32_t), {}) ||
            warp_pipeline->shader_info().push_constant_count != 11 ||
            warp_pipeline->shader_info().binding_count != 4)
            warp_pipeline.reset(); // Software native-plane renderer implements the same equations.
    }
    net.register_custom_layer("rife.Warp", Warp_layer_creator);
    FILE *fp = open_binary(path / "flownet.param");
    if (!fp) return false;
    const int params = net.load_param(fp);
    std::fclose(fp);
    if (params != 0) return false;
    const auto &names = net.input_names();
    const char *expected[] = {"rgb16", "rgb8", "rgb4", "time16", "after"};
    if (names.size() != 5 || net.output_names().size() != 1 ||
        std::strcmp(net.output_names()[0], "motion")) return false;
    for (int i = 0; i < 5; ++i) if (std::strcmp(names[i], expected[i])) return false;
    fp = open_binary(path / "flownet.bin");
    if (!fp) return false;
    const int weights = net.load_model(fp);
    std::fclose(fp);
    return weights == 0;
}

int DistilDrba::predict(const KrRgbView frames[3], int w, int h, float time,
                        KrMotion *output, ptrdiff_t stride) const
{
    const int pw = (w + 63) / 64 * 64, ph = (h + 63) / 64 * 64;
    ncnn::Extractor ex = net.create_extractor();
    for (int scale : {16, 8, 4}) {
        auto img = pyramid(frames, w, h, pw, ph, scale);
        if (img.empty() || ex.input(scale == 16 ? "rgb16" : scale == 8 ? "rgb8" : "rgb4", img))
            return KR_INFERENCE_ERROR;
    }
    ncnn::Mat t(pw / 16, ph / 16, 1), side(1, 1, 1);
    if (t.empty() || side.empty()) return KR_INFERENCE_ERROR;
    t.fill(time);
    side.fill(time > 1.f ? 1.f : 0.f);
    ncnn::Mat result;
    if (ex.input("time16", t) || ex.input("after", side) || ex.extract("motion", result) ||
        result.w != pw / 4 || result.h != ph / 4 || result.c != 5 ||
        result.elempack != 1 || result.elemsize != sizeof(float)) return KR_INFERENCE_ERROR;
    // Both upstream bilinear expansions (flow units x4 and sigmoid(mask))
    // happen in the full-size compositor. Keep valid padded grid taps here.
    for (int y = 0; y < result.h; ++y) {
        const float *src[5];
        for (int c = 0; c < 5; ++c) src[c] = result.channel(c).row(y);
        for (int x = 0; x < result.w; ++x) {
            KrMotion v = {src[0][x]*4, src[1][x]*4, src[2][x]*4, src[3][x]*4, src[4][x]};
            if (!std::isfinite(v.cx) || !std::isfinite(v.cy) || !std::isfinite(v.px) ||
                !std::isfinite(v.py) || !std::isfinite(v.logit)) return KR_INFERENCE_ERROR;
            output[y * stride + x] = v;
        }
    }
    return KR_OK;
}

bool DistilDrba::warp_gpu(const KrMotion *grid, int mw, int mh, int w, int h, const KrPlane &p)
{
    if (!warp_pipeline || disable_gpu_warp) return false;
    const int gw = (mw+63)/64*16, gh = (mh+63)/64*16;
    const int row = p.width * p.pixel_bytes, pitch = (row + 3) & ~3;
    auto plane_words = [&](const uint8_t *src, ptrdiff_t stride) {
        ncnn::Mat data(pitch / 4, p.height, static_cast<size_t>(4));
        if (!data.empty()) {
            for (int y = 0; y < p.height; ++y) {
                uint8_t *d = reinterpret_cast<uint8_t *>(data.row(y));
                std::memcpy(d, src + y * stride, row);
                std::memset(d + row, 0, pitch - row);
            }
        }
        return data;
    };
    static_assert(sizeof(KrMotion) == 5*sizeof(float));
    ncnn::Mat field(gw*gh*5, const_cast<KrMotion *>(grid), sizeof(float));
    ncnn::Mat a = plane_words(p.center, p.center_stride), b = plane_words(p.partner, p.partner_stride);
    if (a.empty() || b.empty()) return false;
    ncnn::VkCompute cmd(device);
    std::vector<ncnn::VkMat> io(4);
    cmd.record_clone(field, io[0], transfer);
    cmd.record_clone(a, io[1], transfer);
    cmd.record_clone(b, io[2], transfer);
    io[3].create(pitch/4, p.height, static_cast<size_t>(4), 1, transfer.blob_vkallocator);
    for (auto &v : io) if (v.empty()) return false;
    std::vector<ncnn::vk_constant_type> params(11);
    const int sizes[] = {p.width, p.height, gw, gh, pitch, p.pixel_bytes, p.sample_bytes, p.padding, p.big_endian};
    for (int i = 0; i < 9; ++i) params[i].i = sizes[i];
    params[9].f = static_cast<float>(w) / (mw * (1 << p.sub_x));
    params[10].f = static_cast<float>(h) / (mh * (1 << p.sub_y));
    cmd.record_pipeline(warp_pipeline.get(), io, params, io[3]);
    ncnn::Mat result;
    cmd.record_clone(io[3], result, transfer);
    if (cmd.submit_and_wait() || result.empty()) {
        disable_gpu_warp = true;
        return false;
    }
    for (int y = 0; y < p.height; ++y)
        std::memcpy(p.dst + y*p.dst_stride, result.row(y), row);
    return true;
}
