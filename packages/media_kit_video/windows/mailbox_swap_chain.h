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

#include <mutex>
#include <cstdint>
#include <memory>

// Four shared render targets. Publish a completed frame from the producer
// worker, including the first redraw after a paused fullscreen resize.
class MailboxSwapChain final {
 public:
  // device must outlive the returned mailbox.
  static HRESULT Create(ID3D11Device* device,
                        int32_t width,
                        int32_t height,
                        std::unique_ptr<MailboxSwapChain>* out,
                        bool force_event_queries = false);

  ~MailboxSwapChain();

  // Render target of the frame being produced, passed to libmpv as
  // mpv_d3d11_fbo::tex.  Borrowed pointer, valid until the next
  // ProducerCommit() or Resize().  Producer thread only.
  ID3D11Texture2D* ProducerTexture() const {
    return slots_[write_slot_].texture.Get();
  }

  // Called from the producer thread after mpv_render_context_render returns.
  bool ProducerCommit();

  // Pin the displayed slot until Flutter binds its replacement. The release
  // callback drops the prior pin only after ANGLE has imported the new image.
  HANDLE ConsumerAcquire();
  void ConsumerReleasePrevious();

  int32_t width() const { return width_; }
  int32_t height() const { return height_; }

 private:
  MailboxSwapChain() = default;

  MailboxSwapChain(const MailboxSwapChain&) = delete;
  MailboxSwapChain& operator=(const MailboxSwapChain&) = delete;

  HRESULT AllocateSlots();
  void ReleaseSlots();

  struct TextureSlot {
    Microsoft::WRL::ComPtr<ID3D11Texture2D> texture;
    HANDLE shared_handle = nullptr;
    Microsoft::WRL::ComPtr<ID3D11Fence> fence;
    Microsoft::WRL::ComPtr<ID3D11Query> completion_event;
    uint64_t fence_value = 0;
  };

  Microsoft::WRL::ComPtr<ID3D11Device> device_;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext> context_;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext4> context4_;

  int32_t width_ = 1;
  int32_t height_ = 1;

  TextureSlot slots_[4];

  std::mutex slots_mutex_;
  int latest_completed_slot_ = -1;
  int displayed_slot_ = -1;
  int previous_slot_ = -1;
  HANDLE completion_event_ = nullptr;
  int write_slot_ = 0;  // producer-private
};

#endif  // MAILBOX_SWAP_CHAIN_H_