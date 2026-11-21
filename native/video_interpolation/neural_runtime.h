/* Copyright 2026 Kazumi contributors. SPDX-License-Identifier: MIT */
#pragma once
#ifdef _WIN32
#include <windows.h>
#else
#include <dlfcn.h>
#endif
#include "rife_bridge.h"

struct api {
#ifdef _WIN32
    HMODULE module;
#else
    void *module;
#endif
    int (*predict_motion)(KrContext *, const KrRgbView [3], int, int, float, KrMotion *, ptrdiff_t);
    int (*warp_plane)(KrContext *, const KrMotion *, int, int, int, int, const KrPlane *, int);
    uint32_t (*abi)(void);
    int (*create)(const KrOptions *, KrContext **);
    void (*destroy)(KrContext *);
};

static void close_runtime(struct api *api)
{
    if (api->module) {
#ifdef _WIN32
        FreeLibrary(api->module);
#else
        dlclose(api->module);
#endif
    }
    *api = (struct api){0};
}

static int module_anchor;

static bool open_runtime(struct api *api)
{
#ifdef _WIN32
    HMODULE current;
    wchar_t path[32768];
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                            GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                            (LPCWSTR)&module_anchor, &current))
        return false;
    DWORD length = GetModuleFileNameW(current, path, MP_ARRAY_SIZE(path));
    if (!length || length >= MP_ARRAY_SIZE(path)) return false;
    wchar_t *end = wcsrchr(path, L'\\');
    if (!end || end + MP_ARRAY_SIZE(L"kazumi_rife.dll") >= path + MP_ARRAY_SIZE(path))
        return false;
    wcscpy(end + 1, L"kazumi_rife.dll");
    api->module = LoadLibraryExW(path, NULL,
        LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
#define LOOKUP(name) GetProcAddress(api->module, name)
#else
#if defined(__ANDROID__)
    // This resolves inside the APK's own linker namespace.
    (void)module_anchor;
    api->module = dlopen("libkazumi_rife.so", RTLD_NOW | RTLD_LOCAL | RTLD_NODELETE);
#else
    Dl_info info;
    if (!dladdr(&module_anchor, &info) || !info.dli_fname) return false;
    const char *end = strrchr(info.dli_fname, '/');
    if (!end) return false;
    char *path = talloc_asprintf(NULL, "%.*s/libkazumi_rife.so",
                                (int)(end - info.dli_fname), info.dli_fname);
    api->module = dlopen(path, RTLD_NOW | RTLD_LOCAL | RTLD_NODELETE);
    talloc_free(path);
#endif
#define LOOKUP(name) dlsym(api->module, name)
#endif
    if (!api->module) return false;
#define BIND(name) do {                                                          \
    __typeof__(LOOKUP("kr_" #name)) ptr = LOOKUP("kr_" #name);                   \
    if (!ptr) goto fail;                                                        \
    memcpy(&api->name, &ptr, sizeof(ptr));                                        \
} while (0)
    BIND(abi);
    BIND(create);
    BIND(destroy);
    BIND(predict_motion);
    BIND(warp_plane);
#undef BIND
#undef LOOKUP
    if (api->abi() != KR_ABI_VERSION) goto fail;
    // ncnn's OpenMP backend can keep worker/TLS teardown callbacks after the
    // last inference. Destroy each context, but keep the validated runtime
    // mapped when its filter is toggled off or the current episode closes.
#ifdef _WIN32
    HMODULE pinned = NULL;
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                            GET_MODULE_HANDLE_EX_FLAG_PIN,
                            (LPCWSTR)api->module, &pinned))
        goto fail;
    FreeLibrary(pinned); // Release this extra reference, not the lifetime pin.
#endif
    return true;
fail:
    close_runtime(api);
    return false;
}
