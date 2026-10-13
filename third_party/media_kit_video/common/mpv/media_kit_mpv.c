#define MEDIA_KIT_MPV_IMPLEMENTATION
#include "include/media_kit_mpv.h"
#include <string.h>

#ifdef _WIN32
#include <windows.h>
static SRWLOCK mutex = SRWLOCK_INIT;
#define LOCK() AcquireSRWLockExclusive(&mutex)
#define UNLOCK() ReleaseSRWLockExclusive(&mutex)
typedef HMODULE library_handle;
typedef FARPROC symbol_pointer;
#define SYMBOL(module, name) GetProcAddress(module, name)
#define CLOSE(module) FreeLibrary(module)
static library_handle open_library(const char *path) {
    wchar_t wide[32768];
    if (!MultiByteToWideChar(CP_UTF8, 0, path, -1, wide, 32768)) return NULL;
    return LoadLibraryW(wide);
}
#else
#include <pthread.h>
#include <dlfcn.h>
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
#define LOCK() pthread_mutex_lock(&mutex)
#define UNLOCK() pthread_mutex_unlock(&mutex)
typedef void *library_handle;
typedef void *symbol_pointer;
#define SYMBOL(module, name) dlsym(module, name)
#define CLOSE(module) dlclose(module)
static library_handle open_library(const char *path) { return dlopen(path, RTLD_NOW | RTLD_LOCAL); }
#endif

typedef struct {
    const char *(*error_string)(int);
    void (*free_node_contents)(mpv_node *);
    int (*get_property)(mpv_handle *, const char *, mpv_format, void *);
    int (*set_option_string)(mpv_handle *, const char *, const char *);
    int (*render_context_create)(mpv_render_context **, mpv_handle *, mpv_render_param *);
    void (*render_context_free)(mpv_render_context *);
    int (*render_context_render)(mpv_render_context *, mpv_render_param *);
    void (*render_context_report_swap)(mpv_render_context *);
    void (*render_context_set_update_callback)(mpv_render_context *, mpv_render_update_fn, void *);
} mpv_api;
static mpv_api api;
static library_handle library;

int media_kit_mpv_initialize(const char *path) {
    if (!path || !path[0]) return -1;
    LOCK();
    library_handle candidate = open_library(path);
    if (!candidate) { UNLOCK(); return -1; }
    if (library) {
        const int result = library == candidate ? 0 : -2;
        CLOSE(candidate);
        UNLOCK();
        return result;
    }
    mpv_api next;
    // Avoid incompatible C function/object pointer casts.
#define LOAD(name) do { \
    symbol_pointer symbol = SYMBOL(candidate, "mpv_" #name); \
    if (!symbol) { CLOSE(candidate); UNLOCK(); return -1; } \
    memcpy(&next.name, &symbol, sizeof(symbol)); \
} while (0)
    LOAD(error_string);
    LOAD(free_node_contents);
    LOAD(get_property);
    LOAD(set_option_string);
    LOAD(render_context_create);
    LOAD(render_context_free);
    LOAD(render_context_render);
    LOAD(render_context_report_swap);
    LOAD(render_context_set_update_callback);
#undef LOAD
    api = next;
    library = candidate; // Process lifetime; render callbacks can outlive engines.
    UNLOCK();
    return 0;
}

const char *media_kit_mpv_error_string(int error) { return api.error_string(error); }
void media_kit_mpv_free_node_contents(mpv_node *node) { api.free_node_contents(node); }
int media_kit_mpv_get_property(mpv_handle *h, const char *n, mpv_format f, void *d) { return api.get_property(h, n, f, d); }
int media_kit_mpv_set_option_string(mpv_handle *h, const char *n, const char *v) { return api.set_option_string(h, n, v); }
int media_kit_mpv_render_context_create(mpv_render_context **c, mpv_handle *h, mpv_render_param *p) { return api.render_context_create(c, h, p); }
void media_kit_mpv_render_context_free(mpv_render_context *c) { api.render_context_free(c); }
int media_kit_mpv_render_context_render(mpv_render_context *c, mpv_render_param *p) { return api.render_context_render(c, p); }
void media_kit_mpv_render_context_report_swap(mpv_render_context *c) { api.render_context_report_swap(c); }
void media_kit_mpv_render_context_set_update_callback(mpv_render_context *c, mpv_render_update_fn f, void *d) { api.render_context_set_update_callback(c, f, d); }
