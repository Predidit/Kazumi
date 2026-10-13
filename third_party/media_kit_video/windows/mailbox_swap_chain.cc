// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2026 Predidit.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "mailbox_swap_chain.h"

#include <iostream>

MailboxSwapChain::~MailboxSwapChain() {
  ReleaseSlots();
}

HRESULT MailboxSwapChain::Create(ID3D11Device* device,
                                  int32_t width,
                                  int32_t height,
                                  MailboxSwapChain** out) {
  if (!device || !out) return E_INVALIDARG;

  auto* p = new (std::nothrow) MailboxSwapChain();
  if (!p) return E_OUTOFMEMORY;

  p->device_ = device;
  p->width_ = (width > 0) ? width : 1;
  p->height_ = (height > 0) ? height : 1;

  {
    Microsoft::WRL::ComPtr<ID3D11DeviceContext> ctx;
    device->GetImmediateContext(&ctx);
    const HRESULT hr2 = ctx.As(&p->context4_);
    if (FAILED(hr2)) {
      std::cout << "media_kit: MailboxSwapChain: ID3D11DeviceContext4 not available "
                   "(hr=0x" << std::hex << hr2 << std::dec << ")" << std::endl;
      delete p;
      return hr2;
    }
  }

  const HRESULT hr = p->AllocateSlots();
  if (FAILED(hr)) {
    delete p;
    return hr;
  }

  *out = p;
  return S_OK;
}

HRESULT STDMETHODCALLTYPE MailboxSwapChain::QueryInterface(REFIID riid,
                                                            void** ppv) {
  if (!ppv) return E_POINTER;

  if (riid == __uuidof(IUnknown) || riid == __uuidof(IDXGIObject) ||
      riid == __uuidof(IDXGIDeviceSubObject) ||
      riid == __uuidof(IDXGISwapChain)) {
    *ppv = static_cast<IDXGISwapChain*>(this);
    AddRef();
    return S_OK;
  }

  *ppv = nullptr;
  return E_NOINTERFACE;
}

ULONG STDMETHODCALLTYPE MailboxSwapChain::AddRef() {
  return ref_count_.fetch_add(1u, std::memory_order_relaxed) + 1u;
}

ULONG STDMETHODCALLTYPE MailboxSwapChain::Release() {
  const ULONG prev = ref_count_.fetch_sub(1u, std::memory_order_acq_rel);
  if (prev == 1u) delete this;
  return prev - 1u;
}

HRESULT STDMETHODCALLTYPE MailboxSwapChain::GetBuffer(UINT Buffer,
                                                       REFIID riid,
                                                       void** ppSurface) {
  if (!ppSurface) return E_POINTER;
  if (Buffer != 0) return DXGI_ERROR_INVALID_CALL;

  if (riid != __uuidof(ID3D11Texture2D) &&
      riid != __uuidof(ID3D11Resource)) {
    return E_NOINTERFACE;
  }

  ID3D11Texture2D* tex = slots_[write_slot_].texture.Get();
  if (!tex) return E_FAIL;

  tex->AddRef();
  *ppSurface = tex;
  return S_OK;
}

HRESULT STDMETHODCALLTYPE
MailboxSwapChain::GetDesc(DXGI_SWAP_CHAIN_DESC* pDesc) {
  if (!pDesc) return E_POINTER;
  *pDesc = {};
  pDesc->BufferDesc.Width = static_cast<UINT>(width_);
  pDesc->BufferDesc.Height = static_cast<UINT>(height_);
  pDesc->BufferDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  pDesc->BufferCount = 1;
  pDesc->SampleDesc.Count = 1;
  pDesc->BufferUsage =
      DXGI_USAGE_RENDER_TARGET_OUTPUT | DXGI_USAGE_SHADER_INPUT;
  pDesc->Windowed = TRUE;
  pDesc->SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
  return S_OK;
}

bool MailboxSwapChain::ProducerCommit() {
  auto& ws = slots_[write_slot_];
  const auto signal_value = ws.fence_value + 1;
  const HRESULT signal_result = context4_->Signal(ws.fence.Get(), signal_value);
  if (FAILED(signal_result)) {
    std::cout << "media_kit: MailboxSwapChain: Fence signal failed (hr=0x"
              << std::hex << signal_result << std::dec << ")" << std::endl;
    return false;
  }
  ws.fence_value = signal_value;

  // This runs one full render-cycle after the *previous* Signal was enqueued.
  // By then the D3D11 runtime has had ample opportunity to submit the prior
  // command buffer to the GPU, so GetCompletedValue() is far more likely to
  // have advanced than it would be inside ConsumerAcquire (which can be
  // called microseconds after the Signal).  The check is non-blocking: if
  // the fence isn't done yet, we simply leave latest_completed_slot_ as-is
  // and try again next frame.
  //
  // On success we do a combined promotion CAS on mailbox_state_:
  //   (has_pending=1, pending=P, completed=C, free=F)
  //   → (has_pending=0, extra=C, completed=P, free=F)
  // then store latest_completed_slot_ = P with release ordering so that
  // ConsumerAcquire's acquire load cannot observe P before mailbox_state_
  // reflects P in the 'completed' role (i.e., protected from the producer).
  {
    uint32_t snap = mailbox_state_.load(std::memory_order_acquire);
    if (snap & (1u << 6)) {  // has_pending
      const int pend = static_cast<int>((snap >> 4) & 0x3u);
      const int comp = static_cast<int>((snap >> 2) & 0x3u);
      const int fr   = static_cast<int>( snap        & 0x3u);
      if (slots_[pend].fence->GetCompletedValue() >=
          slots_[pend].fence_value) {
        const uint32_t snap_desired =
            (static_cast<uint32_t>(comp) << 4) |
            (static_cast<uint32_t>(pend) << 2) |
            static_cast<uint32_t>(fr);
        if (mailbox_state_.compare_exchange_strong(
                snap, snap_desired,
                std::memory_order_acq_rel,
                std::memory_order_relaxed)) {
          latest_completed_slot_.store(pend, std::memory_order_release);
        }
        // CAS failure means no concurrent writer exists (ProducerCommit is
        // called from a single producer thread); the only way it can fail is
        // if mailbox_state_ was already has_pending=0, which means nothing
        // to promote.  Either way, leave latest_completed_slot_ untouched.
      }
    }
  }

  // Desired state:
  //   has_pending = 1
  //   pending     = write_slot_          (new latest frame)
  //   completed   = old completed_slot   (unchanged)
  //   free        = old pending_or_extra (recycled: was old pending or extra_free)
  //
  // new write_slot_ (producer-private) = old free_slot.
  uint32_t expected = mailbox_state_.load(std::memory_order_relaxed);
  while (true) {
    const int old_free      = static_cast<int>( expected        & 0x3u);
    const int old_completed = static_cast<int>((expected >> 2)  & 0x3u);
    const int old_poe       = static_cast<int>((expected >> 4)  & 0x3u);
    const uint32_t desired =
        (1u << 6) |
        (static_cast<uint32_t>(write_slot_)   << 4) |
        (static_cast<uint32_t>(old_completed) << 2) |
        static_cast<uint32_t>(old_poe);
    if (mailbox_state_.compare_exchange_weak(
            expected, desired,
            std::memory_order_release,
            std::memory_order_relaxed)) {
      write_slot_ = old_free;
      break;
    }
  }
  return true;
}

HANDLE MailboxSwapChain::ConsumerAcquire() {
  // Always return the most recently fence-confirmed frame.
  // Advancement is handled exclusively by ProducerCommit (called one full
  // render-cycle after each Signal, where fence completion is far more
  // likely).
  return slots_[latest_completed_slot_.load(std::memory_order_acquire)]
      .shared_handle;
}

HRESULT MailboxSwapChain::UploadWriteFrame(const void* pixels, UINT row_pitch) {
  if (!pixels || row_pitch < static_cast<UINT>(width_) * 4) {
    return E_INVALIDARG;
  }
  auto* texture = slots_[write_slot_].texture.Get();
  if (!texture) {
    return E_FAIL;
  }
  context4_->UpdateSubresource(texture, 0, nullptr, pixels, row_pitch, 0);
  return device_->GetDeviceRemovedReason();
}

HRESULT MailboxSwapChain::Resize(int32_t width, int32_t height) {
  ReleaseSlots();
  width_ = (width > 0) ? width : 1;
  height_ = (height > 0) ? height : 1;
  mailbox_state_.store(57u, std::memory_order_relaxed);
  latest_completed_slot_.store(2, std::memory_order_relaxed);
  write_slot_ = 0;
  return AllocateSlots();
}

HRESULT MailboxSwapChain::AllocateSlots() {
  Microsoft::WRL::ComPtr<ID3D11Device5> device5;
  {
    const HRESULT hr =
        device_->QueryInterface(__uuidof(ID3D11Device5), (void**)&device5);
    if (FAILED(hr)) {
      std::cout << "media_kit: MailboxSwapChain: ID3D11Device5 not available "
                   "(hr=0x" << std::hex << hr << std::dec << ")" << std::endl;
      return hr;
    }
  }

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

    hr = device5->CreateFence(0, D3D11_FENCE_FLAG_NONE,
                              __uuidof(ID3D11Fence),
                              (void**)&slots_[i].fence);
    if (FAILED(hr)) {
      std::cout << "media_kit: MailboxSwapChain: CreateFence slot " << i
                << " failed (hr=0x" << std::hex << hr << std::dec << ")"
                << std::endl;
      return hr;
    }
    slots_[i].fence_value = 0;
  }

  return S_OK;
}

void MailboxSwapChain::ReleaseSlots() {
  for (auto& slot : slots_) {
    slot.texture.Reset();
    slot.shared_handle = nullptr;
    slot.fence.Reset();
    slot.fence_value = 0;
  }
}