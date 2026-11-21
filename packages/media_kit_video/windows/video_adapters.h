// Kazumi's Windows video render adapter selection. MIT, see ../LICENSE.
#pragma once

#include <Windows.h>
#include <dxgi1_2.h>
#include <wrl.h>

#include <string>
#include <vector>

struct VideoAdapter {
  Microsoft::WRL::ComPtr<IDXGIAdapter1> adapter;
  DXGI_ADAPTER_DESC1 desc;
  std::string id;
  std::string name;
};

std::vector<VideoAdapter> EnumerateVideoAdapters();
Microsoft::WRL::ComPtr<IDXGIAdapter1> FindVideoAdapter(const std::string& id);
bool SameVideoAdapter(IDXGIAdapter* first, IDXGIAdapter* second);
