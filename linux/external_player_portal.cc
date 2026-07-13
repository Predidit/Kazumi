#include "external_player_portal.h"

#include <errno.h>
#include <fcntl.h>
#include <gio/gio.h>
#include <gio/gunixfdlist.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <set>
#include <vector>

namespace {

constexpr char kPortalBusName[] = "org.freedesktop.portal.Desktop";
constexpr char kPortalObjectPath[] = "/org/freedesktop/portal/desktop";
constexpr char kOpenUriInterface[] = "org.freedesktop.portal.OpenURI";
constexpr char kRequestInterface[] = "org.freedesktop.portal.Request";
constexpr char kPlaylistSuffix[] = ".m3u8";
constexpr guint32 kMinimumOpenUriPortalVersion = 3;

struct OpenPortalRequest {
  gint reference_count;
  GDBusConnection* connection;
  GCancellable* cancellable;
  guint response_subscription_id;
  gchar* request_path;
  gchar* url;
  ExternalPlayerPortalCallback callback;
  gpointer user_data;
  bool completed;
};

std::set<OpenPortalRequest*> active_requests;

OpenPortalRequest* ReferenceRequest(OpenPortalRequest* request) {
  ++request->reference_count;
  return request;
}

void UnreferenceRequest(OpenPortalRequest* request) {
  if (--request->reference_count != 0) {
    return;
  }

  g_clear_object(&request->connection);
  g_clear_object(&request->cancellable);
  g_free(request->request_path);
  g_free(request->url);
  delete request;
}

void DestroyRequestReference(gpointer user_data) {
  UnreferenceRequest(static_cast<OpenPortalRequest*>(user_data));
}

bool IsSupportedUrl(const gchar* url) {
  if (url == nullptr || url[0] == '\0' || strchr(url, '\r') != nullptr ||
      strchr(url, '\n') != nullptr) {
    return false;
  }

  g_autofree gchar* scheme = g_uri_parse_scheme(url);
  return scheme != nullptr &&
         (g_ascii_strcasecmp(scheme, "http") == 0 ||
          g_ascii_strcasecmp(scheme, "https") == 0);
}

gchar* CreatePlaylist(const gchar* url, GError** error) {
  g_autofree gchar* path =
      g_build_filename(g_get_tmp_dir(), "kazumi_stream_XXXXXX.m3u8", nullptr);
  const int fd = mkstemps(path, strlen(kPlaylistSuffix));
  if (fd == -1) {
    g_set_error(error, G_FILE_ERROR, g_file_error_from_errno(errno),
                "Failed to create playlist: %s", g_strerror(errno));
    return nullptr;
  }

  g_autofree gchar* contents = g_strdup_printf("#EXTM3U\n%s\n", url);
  const gsize contents_length = strlen(contents);
  gsize written = 0;
  while (written < contents_length) {
    const ssize_t count =
        write(fd, contents + written, contents_length - written);
    if (count < 0 && errno == EINTR) {
      continue;
    }
    if (count <= 0) {
      const int saved_errno = errno;
      close(fd);
      g_set_error(error, G_FILE_ERROR, g_file_error_from_errno(saved_errno),
                  "Failed to write playlist: %s", g_strerror(saved_errno));
      return nullptr;
    }
    written += static_cast<gsize>(count);
  }

  if (close(fd) != 0) {
    const int saved_errno = errno;
    g_set_error(error, G_FILE_ERROR, g_file_error_from_errno(saved_errno),
                "Failed to close playlist: %s", g_strerror(saved_errno));
    return nullptr;
  }

  return g_steal_pointer(&path);
}

bool IsPortalUnavailableError(const GError* error) {
  return g_error_matches(error, G_DBUS_ERROR, G_DBUS_ERROR_SERVICE_UNKNOWN) ||
         g_error_matches(error, G_DBUS_ERROR, G_DBUS_ERROR_NAME_HAS_NO_OWNER) ||
         g_error_matches(error, G_DBUS_ERROR, G_DBUS_ERROR_UNKNOWN_METHOD) ||
         g_error_matches(error, G_IO_ERROR, G_IO_ERROR_NOT_SUPPORTED);
}

ExternalPlayerPortalResult ResultForPortalError(const GError* error) {
  return IsPortalUnavailableError(error)
             ? ExternalPlayerPortalResult::kUnavailable
             : ExternalPlayerPortalResult::kFailed;
}

void CompleteRequest(OpenPortalRequest* request,
                     ExternalPlayerPortalResult result,
                     const gchar* error_message) {
  if (request->completed) {
    return;
  }

  request->completed = true;
  if (request->response_subscription_id != 0 &&
      request->connection != nullptr) {
    const guint subscription_id = request->response_subscription_id;
    request->response_subscription_id = 0;
    g_dbus_connection_signal_unsubscribe(request->connection, subscription_id);
  }
  active_requests.erase(request);
  request->callback(result, error_message, request->user_data);
  UnreferenceRequest(request);
}

gchar* CreateHandleToken() {
  g_autofree gchar* uuid = g_uuid_string_random();
  for (gchar* character = uuid; *character != '\0'; ++character) {
    if (*character == '-') {
      *character = '_';
    }
  }
  return g_strdup_printf("kazumi_%s", uuid);
}

gchar* CreateExpectedRequestPath(GDBusConnection* connection,
                                 const gchar* handle_token) {
  const gchar* unique_name = g_dbus_connection_get_unique_name(connection);
  if (unique_name == nullptr) {
    return nullptr;
  }

  g_autofree gchar* sender = g_strdup(unique_name[0] == ':' ? unique_name + 1
                                                            : unique_name);
  for (gchar* character = sender; *character != '\0'; ++character) {
    if (*character == '.') {
      *character = '_';
    }
  }
  return g_strdup_printf("/org/freedesktop/portal/desktop/request/%s/%s",
                         sender, handle_token);
}

void PortalResponseReceived(GDBusConnection*,
                            const gchar*,
                            const gchar*,
                            const gchar*,
                            const gchar*,
                            GVariant* parameters,
                            gpointer user_data) {
  auto* request = static_cast<OpenPortalRequest*>(user_data);
  guint32 response = 2;
  g_variant_get_child(parameters, 0, "u", &response);

  if (response == 0) {
    CompleteRequest(request, ExternalPlayerPortalResult::kLaunched, nullptr);
  } else if (response == 1) {
    CompleteRequest(request, ExternalPlayerPortalResult::kCancelled, nullptr);
  } else {
    CompleteRequest(request, ExternalPlayerPortalResult::kUnavailable,
                    "The desktop portal could not open the playlist");
  }
}

guint SubscribeToResponse(OpenPortalRequest* request,
                          const gchar* request_path) {
  return g_dbus_connection_signal_subscribe(
      request->connection, kPortalBusName, kRequestInterface, "Response",
      request_path, nullptr, G_DBUS_SIGNAL_FLAGS_NONE,
      PortalResponseReceived, ReferenceRequest(request),
      DestroyRequestReference);
}

void OpenFileFinished(GObject* source_object,
                      GAsyncResult* result,
                      gpointer user_data) {
  auto* request = static_cast<OpenPortalRequest*>(user_data);
  g_autoptr(GError) error = nullptr;
  g_autoptr(GVariant) response =
      g_dbus_connection_call_with_unix_fd_list_finish(
          G_DBUS_CONNECTION(source_object), nullptr, result, &error);

  if (!request->completed && response == nullptr) {
    CompleteRequest(request, ResultForPortalError(error), error->message);
  } else if (!request->completed) {
    const gchar* returned_path = nullptr;
    g_variant_get(response, "(&o)", &returned_path);
    if (g_strcmp0(returned_path, request->request_path) != 0) {
      const guint new_subscription_id =
          SubscribeToResponse(request, returned_path);
      const guint old_subscription_id = request->response_subscription_id;
      request->response_subscription_id = new_subscription_id;
      g_free(request->request_path);
      request->request_path = g_strdup(returned_path);
      g_dbus_connection_signal_unsubscribe(request->connection,
                                           old_subscription_id);
    }
  }

  UnreferenceRequest(request);
}

void StartPortalOpen(OpenPortalRequest* request) {
  g_autoptr(GError) error = nullptr;
  g_autofree gchar* playlist_path = CreatePlaylist(request->url, &error);
  if (playlist_path == nullptr) {
    CompleteRequest(request, ExternalPlayerPortalResult::kFailed,
                    error->message);
    return;
  }

  const int playlist_fd = open(playlist_path, O_RDONLY | O_CLOEXEC);
  if (playlist_fd == -1) {
    const int saved_errno = errno;
    g_set_error(&error, G_FILE_ERROR, g_file_error_from_errno(saved_errno),
                "Failed to open playlist: %s", g_strerror(saved_errno));
    CompleteRequest(request, ExternalPlayerPortalResult::kFailed,
                    error->message);
    return;
  }

  g_autoptr(GUnixFDList) fd_list = g_unix_fd_list_new();
  const gint fd_index = g_unix_fd_list_append(fd_list, playlist_fd, &error);
  close(playlist_fd);
  if (fd_index == -1) {
    CompleteRequest(request, ExternalPlayerPortalResult::kFailed,
                    error->message);
    return;
  }

  g_autofree gchar* handle_token = CreateHandleToken();
  request->request_path =
      CreateExpectedRequestPath(request->connection, handle_token);
  if (request->request_path == nullptr) {
    CompleteRequest(request, ExternalPlayerPortalResult::kFailed,
                    "The session bus did not provide a unique connection name");
    return;
  }
  request->response_subscription_id =
      SubscribeToResponse(request, request->request_path);

  GVariantBuilder options;
  g_variant_builder_init(&options, G_VARIANT_TYPE_VARDICT);
  g_variant_builder_add(&options, "{sv}", "handle_token",
                        g_variant_new_string(handle_token));
  g_variant_builder_add(&options, "{sv}", "ask",
                        g_variant_new_boolean(TRUE));

  g_dbus_connection_call_with_unix_fd_list(
      request->connection, kPortalBusName, kPortalObjectPath,
      kOpenUriInterface, "OpenFile",
      g_variant_new("(sh@a{sv})", "", fd_index,
                    g_variant_builder_end(&options)),
      G_VARIANT_TYPE("(o)"), G_DBUS_CALL_FLAGS_NONE, -1, fd_list,
      request->cancellable, OpenFileFinished, ReferenceRequest(request));
}

void PortalVersionReady(GObject* source_object,
                        GAsyncResult* result,
                        gpointer user_data) {
  auto* request = static_cast<OpenPortalRequest*>(user_data);
  g_autoptr(GError) error = nullptr;
  g_autoptr(GVariant) response = g_dbus_connection_call_finish(
      G_DBUS_CONNECTION(source_object), result, &error);

  if (!request->completed && response == nullptr) {
    CompleteRequest(request, ResultForPortalError(error), error->message);
  } else if (!request->completed) {
    g_autoptr(GVariant) boxed_version = nullptr;
    g_variant_get(response, "(@v)", &boxed_version);
    g_autoptr(GVariant) version = g_variant_get_variant(boxed_version);
    if (!g_variant_is_of_type(version, G_VARIANT_TYPE_UINT32) ||
        g_variant_get_uint32(version) < kMinimumOpenUriPortalVersion) {
      CompleteRequest(
          request, ExternalPlayerPortalResult::kUnavailable,
          "The OpenURI portal does not support asking for an application");
    } else {
      StartPortalOpen(request);
    }
  }

  UnreferenceRequest(request);
}

void PortalBusReady(GObject*,
                    GAsyncResult* result,
                    gpointer user_data) {
  auto* request = static_cast<OpenPortalRequest*>(user_data);
  g_autoptr(GError) error = nullptr;
  request->connection = g_bus_get_finish(result, &error);

  if (!request->completed && request->connection == nullptr) {
    CompleteRequest(request, ExternalPlayerPortalResult::kUnavailable,
                    error->message);
  } else if (!request->completed) {
    g_dbus_connection_call(
        request->connection, kPortalBusName, kPortalObjectPath,
        "org.freedesktop.DBus.Properties", "Get",
        g_variant_new("(ss)", kOpenUriInterface, "version"),
        G_VARIANT_TYPE("(v)"), G_DBUS_CALL_FLAGS_NONE, -1,
        request->cancellable, PortalVersionReady, ReferenceRequest(request));
  }

  UnreferenceRequest(request);
}

void ClosePortalRequest(OpenPortalRequest* request) {
  if (request->connection == nullptr || request->request_path == nullptr) {
    return;
  }

  g_dbus_connection_call(request->connection, kPortalBusName,
                         request->request_path, kRequestInterface, "Close",
                         nullptr, nullptr, G_DBUS_CALL_FLAGS_NONE, -1, nullptr,
                         nullptr, nullptr);
}

}  // namespace

void OpenExternalPlayerWithPortal(const gchar* url,
                                  ExternalPlayerPortalCallback callback,
                                  gpointer user_data) {
  if (!IsSupportedUrl(url)) {
    callback(ExternalPlayerPortalResult::kInvalidArgument,
             "A non-empty HTTP(S) URL without line breaks is required",
             user_data);
    return;
  }

  auto* request = new OpenPortalRequest{
      1,
      nullptr,
      g_cancellable_new(),
      0,
      nullptr,
      g_strdup(url),
      callback,
      user_data,
      false,
  };
  active_requests.insert(request);
  g_bus_get(G_BUS_TYPE_SESSION, request->cancellable, PortalBusReady,
            ReferenceRequest(request));
}

void CancelExternalPlayerPortalRequests() {
  std::vector<OpenPortalRequest*> requests;
  requests.reserve(active_requests.size());
  for (OpenPortalRequest* request : active_requests) {
    requests.push_back(ReferenceRequest(request));
  }

  for (OpenPortalRequest* request : requests) {
    ClosePortalRequest(request);
    g_cancellable_cancel(request->cancellable);
    CompleteRequest(request, ExternalPlayerPortalResult::kCancelled, nullptr);
    UnreferenceRequest(request);
  }
}
