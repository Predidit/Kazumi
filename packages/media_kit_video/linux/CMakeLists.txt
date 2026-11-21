cmake_minimum_required(VERSION 3.10)
project(media_kit_video LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)
set(PLUGIN_NAME "media_kit_video_plugin")
find_package(PkgConfig REQUIRED)
pkg_check_modules(epoxy REQUIRED IMPORTED_TARGET epoxy)
find_package(Threads REQUIRED)
add_library(${PLUGIN_NAME} SHARED
  "media_kit_video_plugin.cc" "texture_gl.cc" "texture_sw.cc"
  "video_output_manager.cc" "video_output.cc" "gl_render_thread.cc" "utils.cc"
  "../common/mpv/media_kit_mpv.c")
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME}
  INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include"
  PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../common/mpv/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter PkgConfig::GTK PkgConfig::epoxy Threads::Threads ${CMAKE_DL_LIBS})
# Native libraries are emitted by media_kit's Dart build hook.
set(media_kit_video_bundled_libraries "" PARENT_SCOPE)
