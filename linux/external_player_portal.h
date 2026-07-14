#ifndef FLUTTER_EXTERNAL_PLAYER_PORTAL_H_
#define FLUTTER_EXTERNAL_PLAYER_PORTAL_H_

#include <glib.h>

enum class ExternalPlayerPortalResult {
  kLaunched,
  kCancelled,
  kUnavailable,
  kInvalidArgument,
  kFailed,
};

using ExternalPlayerPortalCallback = void (*)(
    ExternalPlayerPortalResult result,
    const gchar* error_message,
    gpointer user_data);

// Writes the URL to an M3U8 playlist in the system temporary directory and
// asks the desktop portal to open it with a user-selected application. The
// playlist is intentionally retained after the request completes.
void OpenExternalPlayerWithPortal(const gchar* url,
                                  ExternalPlayerPortalCallback callback,
                                  gpointer user_data);

// Cancels pending D-Bus calls and closes active portal requests during shutdown.
void CancelExternalPlayerPortalRequests();

#endif  // FLUTTER_EXTERNAL_PLAYER_PORTAL_H_
