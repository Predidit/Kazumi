// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2026 Predidit.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "mailbox_swap_chain.h"

#include <iostream>
#include <new>

MailboxSwapChain::~MailboxSwapChain() {
  ReleaseSlots();
}

HRESULT MailboxSwapChain::Create(ID3D11Device* device,
                                  int32_t width,
                                  int32_t height,
                                  std::unique_ptr<MailboxSwapChain>* out,
                                  bool force_event_queries) {
  if (!device || !out) return E_INVALIDARG;

  std::unique_ptr<MailboxSwapChain> p(new (std::nothrow) MailboxSwapChain());
  if (!p) return E_OUTOFMEMORY;

  p->device_ = device;
  p->width_ = (width > 0) ? width : 1;
  p->height_ = (height > 0) ? height : 1;

  device->GetImmediateContext(&p->context_);
  if (!p->context_) return E_FAIL;
  if (!force_event_queries) p->context_.As(&p->context4_);

  const HRESULT hr = p->AllocateSlots();
  if (FAILED(hr)) {
    return hr;
  }

  *out = std::move(p);
  return S_OK;
}

bool MailboxSwapChain::ProducerCommit() {
  auto& slot = slots_[write_slot_];
  // A paused player may never submit another frame. Wait on this worker and
  // signal Flutter only when this exact slot is safe to import.
  constexpr DWORD timeout_ms = 1000;
  const auto deadline = GetTickCount64() + timeout_ms;
  if (context4_) {
    const auto value = ++slot.fence_value;
    if (FAILED(context4_->Signal(slot.fence.Get(), value))) return false;
    context_->Flush();
    if (slot.fence->GetCompletedValue() < value) {
      if (FAILED(slot.fence->SetEventOnCompletion(value, completion_event_))) return false;
      while (slot.fence->GetCompletedValue() < value) {
        const auto now = GetTickCount64();
        if (now >= deadline || WaitForSingleObject(completion_event_,
              static_cast<DWORD>(deadline - now)) != WAIT_OBJECT_0) return false;
      }
    }
    if (slot.fence->GetCompletedValue() == UINT64_MAX) return false;
  } else {
    context_->End(slot.completion_event.Get());
    context_->Flush();
    for (;;) {
      BOOL done = FALSE;
      const HRESULT hr = context_->GetData(slot.completion_event.Get(), &done,
                                          sizeof(done), 0);
      if (hr == S_OK && done) break;
      if (FAILED(hr) || GetTickCount64() >= deadline) return false;
      Sleep(1);
    }
  }
  {
    std::lock_guard<std::mutex> lock(slots_mutex_);
    latest_completed_slot_ = write_slot_;
    do {
      write_slot_ = (write_slot_ + 1) % 4;
    } while (write_slot_ == latest_completed_slot_ ||
             write_slot_ == displayed_slot_ || write_slot_ == previous_slot_);
  }
  return true;
}

HANDLE MailboxSwapChain::ConsumerAcquire() {
  std::lock_guard<std::mutex> lock(slots_mutex_);
  if (latest_completed_slot_ < 0) return nullptr;
  if (latest_completed_slot_ != displayed_slot_) {
    previous_slot_ = displayed_slot_;
    displayed_slot_ = latest_completed_slot_;
  }
  return slots_[displayed_slot_].shared_handle;
}

void MailboxSwapChain::ConsumerReleasePrevious() {
  std::lock_guard<std::mutex> lock(slots_mutex_);
  previous_slot_ = -1;
}

HRESULT MailboxSwapChain::AllocateSlots() {
  D3D11_TEXTURE2D_DESC desc = {};
  desc.Width = static_cast<UINT>(width_);
  desc.Height = static_cast<UINT>(height_);
  desc.MipLevels = 1;
  desc.ArraySize = 1;
  desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  desc.SampleDesc.Count = 1;
  desc.SampleDesc.Quality = 0;
  desc.Usage = D3D11_USAGE_DEFAULT;
  desc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
  desc.CPUAccessFlags = 0;
  desc.MiscFlags = D3D11_RESOURCE_MISC_SHARED;

  for (int i = 0; i < 4; ++i) {
    HRESULT hr = device_->CreateTexture2D(&desc, nullptr, &slots_[i].texture);
    if (FAILED(hr)) {
      std::cout << "media_kit: MailboxSwapChain: CreateTexture2D slot " << i
                << " failed (hr=0x" << std::hex << hr << std::dec << ")"
                << std::endl;
      return hr;
    }

    Microsoft::WRL::ComPtr<IDXGIResource> resource;
    hr = slots_[i].texture.As(&resource);
    if (FAILED(hr)) {
      std::cout << "media_kit: MailboxSwapChain: As<IDXGIResource> slot " << i
                << " failed (hr=0x" << std::hex << hr << std::dec << ")"
                << std::endl;
      return hr;
    }

    hr = resource->GetSharedHandle(&slots_[i].shared_handle);
    if (FAILED(hr)) {
      std::cout << "media_kit: MailboxSwapChain: GetSharedHandle slot " << i
                << " failed (hr=0x" << std::hex << hr << std::dec << ")"
                << std::endl;
      return hr;
    }

  }

  Microsoft::WRL::ComPtr<ID3D11Device5> fence_device;
  if (context4_ && SUCCEEDED(device_.As(&fence_device))) {
    for (auto& slot : slots_) {
      const HRESULT hr = fence_device->CreateFence(
          0, D3D11_FENCE_FLAG_NONE, IID_PPV_ARGS(slot.fence.GetAddressOf()));
      if (FAILED(hr)) {
        context4_.Reset();
        break;
      }
    }
    if (context4_) {
      completion_event_ = CreateEventW(nullptr, FALSE, FALSE, nullptr);
      if (completion_event_) return S_OK;
      context4_.Reset();
    }
  } else {
    context4_.Reset();
  }

  // A D3D11-capable driver need not expose the newer fence interfaces. GPU
  // event queries preserve the same non-blocking read contract.
  std::cout << "media_kit: MailboxSwapChain: using D3D11 event queries" << std::endl;
  const D3D11_QUERY_DESC query = {D3D11_QUERY_EVENT, 0};
  for (auto& slot : slots_) {
    slot.fence.Reset();
    const HRESULT hr = device_->CreateQuery(&query, slot.completion_event.GetAddressOf());
    if (FAILED(hr)) return hr;
  }

  return S_OK;
}

void MailboxSwapChain::ReleaseSlots() {
  if (completion_event_) CloseHandle(completion_event_);
  completion_event_ = nullptr;
  for (auto& slot : slots_) {
    slot.texture.Reset();
    slot.shared_handle = nullptr;
    slot.fence.Reset();
    slot.completion_event.Reset();
    slot.fence_value = 0;
  }
}