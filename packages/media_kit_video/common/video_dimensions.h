// Copyright (c) 2026 Predidit. MIT license.

#ifndef MEDIA_KIT_VIDEO_DIMENSIONS_H_
#define MEDIA_KIT_VIDEO_DIMENSIONS_H_

#include <cstdint>
#include <cstring>

#include "mpv/include/media_kit_mpv.h"

namespace media_kit {

struct VideoDimensions {
  int64_t width = 0;
  int64_t height = 0;
};

inline VideoDimensions GetVideoDimensions(mpv_handle* handle) {
  mpv_node params{};
  if (mpv_get_property(handle, "video-out-params", MPV_FORMAT_NODE, &params) < 0) {
    // Failed queries do not transfer node ownership.
    return {};
  }

  int64_t dw = 0, dh = 0, rotate = 0;
  if (params.format == MPV_FORMAT_NODE_MAP && params.u.list != nullptr) {
    const auto* list = params.u.list;
    for (int i = 0; i < list->num; ++i) {
      const auto& value = list->values[i];
      if (value.format != MPV_FORMAT_INT64) {
        continue;
      }
      const char* key = list->keys[i];
      if (std::strcmp(key, "dw") == 0) {
        dw = value.u.int64;
      } else if (std::strcmp(key, "dh") == 0) {
        dh = value.u.int64;
      } else if (std::strcmp(key, "rotate") == 0) {
        rotate = value.u.int64;
      }
    }
  }
  // Successful non-map results also need releasing.
  mpv_free_node_contents(&params);

  return rotate == 0 || rotate == 180 ? VideoDimensions{dw, dh}
                                    : VideoDimensions{dh, dw};
}

}  // namespace media_kit

#endif  // MEDIA_KIT_VIDEO_DIMENSIONS_H_
