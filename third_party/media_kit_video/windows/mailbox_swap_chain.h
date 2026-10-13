// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2026 Predidit.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef MAILBOX_SWAP_CHAIN_H_
#define MAILBOX_SWAP_CHAIN_H_

#include <Windows.h>
#include <d3d11.h>
#include <d3d11_4.h>
#include <dxgi.h>
#include <wrl.h>

#include <atomic>
#include <cstdint>

// Minimal IDXGISwapChain facade backed by a lock-free 4-slot mailbox with
// a last-completed-frame cache.
//
// Four BGRA8 textures are kept, each with a DXGI shared HANDLE.
// mailbox_state_ is a single atomic<uint32_t>:
//   bits [1:0] = free_slot         (0-3): producer takes this for the next frame
//   bits [3:2] = completed_slot    (0-3): most recent fence-confirmed frame;
//                                          safe Consumer fallback at any time
//   bits [5:4] = pending_or_extra  (0-3): has_pending=1 → latest submitted frame
//                                          (fence may still be in-flight);
//                                          has_pending=0 → second free slot
//   bit  [6]   = has_pending            : 1 = a new frame is waiting to be consumed
//
// 4-slot invariant (all roles are always distinct):
//   has_pending=1: write_slot_(private) | free | pending | completed  = 4 slots
//   has_pending=0: write_slot_(private) | free | extra_free | completed = 4 slots
//
// Initial value 57u = 0b0_11_10_01:
//   has_pending=0, extra_free=3, completed=2, free=1, write_slot_=0 (private)
class MailboxSwapChain final : public IDXGISwapChain {
 public:
  // Returns an AddRef'd pointer (ref count = 1). device must outlive this.
  static HRESULT Create(ID3D11Device* device,
                        int32_t width,
                        int32_t height,
                        MailboxSwapChain** out);

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid,
                                           void** ppv) override;
  ULONG STDMETHODCALLTYPE AddRef() override;
  ULONG STDMETHODCALLTYPE Release() override;

  HRESULT STDMETHODCALLTYPE SetPrivateData(REFGUID, UINT,
                                           const void*) override {
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE SetPrivateDataInterface(REFGUID,
                                                    const IUnknown*) override {
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE GetPrivateData(REFGUID, UINT*, void*) override {
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE GetParent(REFIID, void**) override {
    return E_NOTIMPL;
  }

  HRESULT STDMETHODCALLTYPE GetDevice(REFIID, void**) override {
    return E_NOTIMPL;
  }

  // Present is a no-op: mpv drives presentation via done_frame / Flush.
  HRESULT STDMETHODCALLTYPE Present(UINT, UINT) override { return S_OK; }

  // Called by the libmpv DXGI back-end each frame to obtain a render target.
  HRESULT STDMETHODCALLTYPE GetBuffer(UINT Buffer,
                                      REFIID riid,
                                      void** ppSurface) override;

  HRESULT STDMETHODCALLTYPE GetDesc(DXGI_SWAP_CHAIN_DESC* pDesc) override;

  HRESULT STDMETHODCALLTYPE SetFullscreenState(BOOL,
                                               IDXGIOutput*) override {
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE GetFullscreenState(BOOL*,
                                               IDXGIOutput**) override {
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE ResizeBuffers(UINT, UINT, UINT, DXGI_FORMAT,
                                          UINT) override {
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE ResizeTarget(const DXGI_MODE_DESC*) override {
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE GetContainingOutput(IDXGIOutput**) override {
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE GetFrameStatistics(
      DXGI_FRAME_STATISTICS*) override {
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE GetLastPresentCount(UINT*) override {
    return E_NOTIMPL;
  }

  // Called from the producer thread after the frame has been written. Signals
  // its fence and publishes write_slot_ as the new pending frame. Returns
  // false when the fence could not be signaled.
  bool ProducerCommit();

  // Called from the consumer thread (Flutter GpuSurfaceTexture callback).
  // Returns the DXGI shared HANDLE of the most recent fence-confirmed frame.
  // Implementation is a single acquire load of latest_completed_slot_ —
  // no CAS, no fence poll, no flush, no stall, no KeyedMutex.
  HANDLE ConsumerAcquire();

  // Recreates all three texture slots at the new dimensions.
  // Must only be called from the producer thread with no active consumer.
  HRESULT Resize(int32_t width, int32_t height);

  ID3D11Texture2D* GetWriteTexture() const {
    return slots_[write_slot_].texture.Get();
  }

  HRESULT UploadWriteFrame(const void* pixels, UINT row_pitch);

  // Returns the latest GPU-confirmed HANDLE without advancing mailbox state.
  // Safe to call before the consumer thread starts.
  HANDLE ReadHandleSnapshot() const {
    return slots_[latest_completed_slot_.load(std::memory_order_acquire)]
        .shared_handle;
  }

  int32_t width() const { return width_; }
  int32_t height() const { return height_; }

 private:
  MailboxSwapChain() = default;
  ~MailboxSwapChain();

  MailboxSwapChain(const MailboxSwapChain&) = delete;
  MailboxSwapChain& operator=(const MailboxSwapChain&) = delete;

  HRESULT AllocateSlots();
  void ReleaseSlots();

  struct TextureSlot {
    Microsoft::WRL::ComPtr<ID3D11Texture2D> texture;
    HANDLE shared_handle = nullptr;
    Microsoft::WRL::ComPtr<ID3D11Fence> fence;
    uint64_t fence_value = 0;
  };

  ID3D11Device* device_ = nullptr;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext4> context4_;

  int32_t width_ = 1;
  int32_t height_ = 1;

  TextureSlot slots_[4];

  // Lock-free mailbox state — see bit-field comment at top of class.
  // Initial value 57u = 0b0_11_10_01.
  std::atomic<uint32_t> mailbox_state_{57u};

  // Cache of the most recently fence-confirmed completed slot.
  // ConsumerAcquire reads this directly (one atomic load, no CAS, no fence
  // poll).  Updated by ProducerCommit after a successful non-blocking
  // pending→completed promotion.  Initialised to 2, which matches the
  // 'completed' field in mailbox_state_'s initial value 57u.
  std::atomic<int> latest_completed_slot_{2};

  int write_slot_ = 0;  // producer-private

  std::atomic<ULONG> ref_count_{1u};
};

#endif  // MAILBOX_SWAP_CHAIN_H_