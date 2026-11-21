/* Copyright 2026 Kazumi contributors. SPDX-License-Identifier: MIT */
#include "rife_bridge.h"
#include "distildrba.h"
#include <gpu.h>

#include <cmath>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <memory>
#include <mutex>
#include <string>

struct KrContext {
    std::unique_ptr<DistilDrba> drba;
    bool gpu = false;
};

namespace {
constexpr int kMaximumDimension = 4096;
constexpr int kMaximumPixels = 3840 * 2160;
constexpr int kInvalidDevice = -2;

std::string uuid_string(const uint8_t *bytes)
{
    constexpr char hex[] = "0123456789abcdef";
    std::string id;
    for (int i = 0; i < VK_UUID_SIZE; ++i) {
        if (i == 4 || i == 6 || i == 8 || i == 10) id += '-';
        id += hex[bytes[i] >> 4];
        id += hex[bytes[i] & 15];
    }
    return id;
}

std::mutex lifecycle;
int gpu_users = 0;

int select_gpu(const char *id)
{
    const int count = ncnn::get_gpu_count();
    const int preferred = ncnn::get_default_gpu_index();
    const bool automatic = !id || !id[0];
    if (!automatic && !ncnn::vkGetPhysicalDeviceProperties2KHR) return kInvalidDevice;

    int first_hardware = kInvalidDevice;
    for (int i = 0; i < count; ++i) {
        const auto &gpu = ncnn::get_gpu_info(i);
        // Automatic GPU mode and the device picker must agree. Software Vulkan
        // drivers can be enumerated alongside hardware on both mobile and PC.
        if (gpu.physicalDeviceProperties().deviceType == VK_PHYSICAL_DEVICE_TYPE_CPU) continue;
        if (automatic) {
            if (i == preferred) return i;
            if (first_hardware == kInvalidDevice) first_hardware = i;
            continue;
        }
        VkPhysicalDeviceIDProperties identity{};
        identity.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ID_PROPERTIES;
        VkPhysicalDeviceProperties2 props{};
        props.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
        props.pNext = &identity;
        ncnn::vkGetPhysicalDeviceProperties2KHR(gpu.physicalDevice(), &props);
        if (uuid_string(identity.deviceUUID) == id) return i;
#if defined(_WIN32)
        if (identity.deviceLUIDValid) {
            // DXGILUID is { LowPart, HighPart } in native little-endian order.
            uint32_t low{}, high{};
            std::memcpy(&low, identity.deviceLUID, sizeof(low));
            std::memcpy(&high, identity.deviceLUID + sizeof(low), sizeof(high));
            char luid[18];
            std::snprintf(luid, sizeof(luid), "%08x:%08x", high, low);
            if (std::strcmp(luid, id) == 0) return i;
        }
#endif
    }
    return first_hardware;
}

}

uint32_t kr_abi(void) { return KR_ABI_VERSION; }

int kr_create(const KrOptions *options, KrContext **result)
{
    if (!result) return KR_INVALID_ARGUMENT;
    *result = nullptr;
    if (!options || options->abi != KR_ABI_VERSION || !options->model_directory ||
        options->cpu_threads < 1 || options->cpu_threads > 16)
        return KR_INVALID_ARGUMENT;
    try {
        const auto path = std::filesystem::u8path(options->model_directory);
        std::lock_guard<std::mutex> guard(lifecycle);
        const bool gpu = !options->cpu;
        struct TryGPU {
            bool newly_initialized = false, keep = false;
            ~TryGPU() {
                if (newly_initialized && !keep) ncnn::destroy_gpu_instance();
            }
        } lifecycle_guard;
        if (gpu && gpu_users == 0) {
            if (ncnn::create_gpu_instance() != 0) return KR_NO_GPU;
            lifecycle_guard.newly_initialized = true;
        }
        const int device = gpu ? select_gpu(options->device_id) : -1;
        if (gpu && device < 0) return KR_NO_GPU;

        auto context = std::make_unique<KrContext>();
        context->gpu = gpu;
        context->drba = std::make_unique<DistilDrba>();
        if (!context->drba->load(path, device, options->cpu_threads)) return KR_MODEL_ERROR;
        if (gpu) ++gpu_users;
        lifecycle_guard.keep = true;
        *result = context.release();
        return KR_OK;
    } catch (...) {
        return KR_MODEL_ERROR;
    }
}

void kr_destroy(KrContext *context)
{
    if (!context) return;
    std::lock_guard<std::mutex> guard(lifecycle);
    const bool gpu = context->gpu;
    delete context;
    if (gpu && --gpu_users == 0) ncnn::destroy_gpu_instance();
}

int kr_predict_motion(KrContext *context, const KrRgbView frames[3], int w, int h,
                      float time, KrMotion *output, ptrdiff_t stride)
{
    if (!context || !context->drba || !frames || !output || w <= 0 || h <= 0 ||
        w > kMaximumDimension || h > kMaximumDimension || w * h > kMaximumPixels ||
        !std::isfinite(time) || time < .5f || time > 1.5f || time == 1.f ||
        stride < (w + 63) / 64 * 16 || stride > PTRDIFF_MAX / sizeof(KrMotion) / ((h+63)/64*16))
        return KR_INVALID_ARGUMENT;
    for (int i = 0; i < 3; ++i)
        if (!frames[i].data || frames[i].stride < w * 3 || frames[i].stride > PTRDIFF_MAX / h)
            return KR_INVALID_ARGUMENT;
    try {
        return context->drba->predict(frames, w, h, time, output, stride);
    } catch (...) {
        return KR_INFERENCE_ERROR;
    }
}

bool drba_warp_gpu(KrContext *context, const KrMotion *grid, int mw, int mh, int w, int h, const KrPlane &plane)
{
    if (!context || !context->drba || !context->gpu) return false;
    try {
        return context->drba->warp_gpu(grid, mw, mh, w, h, plane);
    } catch (...) {
        return false;
    }
}
