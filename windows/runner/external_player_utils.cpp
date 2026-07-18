// This file is a part of Kazumi
// (https://github.com/Predidit/Kazumi).
//
// Copyright © 2024 Predidit
// All rights reserved.
// Use of this source code is governed by GPLv3 license that can be found in the
// LICENSE file.

#include "external_player_utils.h"

#include <chrono>
#include <random>
#include <string>
#include <thread>

namespace {

constexpr wchar_t kPlaylistPrefix[] = L"kazumi_stream_";
constexpr wchar_t kPlaylistSuffix[] = L".m3u8";
constexpr size_t kMaximumUrlBytes = 64 * 1024;
constexpr ULONGLONG kFileTimeTicksPerSecond = 10000000ULL;
constexpr ULONGLONG kStalePlaylistSeconds = 60ULL * 60ULL;

bool IsSafePlaylistEntry(const std::string& url) {
  return !url.empty() && url.size() <= kMaximumUrlBytes &&
         url.find('\0') == std::string::npos &&
         url.find('\r') == std::string::npos &&
         url.find('\n') == std::string::npos;
}

std::wstring EnsureTrailingSeparator(std::wstring path) {
  if (!path.empty() && path.back() != L'\\' && path.back() != L'/') {
    path.push_back(L'\\');
  }
  return path;
}

void CleanupStalePlaylists(const std::wstring& temp_path) {
  const std::wstring pattern =
      temp_path + kPlaylistPrefix + L"*" + kPlaylistSuffix;
  WIN32_FIND_DATAW find_data = {};
  HANDLE find_handle = ::FindFirstFileW(pattern.c_str(), &find_data);
  if (find_handle == INVALID_HANDLE_VALUE) {
    return;
  }

  FILETIME now_file_time = {};
  ::GetSystemTimeAsFileTime(&now_file_time);
  ULARGE_INTEGER now = {};
  now.LowPart = now_file_time.dwLowDateTime;
  now.HighPart = now_file_time.dwHighDateTime;
  const ULONGLONG stale_ticks =
      kStalePlaylistSeconds * kFileTimeTicksPerSecond;

  do {
    if ((find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
      continue;
    }
    ULARGE_INTEGER modified = {};
    modified.LowPart = find_data.ftLastWriteTime.dwLowDateTime;
    modified.HighPart = find_data.ftLastWriteTime.dwHighDateTime;
    if (now.QuadPart > modified.QuadPart &&
        now.QuadPart - modified.QuadPart > stale_ticks) {
      ::DeleteFileW((temp_path + find_data.cFileName).c_str());
    }
  } while (::FindNextFileW(find_handle, &find_data));

  ::FindClose(find_handle);
}

bool CreatePlaylistFile(const std::wstring& temp_path,
                        const std::string& url,
                        std::wstring* playlist_path) {
  std::random_device random_device;
  std::mt19937_64 generator(random_device());

  for (int attempt = 0; attempt < 16; ++attempt) {
    wchar_t token[33] = {};
    swprintf_s(token, L"%016llx%016llx",
               static_cast<unsigned long long>(generator()),
               static_cast<unsigned long long>(generator()));
    const std::wstring candidate =
        temp_path + kPlaylistPrefix + token + kPlaylistSuffix;
    HANDLE file = ::CreateFileW(
        candidate.c_str(), GENERIC_WRITE, FILE_SHARE_READ, nullptr, CREATE_NEW,
        FILE_ATTRIBUTE_TEMPORARY | FILE_ATTRIBUTE_NOT_CONTENT_INDEXED, nullptr);
    if (file == INVALID_HANDLE_VALUE) {
      if (::GetLastError() == ERROR_FILE_EXISTS) {
        continue;
      }
      return false;
    }

    const std::string content = "#EXTM3U\r\n" + url + "\r\n";
    DWORD bytes_written = 0;
    const BOOL write_succeeded =
        ::WriteFile(file, content.data(), static_cast<DWORD>(content.size()),
                    &bytes_written, nullptr);
    const BOOL flush_succeeded =
        write_succeeded ? ::FlushFileBuffers(file) : FALSE;
    ::CloseHandle(file);
    if (!write_succeeded || !flush_succeeded ||
        bytes_written != content.size()) {
      ::DeleteFileW(candidate.c_str());
      return false;
    }

    *playlist_path = candidate;
    return true;
  }
  return false;
}

void SchedulePlaylistCleanup(std::wstring playlist_path) {
  std::thread([playlist_path = std::move(playlist_path)]() {
    std::this_thread::sleep_for(std::chrono::minutes(5));
    ::DeleteFileW(playlist_path.c_str());
  }).detach();
}

}  // namespace

bool ExternalPlayerUtils::OpenWithPlayer(const std::string& url) {
  if (!IsSafePlaylistEntry(url)) {
    return false;
  }

  wchar_t temp_path_buffer[MAX_PATH + 1] = {};
  const DWORD length =
      ::GetTempPathW(_countof(temp_path_buffer), temp_path_buffer);
  if (length == 0 || length >= _countof(temp_path_buffer)) {
    return false;
  }
  const std::wstring temp_path =
      EnsureTrailingSeparator(std::wstring(temp_path_buffer, length));
  CleanupStalePlaylists(temp_path);

  std::wstring playlist_path;
  if (!CreatePlaylistFile(temp_path, url, &playlist_path)) {
    return false;
  }

  SHELLEXECUTEINFOW exec_info = {};
  exec_info.cbSize = sizeof(SHELLEXECUTEINFOW);
  exec_info.fMask = SEE_MASK_INVOKEIDLIST | SEE_MASK_NOCLOSEPROCESS;
  exec_info.lpVerb = L"openas";
  exec_info.lpFile = playlist_path.c_str();
  exec_info.nShow = SW_SHOWNORMAL;

  if (!::ShellExecuteExW(&exec_info)) {
    ::DeleteFileW(playlist_path.c_str());
    return false;
  }
  if (exec_info.hProcess != nullptr) {
    ::CloseHandle(exec_info.hProcess);
  }
  SchedulePlaylistCleanup(std::move(playlist_path));
  return true;
}
