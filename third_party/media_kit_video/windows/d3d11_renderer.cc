// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2026 Predidit.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "d3d11_renderer.h"

#include <iostream>
#include <iterator>
#include <stdexcept>

#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")

int D3D11Renderer::instance_count_ = 0;

D3D11Renderer::D3D11Renderer(int32_t width, int32_t height,
                             IDXGIAdapter* flutter_adapter,
                             std::string selected_adapter_id)
    : width_(width), height_(height), flutter_adapter_(flutter_adapter) {
  const bool has_selected_adapter =
      selected_adapter_id != "auto" && !selected_adapter_id.empty();
  Microsoft::WRL::ComPtr<IDXGIAdapter> render_adapter;
  if (has_selected_adapter) {
    auto selected_adapter = Utils::FindD3D11Adapter(selected_adapter_id);
    if (!selected_adapter) {
      throw std::runtime_error("Selected D3D11 adapter is no longer available.");
    }
    render_adapter = selected_adapter;
    if (!flutter_adapter) {
      throw std::runtime_error("Flutter's D3D11 adapter is unavailable.");
    }
  } else if (flutter_adapter) {
    render_adapter = flutter_adapter;
  }

  if (!CreateD3D11Device(render_adapter.Get(), d3d_11_device_,
                         d3d_11_device_context_)) {
    throw std::runtime_error("Unable to create Direct3D 11 render device.");
  }

  if (has_selected_adapter) {
    DXGI_ADAPTER_DESC render_description = {};
    DXGI_ADAPTER_DESC flutter_description = {};
    if (!render_adapter || !flutter_adapter ||
        FAILED(render_adapter->GetDesc(&render_description)) ||
        FAILED(flutter_adapter->GetDesc(&flutter_description))) {
      throw std::runtime_error("Unable to compare D3D11 adapter identities.");
    }
    cross_adapter_ =
        render_description.AdapterLuid.HighPart !=
            flutter_description.AdapterLuid.HighPart ||
        render_description.AdapterLuid.LowPart !=
            flutter_description.AdapterLuid.LowPart;
  }

  if (!CreateMailbox()) {
    throw std::runtime_error("Unable to create D3D11 mailbox swap chain.");
  }
  if (cross_adapter_ && !CreateReadbackTexture()) {
    throw std::runtime_error("Unable to create cross-adapter readback texture.");
  }
  cross_adapter_ready_ = true;

  instance_count_++;
}

D3D11Renderer::~D3D11Renderer() {
  readback_texture_.Reset();
  flutter_mailbox_swap_chain_.Reset();
  render_mailbox_swap_chain_.Reset();
  flutter_device_context_.Reset();
  flutter_device_.Reset();
  d3d_11_device_context_.Reset();
  d3d_11_device_.Reset();
  instance_count_--;
}

void D3D11Renderer::SetSize(int32_t width, int32_t height) {
  if (width == width_ && height == height_) return;
  width_ = width;
  height_ = height;
  readback_texture_.Reset();
  cross_adapter_ready_ = false;

  bool resize_succeeded = true;
  if (render_mailbox_swap_chain_) {
    const HRESULT hr = render_mailbox_swap_chain_->Resize(width_, height_);
    if (FAILED(hr)) {
      std::cout << "media_kit: D3D11Renderer: Render mailbox resize failed "
                   "(hr=0x"
                << std::hex << hr << std::dec << ")" << std::endl;
      resize_succeeded = false;
    }
  }
  if (cross_adapter_ && flutter_mailbox_swap_chain_) {
    const HRESULT hr = flutter_mailbox_swap_chain_->Resize(width_, height_);
    if (FAILED(hr)) {
      std::cout << "media_kit: D3D11Renderer: Flutter mailbox resize failed "
                   "(hr=0x"
                << std::hex << hr << std::dec << ")" << std::endl;
      resize_succeeded = false;
    }
    if (resize_succeeded && CreateReadbackTexture()) {
      cross_adapter_ready_ = true;
    } else {
      std::cout << "media_kit: D3D11Renderer: Readback texture recreation "
                   "failed."
                << std::endl;
    }
  }
}

bool D3D11Renderer::ProducerCommit() {
  if (cross_adapter_) {
    return TransferFrameToFlutterAdapter();
  }
  if (flutter_mailbox_swap_chain_) {
    return flutter_mailbox_swap_chain_->ProducerCommit();
  }
  return false;
}

HANDLE D3D11Renderer::ConsumerAcquire() {
  if (flutter_mailbox_swap_chain_) {
    return flutter_mailbox_swap_chain_->ConsumerAcquire();
  }
  return nullptr;
}

HANDLE D3D11Renderer::ReadHandleSnapshot() const {
  if (flutter_mailbox_swap_chain_) {
    return flutter_mailbox_swap_chain_->ReadHandleSnapshot();
  }
  return nullptr;
}

bool D3D11Renderer::CreateD3D11Device(
    IDXGIAdapter* adapter,
    Microsoft::WRL::ComPtr<ID3D11Device>& device,
    Microsoft::WRL::ComPtr<ID3D11DeviceContext>& context) {
  const D3D_FEATURE_LEVEL feature_levels[] = {
      D3D_FEATURE_LEVEL_11_1,
      D3D_FEATURE_LEVEL_11_0,
      D3D_FEATURE_LEVEL_10_1,
      D3D_FEATURE_LEVEL_10_0,
      D3D_FEATURE_LEVEL_9_3,
  };
  D3D_DRIVER_TYPE driver_type =
      adapter ? D3D_DRIVER_TYPE_UNKNOWN : D3D_DRIVER_TYPE_HARDWARE;
  Microsoft::WRL::ComPtr<IDXGIAdapter> legacy_adapter(adapter);

  if (!adapter && !Utils::IsWindows10RTMOrGreater()) {
    Microsoft::WRL::ComPtr<IDXGIFactory> factory;
    if (SUCCEEDED(::CreateDXGIFactory(__uuidof(IDXGIFactory),
                                      reinterpret_cast<void**>(
                                          factory.GetAddressOf()))) &&
        factory) {
      factory->EnumAdapters(0, legacy_adapter.GetAddressOf());
    }
    if (legacy_adapter) {
      driver_type = D3D_DRIVER_TYPE_UNKNOWN;
    }
  }

  const HRESULT hr = ::D3D11CreateDevice(
      legacy_adapter.Get(), driver_type, nullptr,
      D3D11_CREATE_DEVICE_BGRA_SUPPORT, feature_levels,
      static_cast<UINT>(std::size(feature_levels)), D3D11_SDK_VERSION,
      device.GetAddressOf(), nullptr, context.GetAddressOf());

  if (FAILED(hr)) {
    std::cout << "media_kit: D3D11Renderer: D3D11CreateDevice failed (hr=0x"
              << std::hex << hr << std::dec << ")" << std::endl;
    return false;
  }

  Microsoft::WRL::ComPtr<IDXGIDevice> dxgi_device;
  if (SUCCEEDED(device->QueryInterface(__uuidof(IDXGIDevice),
                                       reinterpret_cast<void**>(
                                           dxgi_device.GetAddressOf()))) &&
      dxgi_device) {
    dxgi_device->SetGPUThreadPriority(5);
  }

  const auto level = device->GetFeatureLevel();
  std::cout << "media_kit: D3D11Renderer: Direct3D Feature Level: "
            << (static_cast<unsigned>(level) >> 12) << "_"
            << ((static_cast<unsigned>(level) >> 8) & 0xfu) << std::endl;
  return true;
}

bool D3D11Renderer::CreateMailbox() {
  MailboxSwapChain* render_raw = nullptr;
  HRESULT hr = MailboxSwapChain::Create(d3d_11_device_.Get(), width_, height_,
                                         &render_raw);
  if (FAILED(hr)) {
    std::cout << "media_kit: D3D11Renderer: Render mailbox creation failed "
                 "(hr=0x"
              << std::hex << hr << std::dec << ")" << std::endl;
    return false;
  }
  render_mailbox_swap_chain_.Attach(render_raw);

  if (!cross_adapter_) {
    flutter_mailbox_swap_chain_ = render_mailbox_swap_chain_;
    return true;
  }

  DXGI_ADAPTER_DESC flutter_description = {};
  if (!flutter_adapter_ ||
      FAILED(flutter_adapter_->GetDesc(&flutter_description))) {
    return false;
  }
  auto selected_flutter_adapter =
      Utils::FindD3D11Adapter(
          Utils::D3D11AdapterId(flutter_description.AdapterLuid));
  if (!selected_flutter_adapter ||
      !CreateD3D11Device(selected_flutter_adapter.Get(), flutter_device_,
                         flutter_device_context_)) {
    return false;
  }

  MailboxSwapChain* flutter_raw = nullptr;
  hr = MailboxSwapChain::Create(flutter_device_.Get(), width_, height_,
                                &flutter_raw);
  if (FAILED(hr)) {
    std::cout << "media_kit: D3D11Renderer: Flutter mailbox creation failed "
                 "(hr=0x"
              << std::hex << hr << std::dec << ")" << std::endl;
    return false;
  }
  flutter_mailbox_swap_chain_.Attach(flutter_raw);
  std::cout << "media_kit: D3D11Renderer: Cross-adapter rendering enabled; "
               "frames are copied through system memory."
            << std::endl;
  return true;
}

bool D3D11Renderer::CreateReadbackTexture() {
  D3D11_TEXTURE2D_DESC desc = {};
  desc.Width = static_cast<UINT>(width_);
  desc.Height = static_cast<UINT>(height_);
  desc.MipLevels = 1;
  desc.ArraySize = 1;
  desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  desc.SampleDesc.Count = 1;
  desc.Usage = D3D11_USAGE_STAGING;
  desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
  return SUCCEEDED(d3d_11_device_->CreateTexture2D(
      &desc, nullptr, readback_texture_.GetAddressOf()));
}

bool D3D11Renderer::TransferFrameToFlutterAdapter() {
  if (!cross_adapter_ready_ || !readback_texture_ ||
      !render_mailbox_swap_chain_ ||
      !flutter_mailbox_swap_chain_) {
    return false;
  }

  auto* source = render_mailbox_swap_chain_->GetWriteTexture();
  if (!source) {
    return false;
  }
  d3d_11_device_context_->CopyResource(readback_texture_.Get(), source);
  d3d_11_device_context_->Flush();

  D3D11_MAPPED_SUBRESOURCE mapped = {};
  HRESULT hr = d3d_11_device_context_->Map(
      readback_texture_.Get(), 0, D3D11_MAP_READ, 0, &mapped);
  if (FAILED(hr)) {
    std::cout << "media_kit: D3D11Renderer: Cross-adapter readback failed "
                 "(hr=0x"
              << std::hex << hr << std::dec << ")" << std::endl;
    return false;
  }

  hr = flutter_mailbox_swap_chain_->UploadWriteFrame(mapped.pData,
                                                      mapped.RowPitch);
  d3d_11_device_context_->Unmap(readback_texture_.Get(), 0);
  if (FAILED(hr)) {
    std::cout << "media_kit: D3D11Renderer: Flutter adapter upload failed "
                 "(hr=0x"
              << std::hex << hr << std::dec << ")" << std::endl;
    return false;
  }
  if (!render_mailbox_swap_chain_->ProducerCommit()) {
    return false;
  }
  return flutter_mailbox_swap_chain_->ProducerCommit();
}
