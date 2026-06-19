// shortcut_utils.cpp - Windows desktop shortcut utilities

#include "shortcut_utils.h"

#include <shobjidl.h>
#include <shlobj.h>
#include <propkey.h>
#include <propvarutil.h>
#include <appmodel.h>

bool ShortcutUtils::CreateDesktopShortcut(const std::wstring& shortcutName, const std::wstring& description) {
  wchar_t desktopPath[MAX_PATH];
  if (SHGetFolderPathW(nullptr, CSIDL_DESKTOP, nullptr, 0, desktopPath) != S_OK) return false;

  std::wstring shortcutPath = std::wstring(desktopPath) + L"\\" + shortcutName + L".lnk";
  if (GetFileAttributesW(shortcutPath.c_str()) != INVALID_FILE_ATTRIBUTES) return true;

  // COM is already initialized in main.cpp, do not re-initialize
  IShellLinkW* pShellLink = nullptr;
  HRESULT hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (void**)&pShellLink);
  if (FAILED(hr)) return false;

  pShellLink->SetDescription(description.c_str());

  // Check if running as MSIX package
  UINT32 length = 0;
  std::wstring aumid;
  if (GetCurrentPackageFamilyName(&length, nullptr) == ERROR_INSUFFICIENT_BUFFER) {
    aumid.resize(length);
    if (GetCurrentPackageFamilyName(&length, &aumid[0]) == ERROR_SUCCESS) {
      if (!aumid.empty() && aumid.back() == L'\0') aumid.pop_back();
      aumid += L"!kazumi";
    }
  }

  bool success = false;
  IPersistFile* pPersistFile = nullptr;

  if (!aumid.empty()) {
    // MSIX: use shell:AppsFolder\AUMID
    pShellLink->SetPath((L"shell:AppsFolder\\" + aumid).c_str());

    IPropertyStore* pPropertyStore = nullptr;
    if (SUCCEEDED(pShellLink->QueryInterface(IID_IPropertyStore, (void**)&pPropertyStore))) {
      PROPVARIANT propVar;
      if (SUCCEEDED(InitPropVariantFromString(aumid.c_str(), &propVar))) {
        pPropertyStore->SetValue(PKEY_AppUserModel_ID, propVar);
        PropVariantClear(&propVar);
      }
      pPropertyStore->Commit();
      pPropertyStore->Release();
    }
  } else {
    // Portable: use executable path
    wchar_t exePath[MAX_PATH];
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    pShellLink->SetPath(exePath);
  }

  if (SUCCEEDED(pShellLink->QueryInterface(IID_IPersistFile, (void**)&pPersistFile))) {
    success = SUCCEEDED(pPersistFile->Save(shortcutPath.c_str(), TRUE));
    pPersistFile->Release();
  }

  pShellLink->Release();
  return success;
}