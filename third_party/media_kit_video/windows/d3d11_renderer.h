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
#include <string>

#include "mailbox_swap_chain.h"
#include "utils.h"

// On one adapter, the render mailbox is also Flutter's presentation mailbox,
// preserving the existing zero-copy shared-handle path. When mpv renders on a
// different adapter, the renderer reads back into system memory and uploads
// into a separate mailbox created on Flutter's adapter; DXGI shared handles
// never cross adapter boundaries.
class D3D11Renderer {
 public:
  int32_t width() const { return width_; }
  int32_t height() const { return height_; }

  // Raw device pointer used by VideoOutput to populate mpv_dxgi_init_params.
  ID3D11Device* device() const { return d3d_11_device_.Get(); }

  // IDXGISwapChain* facade backed by the selected rendering adapter.
  // Passed to mpv as mpv_dxgi_init_params::swapchain (void*).
  IDXGISwapChain* swap_chain() const { return render_mailbox_swap_chain_.Get(); }

  // |flutter_adapter| is FlutterDesktopViewGetGraphicsAdapter's adapter.
  // |selected_adapter_id| is a DXGI LUID, or "auto" to retain the Flutter
  // adapter. An explicit different adapter uses a staged CPU transfer to the
  // Flutter adapter's presentation mailbox.
  explicit D3D11Renderer(int32_t width, int32_t height,
                         IDXGIAdapter* flutter_adapter = nullptr,
                         std::string selected_adapter_id = "auto");
  ~D3D11Renderer();

  // Recreates the three mailbox slots at the new dimensions.
  // Must be called from the producer thread only.
  void SetSize(int32_t width, int32_t height);

  // Called from the producer thread after mpv_render_context_render. Returns
  // false if the rendered frame could not be safely published to Flutter.
  bool ProducerCommit();

  // Called from the consumer thread (Flutter GpuSurfaceTexture callback).
  // Returns the DXGI shared HANDLE of the most recent fence-confirmed frame
  // via a single atomic load — no fence poll, no flush, no stall.
  HANDLE ConsumerAcquire();

  // Returns the DXGI shared HANDLE for the current read slot without
  // advancing mailbox state.  Used once during texture registration before
  // the consumer thread starts.
  HANDLE ReadHandleSnapshot() const;

 private:
  bool CreateD3D11Device(IDXGIAdapter* adapter,
                         Microsoft::WRL::ComPtr<ID3D11Device>& device,
                         Microsoft::WRL::ComPtr<ID3D11DeviceContext>& context);
  bool CreateMailbox();
  bool CreateReadbackTexture();
  bool TransferFrameToFlutterAdapter();

  int32_t width_ = 1;
  int32_t height_ = 1;
  bool cross_adapter_ = false;
  bool cross_adapter_ready_ = false;

  Microsoft::WRL::ComPtr<ID3D11Device> d3d_11_device_;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext> d3d_11_device_context_;
  Microsoft::WRL::ComPtr<IDXGIAdapter> flutter_adapter_;
  Microsoft::WRL::ComPtr<ID3D11Device> flutter_device_;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext> flutter_device_context_;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> readback_texture_;

  Microsoft::WRL::ComPtr<MailboxSwapChain> render_mailbox_swap_chain_;
  Microsoft::WRL::ComPtr<MailboxSwapChain> flutter_mailbox_swap_chain_;

  static int instance_count_;
};

#endif  // D3D11_RENDERER_H_