// shortcut_utils.cpp - Windows desktop shortcut utilities

#include "shortcut_utils.h"

#include <shobjidl.h>
#include <shlobj.h>
#include <propkey.h>  // For PKEY_AppUserModel_ID
#include <propvarutil.h>  // For InitPropVariantFromString
#include <appmodel.h>  // For GetCurrentPackageInfo

#include <flutter/flutter_view_controller.h>

bool ShortcutUtils::IsMsixPackage() {
  // Try to get package family name - if successful, we're in an MSIX package
  UINT32 familyNameLength = 0;
  LONG result = GetCurrentPackageFamilyName(&familyNameLength, nullptr);

  OutputDebugStringW(L"[ShortcutUtils] IsMsixPackage check, result: ");
  wchar_t buf[32];
  _itow_s(result, buf, 10);
  OutputDebugStringW(buf);
  OutputDebugStringW(L"\n");

  // If we need a buffer, it means a package exists
  if (result == ERROR_INSUFFICIENT_BUFFER || result == ERROR_SUCCESS) {
    OutputDebugStringW(L"[ShortcutUtils] Running as MSIX package\n");
    return true;
  }

  // Other errors (like APPMODEL_ERROR_NO_PACKAGE) mean no package
  OutputDebugStringW(L"[ShortcutUtils] NOT running as MSIX package\n");
  return false;
}

std::wstring ShortcutUtils::GetAppUserModelId() {
  if (!IsMsixPackage()) {
    OutputDebugStringW(L"[ShortcutUtils] GetAppUserModelId: not MSIX\n");
    return L"";
  }

  // Get the Package Family Name
  UINT32 familyNameLength = 0;
  LONG result = GetCurrentPackageFamilyName(&familyNameLength, nullptr);

  if (result != ERROR_INSUFFICIENT_BUFFER) {
    OutputDebugStringW(L"[ShortcutUtils] GetAppUserModelId: first call failed\n");
    return L"";
  }

  std::wstring familyName;
  familyName.resize(familyNameLength);
  result = GetCurrentPackageFamilyName(&familyNameLength, &familyName[0]);

  if (result != ERROR_SUCCESS) {
    OutputDebugStringW(L"[ShortcutUtils] GetAppUserModelId: second call failed\n");
    return L"";
  }

  // Remove trailing null character if present
  if (familyNameLength > 0 && familyName.back() == L'\0') {
    familyName.pop_back();
  }

  OutputDebugStringW(L"[ShortcutUtils] Package Family Name: ");
  OutputDebugStringW(familyName.c_str());
  OutputDebugStringW(L"\n");

  // For Flutter MSIX apps, the AppUserModelId format is:
  // PackageFamilyName!AppId
  // The AppId is defined in AppxManifest.xml <Application Id="...">
  // For Kazumi, it should be: PackageFamilyName!kazumi
  std::wstring appId = L"kazumi";
  std::wstring appUserModelId = familyName + L"!" + appId;

  OutputDebugStringW(L"[ShortcutUtils] Final AUMID: ");
  OutputDebugStringW(appUserModelId.c_str());
  OutputDebugStringW(L"\n");

  return appUserModelId;
}

bool ShortcutUtils::CreateDesktopShortcut(
    const std::wstring& shortcutName,
    const std::wstring& description) {

  // Get desktop path
  wchar_t desktopPath[MAX_PATH];
  if (SHGetFolderPathW(NULL, CSIDL_DESKTOP, NULL, 0, desktopPath) != S_OK) {
    return false;
  }

  // Build shortcut full path
  std::wstring shortcutPath = std::wstring(desktopPath) + L"\\";
  shortcutPath += shortcutName;
  shortcutPath += L".lnk";

  // Check if shortcut already exists
  if (GetFileAttributesW(shortcutPath.c_str()) != INVALID_FILE_ATTRIBUTES) {
    return true;
  }

  // Determine if we're in MSIX package
  if (IsMsixPackage()) {
    std::wstring aumid = GetAppUserModelId();
    if (!aumid.empty()) {
      return CreateMsixShortcut(shortcutPath, aumid, description);
    }
    // If we couldn't get AUMID, fallback to executable shortcut
    // (this may have permission issues, but try anyway)
  }

  // Get current executable path for non-MSIX apps
  wchar_t exePath[MAX_PATH];
  GetModuleFileNameW(NULL, exePath, MAX_PATH);

  return CreateExecutableShortcut(shortcutPath, exePath, description);
}

bool ShortcutUtils::CreateExecutableShortcut(
    const std::wstring& shortcutPath,
    const std::wstring& exePath,
    const std::wstring& description) {

  HRESULT hr = CoInitialize(NULL);
  if (FAILED(hr)) {
    return false;
  }

  IShellLinkW* pShellLink = NULL;
  hr = CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER,
                       IID_IShellLinkW, (void**)&pShellLink);
  if (FAILED(hr)) {
    CoUninitialize();
    return false;
  }

  pShellLink->SetPath(exePath.c_str());
  pShellLink->SetDescription(description.c_str());

  IPersistFile* pPersistFile = NULL;
  hr = pShellLink->QueryInterface(IID_IPersistFile, (void**)&pPersistFile);
  if (FAILED(hr)) {
    pShellLink->Release();
    CoUninitialize();
    return false;
  }

  hr = pPersistFile->Save(shortcutPath.c_str(), TRUE);
  pPersistFile->Release();
  pShellLink->Release();
  CoUninitialize();

  return SUCCEEDED(hr);
}

bool ShortcutUtils::CreateMsixShortcut(
    const std::wstring& shortcutPath,
    const std::wstring& appUserModelId,
    const std::wstring& description) {

  // Debug output
  OutputDebugStringW(L"[ShortcutUtils] Creating MSIX shortcut\n");
  OutputDebugStringW(L"[ShortcutUtils] AUMID: ");
  OutputDebugStringW(appUserModelId.c_str());
  OutputDebugStringW(L"\n");
  OutputDebugStringW(L"[ShortcutUtils] Shortcut path: ");
  OutputDebugStringW(shortcutPath.c_str());
  OutputDebugStringW(L"\n");

  HRESULT hr = CoInitialize(NULL);
  if (FAILED(hr)) {
    OutputDebugStringW(L"[ShortcutUtils] CoInitialize failed\n");
    return false;
  }

  IShellLinkW* pShellLink = NULL;
  hr = CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER,
                       IID_IShellLinkW, (void**)&pShellLink);
  if (FAILED(hr)) {
    OutputDebugStringW(L"[ShortcutUtils] CoCreateInstance failed\n");
    CoUninitialize();
    return false;
  }

  pShellLink->SetDescription(description.c_str());

  // For MSIX apps, use shell:AppsFolder\AUMID as the target path
  // This is the correct way to create shortcuts for packaged apps
  std::wstring shellPath = L"shell:AppsFolder\\" + appUserModelId;
  OutputDebugStringW(L"[ShortcutUtils] Shell path: ");
  OutputDebugStringW(shellPath.c_str());
  OutputDebugStringW(L"\n");

  hr = pShellLink->SetPath(shellPath.c_str());
  if (FAILED(hr)) {
    OutputDebugStringW(L"[ShortcutUtils] SetPath failed\n");
  }

  // Also set the AppUserModelID property for proper identification
  IPropertyStore* pPropertyStore = NULL;
  hr = pShellLink->QueryInterface(IID_IPropertyStore, (void**)&pPropertyStore);
  if (SUCCEEDED(hr)) {
    PROPVARIANT propVar;
    hr = InitPropVariantFromString(appUserModelId.c_str(), &propVar);
    if (SUCCEEDED(hr)) {
      hr = pPropertyStore->SetValue(PKEY_AppUserModel_ID, propVar);
      if (FAILED(hr)) {
        OutputDebugStringW(L"[ShortcutUtils] SetValue PKEY_AppUserModel_ID failed\n");
      }
      PropVariantClear(&propVar);
    }
    hr = pPropertyStore->Commit();
    if (FAILED(hr)) {
      OutputDebugStringW(L"[ShortcutUtils] Commit failed\n");
    }
    pPropertyStore->Release();
  }

  // Save the shortcut
  IPersistFile* pPersistFile = NULL;
  hr = pShellLink->QueryInterface(IID_IPersistFile, (void**)&pPersistFile);
  if (FAILED(hr)) {
    OutputDebugStringW(L"[ShortcutUtils] QueryInterface IPersistFile failed\n");
    pShellLink->Release();
    CoUninitialize();
    return false;
  }

  hr = pPersistFile->Save(shortcutPath.c_str(), TRUE);
  if (FAILED(hr)) {
    OutputDebugStringW(L"[ShortcutUtils] Save failed\n");
  } else {
    OutputDebugStringW(L"[ShortcutUtils] Shortcut saved successfully\n");
  }
  pPersistFile->Release();
  pShellLink->Release();
  CoUninitialize();

  return SUCCEEDED(hr);
}