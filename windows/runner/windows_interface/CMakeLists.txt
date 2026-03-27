cmake_minimum_required(VERSION 3.14)
project(windows_interface LANGUAGES CXX)

add_library(windows_interface STATIC
  "windows_interface.cpp"
)

apply_standard_settings(windows_interface)

target_compile_definitions(windows_interface PRIVATE "NOMINMAX")

target_link_libraries(windows_interface PRIVATE flutter flutter_wrapper_plugin)

target_include_directories(windows_interface INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
