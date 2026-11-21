/**
 * This file is a part of media_kit (https://github.com/media-kit/media-kit).
 *
 * Copyright © 2025 & onwards, Bao Han <erbws@foxmail.com>.
 * All rights reserved.
 * Use of this source code is governed by MIT license that can be found in the LICENSE file.
 */

import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import { SurfaceTextureEntry } from '@ohos/flutter_ohos';
import { TextureRegistry } from '@ohos/flutter_ohos';
import { SizeData } from './Utils';

const TAG = "VideoOutput";

export class VideoOutput {
  private id: number = 0;
  private wid: number = 0;
  private w: number = 0;
  private h: number = 0;
  private textureRegistry: TextureRegistry;
  private surfaceProducer: SurfaceTextureEntry;
  private disposed: boolean = false;

  constructor(textureRegistry: TextureRegistry, surfaceProducer: SurfaceTextureEntry) {
    this.surfaceProducer = surfaceProducer;
    this.textureRegistry = textureRegistry;
    this.id = this.surfaceProducer.getTextureId();
    this.wid = this.surfaceProducer.getSurfaceId();
    this.setSurfaceSize(1, 1, true);
  }

  dispose(): void {
    if (this.disposed) {
      return;
    }

    try {
      this.textureRegistry.unregisterTexture(this.id);
      this.disposed = true;
      this.id = 0;
      this.wid = 0;
      this.w = 0;
      this.h = 0;
    } catch (e) {
      Log.e(TAG, `dispose: ${e}`);
    }
  }

  setSurfaceSize(width: number, height: number, force: boolean = false): void {
    try {
      if (!force && this.w == width && this.h == height) {
        return;
      }

      this.w = width;
      this.h = height;
      this.textureRegistry.setTextureBufferSize(this.id, width, height);
    } catch (e) {
      Log.e(TAG, `setSurfaceSize error: ${e}`);
    }
  }

  getSizeData(handle: number): SizeData {
    return {
      handle: handle,
      id: this.id,
      wid: this.wid,
      rect: {
        left: 0,
        top: 0,
        width: this.w,
        height: this.h,
      },
    }
  }
}
