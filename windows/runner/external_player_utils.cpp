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
#include "external_player_utils.h"

void ExternalPlayerUtils::OpenWithPlayer(const char* url) {
    // Convert the URL from char* to wchar_t*
    int urlLength = MultiByteToWideChar(CP_ACP, 0, url, -1, NULL, 0);
    wchar_t* wideUrl = new wchar_t[urlLength];
    MultiByteToWideChar(CP_ACP, 0, url, -1, wideUrl, urlLength);

    SHELLEXECUTEINFO execInfo = {0};
    execInfo.cbSize = sizeof(SHELLEXECUTEINFO);
    execInfo.fMask = SEE_MASK_CLASSNAME;
    execInfo.lpVerb = L"open";
    execInfo.lpFile = wideUrl;
    execInfo.lpClass = L".m3u8"; 
    execInfo.nShow = SW_SHOWNORMAL;

    ShellExecuteEx(&execInfo);

    delete[] wideUrl;
}