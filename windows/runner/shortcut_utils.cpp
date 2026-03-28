// shortcut_utils.cpp - Windows desktop shortcut utilities

#include "shortcut_utils.h"

#include <shobjidl.h>
#include <shlobj.h>
#include <propkey.h>
#include <propvarutil.h>
#include <appmodel.h>

// Get AppUserModelId for MSIX package, returns empty string for portable
static std::wstring GetAppUserModelId() {
  UINT32 length = 0;
  LONG result = GetCurrentPackageFamilyName(&length, nullptr);
  if (result != ERROR_INSUFFICIENT_BUFFER) return L"";

  std::wstring familyName;
  familyName.resize(length);
  result = GetCurrentPackageFamilyName(&length, &familyName[0]);
  if (result != ERROR_SUCCESS) return L"";

  if (!familyName.empty() && familyName.back() == L'\0') {
    familyName.pop_back();
  }

  return familyName + L"!kazumi";
}

static bool SaveShortcut(IShellLinkW* pShellLink, const std::wstring& path) {
  IPersistFile* pPersistFile = nullptr;
  HRESULT hr = pShellLink->QueryInterface(IID_IPersistFile, (void**)&pPersistFile);
  if (FAILED(hr)) return false;

  hr = pPersistFile->Save(path.c_str(), TRUE);
  pPersistFile->Release();
  return SUCCEEDED(hr);
}

bool ShortcutUtils::CreateDesktopShortcut(const std::wstring& shortcutName, const std::wstring& description) {
  wchar_t desktopPath[MAX_PATH];
  if (SHGetFolderPathW(nullptr, CSIDL_DESKTOP, nullptr, 0, desktopPath) != S_OK) return false;

  std::wstring shortcutPath = std::wstring(desktopPath) + L"\\";
  shortcutPath += shortcutName;
  shortcutPath += L".lnk";

  // Skip if already exists
  if (GetFileAttributesW(shortcutPath.c_str()) != INVALID_FILE_ATTRIBUTES) return true;

  HRESULT hr = CoInitialize(nullptr);
  if (FAILED(hr)) return false;

  IShellLinkW* pShellLink = nullptr;
  hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (void**)&pShellLink);
  if (FAILED(hr)) {
    CoUninitialize();
    return false;
  }

  pShellLink->SetDescription(description.c_str());

  std::wstring aumid = GetAppUserModelId();
  bool success = false;

  if (!aumid.empty()) {
    // MSIX: use shell:AppsFolder\AUMID
    std::wstring shellPath = L"shell:AppsFolder\\" + aumid;
    pShellLink->SetPath(shellPath.c_str());

    // Set AppUserModelID property for proper taskbar grouping
    IPropertyStore* pPropertyStore = nullptr;
    hr = pShellLink->QueryInterface(IID_IPropertyStore, (void**)&pPropertyStore);
    if (SUCCEEDED(hr)) {
      PROPVARIANT propVar;
      if (SUCCEEDED(InitPropVariantFromString(aumid.c_str(), &propVar))) {
        pPropertyStore->SetValue(PKEY_AppUserModel_ID, propVar);
        PropVariantClear(&propVar);
      }
      pPropertyStore->Commit();
      pPropertyStore->Release();
    }
    success = SaveShortcut(pShellLink, shortcutPath);
  } else {
    // Portable: use executable path
    wchar_t exePath[MAX_PATH];
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    pShellLink->SetPath(exePath);
    success = SaveShortcut(pShellLink, shortcutPath);
  }

  pShellLink->Release();
  CoUninitialize();
  return success;
}