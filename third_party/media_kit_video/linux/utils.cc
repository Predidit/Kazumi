// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/utils.h"

void utils_enter_native_fullscreen(GtkWidget* window) {
  gtk_window_fullscreen(GTK_WINDOW(window));
}

void utils_exit_native_fullscreen(GtkWidget* window) {
  gtk_window_unfullscreen(GTK_WINDOW(window));
}
