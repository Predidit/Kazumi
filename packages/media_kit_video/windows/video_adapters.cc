// Kazumi's Windows video render adapter selection. MIT, see ../LICENSE.
#include "video_adapters.h"

#include <d3dkmthk.h>

#include <cstdint>
#include <iomanip>
#include <set>
#include <sstream>

#pragma comment(lib, "dxgi.lib")

namespace {

bool IsHardwareRenderAdapter(const DXGI_ADAPTER_DESC1& desc) {
  if (desc.Flags & (DXGI_ADAPTER_FLAG_SOFTWARE | DXGI_ADAPTER_FLAG_REMOTE)) {
    return false;
  }

  // Indirect display drivers can repeat the backing GPU's name and memory
  // with a different LUID, without setting either DXGI flag above. Ask WDDM
  // about this exact LUID instead of deduplicating by name or requiring a monitor.
  D3DKMT_OPENADAPTERFROMLUID open{};
  open.AdapterLuid = desc.AdapterLuid;
  if (::D3DKMTOpenAdapterFromLuid(&open) < 0) return false;

  D3DKMT_ADAPTERTYPE type{};
  const D3DKMT_QUERYADAPTERINFO query{
      open.hAdapter, KMTQAITYPE_ADAPTERTYPE, &type, sizeof(type)};
  const auto status = ::D3DKMTQueryAdapterInfo(&query);
  const D3DKMT_CLOSEADAPTER close{open.hAdapter};
  ::D3DKMTCloseAdapter(&close);
  return status >= 0 && type.RenderSupported && !type.SoftwareDevice &&
         !type.IndirectDisplayDevice;
}

}  // namespace

std::vector<VideoAdapter> EnumerateVideoAdapters() {
  Microsoft::WRL::ComPtr<IDXGIFactory1> factory;
  std::vector<VideoAdapter> result;
  if (FAILED(::CreateDXGIFactory1(IID_PPV_ARGS(factory.GetAddressOf())))) {
    return result;
  }

  std::set<std::string> listed_ids;
  for (UINT index = 0;; ++index) {
    VideoAdapter item{};
    if (FAILED(factory->EnumAdapters1(index, item.adapter.GetAddressOf()))) {
      break;
    }
    if (FAILED(item.adapter->GetDesc1(&item.desc)) ||
        !IsHardwareRenderAdapter(item.desc)) {
      continue;
    }
    const auto luid = item.desc.AdapterLuid;
    std::ostringstream stream;
    stream << std::hex << std::setfill('0')
           << std::setw(8) << static_cast<uint32_t>(luid.HighPart) << ':'
           << std::setw(8) << static_cast<uint32_t>(luid.LowPart);
    item.id = stream.str();

    char utf8[sizeof(item.desc.Description) * 2]{};
    if (::WideCharToMultiByte(CP_UTF8, 0, item.desc.Description, -1, utf8,
                              static_cast<int>(sizeof(utf8)), nullptr,
                              nullptr) && listed_ids.insert(item.id).second) {
      item.name = utf8;
      result.push_back(std::move(item));
    }
  }
  return result;
}

Microsoft::WRL::ComPtr<IDXGIAdapter1> FindVideoAdapter(const std::string& id) {
  if (!id.empty()) {
    for (const auto& item : EnumerateVideoAdapters()) {
      if (item.id == id) return item.adapter;
    }
  }
  return nullptr;
}

bool SameVideoAdapter(IDXGIAdapter* first, IDXGIAdapter* second) {
  if (!first || !second) return false;
  DXGI_ADAPTER_DESC a{}, b{};
  return SUCCEEDED(first->GetDesc(&a)) && SUCCEEDED(second->GetDesc(&b)) &&
         a.AdapterLuid.HighPart == b.AdapterLuid.HighPart &&
         a.AdapterLuid.LowPart == b.AdapterLuid.LowPart;
}
