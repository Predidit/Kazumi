// This file is a part of Kazumi
// (https://github.com/Predidit/Kazumi).
//
// Copyright © 2024 Predidit
// All rights reserved.
// Use of this source code is governed by GPLv3 license that can be found in the
// LICENSE file.

#ifndef EXTERNAL_PLAYER_UTILS_H_
#define EXTERNAL_PLAYER_UTILS_H_

#include <cstdint>

#include <Windows.h>

class ExternalPlayerUtils {
 public:
  static void OpenWithPlayer(const char* url);
};

#endif  // EXTERNAL_PLAYER_UTILS_H_
