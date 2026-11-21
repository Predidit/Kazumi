/**
 * This file is a part of media_kit (https://github.com/media-kit/media-kit).
 *
 * Copyright © 2025 & onwards, Bao Han <erbws@foxmail.com>.
 * All rights reserved.
 * Use of this source code is governed by MIT license that can be found in the LICENSE file.
 */

import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import { TextureRegistry } from '@ohos/flutter_ohos';
import { VideoOutput } from './VideoOutput';
import { SizeData } from './Utils';

const TAG = "VideoOutputManager";

export class VideoOutputManager {
  private videoOutputs: Map<number, VideoOutput> = new Map();
  private textureRegistryReference: TextureRegistry;

  constructor(textureRegistryReference: TextureRegistry) {
    this.textureRegistryReference = textureRegistryReference;
  }

  create(handle: number): SizeData {
    Log.i(TAG, `com.alexmercerind.media_kit_video.VideoOutputManager.create: ${handle}`);

    if (!this.videoOutputs.has(handle)) {
      const textureId = this.textureRegistryReference.getTextureId();
      const videoOutput =
        new VideoOutput(this.textureRegistryReference, this.textureRegistryReference.registerTexture(textureId));
      this.videoOutputs.set(handle, videoOutput);
    }

    return this.videoOutputs.get(handle)!.getSizeData(handle);
  }

  dispose(handle: number): void {
    Log.i(TAG, `com.alexmercerind.media_kit_video.VideoOutputManager.dispose: ${handle}`);

    if (this.videoOutputs.has(handle)) {
      this.videoOutputs.get(handle)?.dispose();
      this.videoOutputs.delete(handle);
    }
  }

  disposeAll(): void {
    this.videoOutputs.forEach((videoOutput: VideoOutput) => {
      videoOutput.dispose();
    });
    this.videoOutputs.clear();
  }

  setSurfaceSize(handle: number, width: number, height: number): void {
    Log.i(TAG, `com.alexmercerind.media_kit_video.VideoOutputManager.setSurfaceSize: ${handle} ${width} ${height}`);

    if (this.videoOutputs.has(handle)) {
      this.videoOutputs.get(handle)?.setSurfaceSize(width, height);
    }
  }
}
