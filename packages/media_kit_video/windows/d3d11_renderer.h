// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © Predidit.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef D3D11_RENDERER_H_
#define D3D11_RENDERER_H_

#include <Windows.h>
#include <d3d11.h>
#include <dxgi.h>
#include <dxgi1_2.h>
#include <wrl.h>

#include <cstdint>
#include <iostream>
#include <memory>

#include "mailbox_swap_chain.h"
#include "utils.h"

// D3D11Renderer creates a D3D11 device and owns a MailboxSwapChain that
// owns the shared texture slots between the libmpv rendering
// thread (producer) and Flutter's render thread (consumer).
//
// The device is handed to mpv through mpv_d3d11_init_params.  For every frame
// the plugin passes render_target() to mpv_render_context_render() as
// mpv_d3d11_fbo::tex and mpv submits its GPU work into it.  The plugin then
// calls ProducerCommit() to hand a completed frame to Flutter's raster thread.
class D3D11Renderer {
 public:
  int32_t width() const { return width_; }
  int32_t height() const { return height_; }

  // Raw device pointer used by VideoOutput to populate mpv_d3d11_init_params.
  ID3D11Device* device() const { return d3d_11_device_.Get(); }

  // Mailbox slot the next frame must be rendered into, passed to mpv as
  // mpv_d3d11_fbo::tex.  Borrowed pointer, valid until the next
  // ProducerCommit() or SetSize().  Producer thread only.
  ID3D11Texture2D* render_target() const {
    return render_texture_ ? render_texture_.Get()
                           : mailbox_swap_chain_->ProducerTexture();
  }

  explicit D3D11Renderer(int32_t width, int32_t height,
                         IDXGIAdapter* flutter_adapter = nullptr,
                         IDXGIAdapter* render_adapter = nullptr,
                         bool force_event_queries = false);
  ~D3D11Renderer();

  // Recreates the mailbox slots at the new dimensions.
  // Must be called from the producer thread only.
  bool SetSize(int32_t width, int32_t height);

  // Called from the producer thread (mpv thread pool) after
  // mpv_render_context_render returns. Publish this GPU-complete frame.
  bool ProducerCommit();

  // Each registered Flutter texture keeps its own mailbox alive through resize.
  std::shared_ptr<MailboxSwapChain> mailbox() const { return mailbox_swap_chain_; }

  // Used by the standalone pixel readback probe. The Flutter callback takes
  // its own stable reference to the published mailbox.
  HANDLE ConsumerAcquire();

 private:
  static bool CreateD3D11Device(
      IDXGIAdapter* adapter,
      Microsoft::WRL::ComPtr<ID3D11Device>& device,
      Microsoft::WRL::ComPtr<ID3D11DeviceContext>& context);
  bool CreateSurfaces(int32_t width, int32_t height);

  const bool force_event_queries_;
  int32_t width_ = 1;
  int32_t height_ = 1;

  Microsoft::WRL::ComPtr<ID3D11Device> d3d_11_device_;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext> d3d_11_device_context_;

  Microsoft::WRL::ComPtr<ID3D11Device> flutter_device_;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext> flutter_context_;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> render_texture_;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> readback_texture_;
  std::shared_ptr<MailboxSwapChain> mailbox_swap_chain_;

  static int instance_count_;
};

#endif  // D3D11_RENDERER_H_