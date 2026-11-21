/**
 * This file is a part of media_kit (https://github.com/media-kit/media-kit).
 *
 * Copyright © 2025 & onwards, Bao Han <erbws@foxmail.com>.
 * All rights reserved.
 * Use of this source code is governed by MIT license that can be found in the LICENSE file.
 */

import deviceInfo from '@ohos.deviceInfo';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

export class Utils {
  static isEmulator(): boolean {
    if (deviceInfo.productModel == "emulator") {
      return true;
    } else {
      return false;
    }
  }

  static enterFullScreen(context: common.UIAbilityContext): void {
    window.getLastWindow(context).then((lastWindow) => {
      if (deviceInfo.deviceType == '2in1') {
        lastWindow.maximize();
        return;
      }
      lastWindow.enableLandscapeMultiWindow();
      lastWindow.setPreferredOrientation(window.Orientation.USER_ROTATION_LANDSCAPE);
      lastWindow.setWindowSystemBarEnable([]);
    })
  }

  static exitFullScreen(context: common.UIAbilityContext): void {
    window.getLastWindow(context).then((lastWindow) => {
      if (deviceInfo.deviceType == '2in1') {
        lastWindow.recover();
        return;
      }
      lastWindow.disableLandscapeMultiWindow();
      if (deviceInfo.deviceType == 'phone') {
        lastWindow.setPreferredOrientation(window.Orientation.USER_ROTATION_PORTRAIT);
      }
      lastWindow.setWindowSystemBarEnable(['status']);
    })
  }
}

export interface Rect {
  left: number,
  top: number,
  width: number,
  height: number,
}

export interface SizeData {
  handle: number,
  id: number,
  wid: number,
  rect: Rect,
}