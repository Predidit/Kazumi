// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2026 Predidit.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "d3d11_renderer.h"
#include "video_adapters.h"

#include <iostream>

#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")

int D3D11Renderer::instance_count_ = 0;

D3D11Renderer::D3D11Renderer(int32_t width, int32_t height,
                             IDXGIAdapter* flutter_adapter,
                             IDXGIAdapter* render_adapter,
                             bool force_event_queries)
    : force_event_queries_(force_event_queries) {
  if (render_adapter && !flutter_adapter) {
    throw std::runtime_error("Cannot identify Flutter's display adapter.");
  }
  if (!CreateD3D11Device(render_adapter ? render_adapter : flutter_adapter,
                         d3d_11_device_, d3d_11_device_context_)) {
    throw std::runtime_error("Unable to create Direct3D 11 render device.");
  }
  if (render_adapter && !SameVideoAdapter(render_adapter, flutter_adapter)) {
    if (!CreateD3D11Device(flutter_adapter, flutter_device_, flutter_context_)) {
      throw std::runtime_error("Unable to create Direct3D 11 display device.");
    }
  }
  if (!CreateSurfaces(width, height)) {
    throw std::runtime_error("Unable to allocate Direct3D 11 video surfaces.");
  }
  instance_count_++;
}

D3D11Renderer::~D3D11Renderer() { instance_count_--; }

bool D3D11Renderer::SetSize(int32_t width, int32_t height) {
  return (width == width_ && height == height_) || CreateSurfaces(width, height);
}

bool D3D11Renderer::ProducerCommit() {
  if (flutter_context_) {
    // DXGI shared handles from the rendering GPU cannot be opened on another
    // adapter. Read once from a staging texture and upload to the display GPU.
    d3d_11_device_context_->CopyResource(readback_texture_.Get(), render_texture_.Get());
    D3D11_MAPPED_SUBRESOURCE mapped{};
    const HRESULT hr = d3d_11_device_context_->Map(
        readback_texture_.Get(), 0, D3D11_MAP_READ, 0, &mapped);
    if (FAILED(hr)) return false;
    flutter_context_->UpdateSubresource(mailbox_swap_chain_->ProducerTexture(),
                                        0, nullptr, mapped.pData,
                                        mapped.RowPitch, 0);
    d3d_11_device_context_->Unmap(readback_texture_.Get(), 0);
  }
  // The mailbox flushes the display device and waits for this write.
  return mailbox_swap_chain_->ProducerCommit();
}

HANDLE D3D11Renderer::ConsumerAcquire() {
  if (mailbox_swap_chain_) {
    return mailbox_swap_chain_->ConsumerAcquire();
  }
  return nullptr;
}

bool D3D11Renderer::CreateD3D11Device(
    IDXGIAdapter* requested_adapter,
    Microsoft::WRL::ComPtr<ID3D11Device>& device,
    Microsoft::WRL::ComPtr<ID3D11DeviceContext>& context) {

  const D3D_FEATURE_LEVEL feature_levels[] = {
      D3D_FEATURE_LEVEL_11_1,
      D3D_FEATURE_LEVEL_11_0,
      D3D_FEATURE_LEVEL_10_1,
      D3D_FEATURE_LEVEL_10_0,
      D3D_FEATURE_LEVEL_9_3,
  };

  Microsoft::WRL::ComPtr<IDXGIAdapter> adapter(requested_adapter);
  D3D_DRIVER_TYPE driver_type = D3D_DRIVER_TYPE_UNKNOWN;

  if (!adapter) {
    if (Utils::IsWindows10RTMOrGreater()) {
      driver_type = D3D_DRIVER_TYPE_HARDWARE;
    } else {
      Microsoft::WRL::ComPtr<IDXGIFactory> dxgi;
      ::CreateDXGIFactory(__uuidof(IDXGIFactory), (void**)&dxgi);
      if (dxgi) {
        dxgi->EnumAdapters(0, &adapter);
      }
    }
  }

  const HRESULT hr = ::D3D11CreateDevice(
      adapter.Get(), driver_type, nullptr,
      D3D11_CREATE_DEVICE_BGRA_SUPPORT,
      feature_levels, static_cast<UINT>(std::size(feature_levels)),
      D3D11_SDK_VERSION, device.GetAddressOf(), nullptr,
      context.GetAddressOf());

  if (FAILED(hr)) {
    std::cout << "media_kit: D3D11Renderer: D3D11CreateDevice failed (hr=0x"
              << std::hex << hr << std::dec << ")" << std::endl;
    return false;
  }

  Microsoft::WRL::ComPtr<IDXGIDevice> dxgi_device;
  if (SUCCEEDED(device->QueryInterface(__uuidof(IDXGIDevice),
                                               (void**)&dxgi_device)) &&
      dxgi_device) {
    dxgi_device->SetGPUThreadPriority(5);
  }

  const auto level = device->GetFeatureLevel();
  std::cout << "media_kit: D3D11Renderer: Direct3D Feature Level: "
            << (static_cast<unsigned>(level) >> 12) << "_"
            << ((static_cast<unsigned>(level) >> 8) & 0xfu) << std::endl;

  return true;
}

bool D3D11Renderer::CreateSurfaces(int32_t width, int32_t height) {
  if (width < 1 || height < 1) return false;
  std::unique_ptr<MailboxSwapChain> mailbox;
  if (FAILED(MailboxSwapChain::Create(
          flutter_device_ ? flutter_device_.Get() : d3d_11_device_.Get(),
          width, height, &mailbox, force_event_queries_))) {
    return false;
  }

  Microsoft::WRL::ComPtr<ID3D11Texture2D> render, readback;
  if (flutter_device_) {
    D3D11_TEXTURE2D_DESC desc{};
    desc.Width = static_cast<UINT>(width);
    desc.Height = static_cast<UINT>(height);
    desc.MipLevels = desc.ArraySize = 1;
    desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    desc.SampleDesc.Count = 1;
    desc.Usage = D3D11_USAGE_DEFAULT;
    desc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
    if (FAILED(d3d_11_device_->CreateTexture2D(&desc, nullptr, &render))) {
      return false;
    }
    desc.Usage = D3D11_USAGE_STAGING;
    desc.BindFlags = 0;
    desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    if (FAILED(d3d_11_device_->CreateTexture2D(&desc, nullptr, &readback))) {
      return false;
    }
  }

  // Publish only once every allocation succeeded. The existing Flutter texture
  // retains its mailbox until a completed replacement is imported.
  render_texture_ = std::move(render);
  readback_texture_ = std::move(readback);
  mailbox_swap_chain_ = std::move(mailbox);
  width_ = width;
  height_ = height;
  return true;
}
