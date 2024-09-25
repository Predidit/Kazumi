// This file is a part of Kazumi
// (https://github.com/Predidit/Kazumi).
//
// Copyright © 2024 Predidit
// All rights reserved.
// Use of this source code is governed by GPLv3 license that can be found in the
// LICENSE file.

#include <windows.h>
#include <cstdio>
#include <string>
#include <iostream>
#include <fstream>
#include <random>
#include "external_player_utils.h"

void ExternalPlayerUtils::OpenWithPlayer(const char* url) {
    // temp file path
    wchar_t tempPath[MAX_PATH];
    GetTempPathW(MAX_PATH, tempPath);

    // Generate a random file name
    std::wstring randomFileName = L"kazumi_stream_";
    std::random_device rd;
    std::mt19937 eng(rd());
    std::uniform_int_distribution<> distr(10000000, 99999999);

    randomFileName += std::to_wstring(distr(eng)) + L".m3u8";

    wchar_t tempFile[MAX_PATH];
    wcscpy_s(tempFile, tempPath);
    wcscat_s(tempFile, randomFileName.c_str());

    // write the URL to the temp file
    std::wofstream outFile(tempFile);
    if (outFile.is_open()) {
        outFile << L"#EXTM3U\n";
        outFile << std::wstring(url, url + strlen(url));
        outFile.close();
    } else {
        return;
    }

    SHELLEXECUTEINFO execInfo = {0};
    execInfo.cbSize = sizeof(SHELLEXECUTEINFO);
    execInfo.fMask = SEE_MASK_INVOKEIDLIST;
    execInfo.lpVerb = L"openas";
    execInfo.lpFile = tempFile;
    execInfo.nShow = SW_SHOWNORMAL;

    ShellExecuteEx(&execInfo);

    // DeleteFileW(tempFile);
}