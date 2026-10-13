/**
 * This file is a part of media_kit (https://github.com/media-kit/media-kit).
 * <p>
 * Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
 * All rights reserved.
 * Use of this source code is governed by MIT license that can be found in the LICENSE file.
 */
package com.alexmercerind.media_kit_video;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.Surface;

import com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper;
import java.util.HashSet;
import java.util.Locale;

import io.flutter.view.TextureRegistry;

public class VideoOutput implements TextureRegistry.SurfaceProducer.Callback {
    private static final String TAG = "VideoOutput";
    private static final HashSet<Long> deletedGlobalObjectRefs = new HashSet<>();
    private static final Handler handler = new Handler(Looper.getMainLooper());


    private long id = 0;
    private long wid = 0;

    private final TextureUpdateCallback textureUpdateCallback;

    private final boolean enableSurfaceProducer;
    private final TextureRegistry.SurfaceProducer surfaceProducer;
    private final TextureRegistry.SurfaceTextureEntry surfaceTextureEntry;
    private Surface surfaceTextureSurface;
    private int surfaceTextureWidth = 1;
    private int surfaceTextureHeight = 1;
    private boolean surfaceTextureNotified = false;

    private final Object lock = new Object();

    VideoOutput(TextureRegistry textureRegistryReference, boolean enableSurfaceProducer, TextureUpdateCallback textureUpdateCallback) {
        this.textureUpdateCallback = textureUpdateCallback;
        this.enableSurfaceProducer = enableSurfaceProducer;

        if (enableSurfaceProducer) {
            Log.i(TAG, "Android video output rendering path: SurfaceProducer");
            surfaceProducer = textureRegistryReference.createSurfaceProducer();
            surfaceProducer.setCallback(this);
            surfaceTextureEntry = null;
        } else {
            Log.i(TAG, "Android video output rendering path: SurfaceTexture");
            surfaceProducer = null;
            surfaceTextureEntry = textureRegistryReference.createSurfaceTexture();
            id = surfaceTextureEntry.id();
            createSurfaceTextureSurface();
        }
    }

    public void dispose() {
        synchronized (lock) {
            if (enableSurfaceProducer) {
                try {
                    surfaceProducer.getSurface().release();
                } catch (Throwable e) {
                    Log.e(TAG, "dispose", e);
                }
                try {
                    surfaceProducer.release();
                } catch (Throwable e) {
                    Log.e(TAG, "dispose", e);
                }
                onSurfaceCleanup();
            } else {
                onSurfaceTextureCleanup();
                try {
                    surfaceTextureEntry.release();
                } catch (Throwable e) {
                    Log.e(TAG, "dispose", e);
                }
            }
        }
    }

    public void setSurfaceSize(int width, int height) {
        setSurfaceSize(width, height, false);
    }

    private void setSurfaceSize(int width, int height, boolean force) {
        synchronized (lock) {
            if (enableSurfaceProducer) {
                try {
                    if (!force && surfaceProducer.getWidth() == width && surfaceProducer.getHeight() == height) {
                        return;
                    }
                    surfaceProducer.setSize(width, height);
                    onSurfaceAvailable();
                } catch (Throwable e) {
                    Log.e(TAG, "setSurfaceSize", e);
                }
            } else {
                try {
                    if (!force && surfaceTextureNotified && surfaceTextureWidth == width && surfaceTextureHeight == height) {
                        return;
                    }
                    surfaceTextureEntry.surfaceTexture().setDefaultBufferSize(width, height);
                    surfaceTextureWidth = width;
                    surfaceTextureHeight = height;
                    surfaceTextureNotified = true;
                    createSurfaceTextureSurface();
                    textureUpdateCallback.onTextureUpdate(id, wid, surfaceTextureWidth, surfaceTextureHeight);
                } catch (Throwable e) {
                    Log.e(TAG, "setSurfaceSize", e);
                }
            }
        }
    }

    @Override
    public void onSurfaceAvailable() {
        synchronized (lock) {
            Log.i(TAG, "onSurfaceAvailable");
            id = surfaceProducer.id();
            wid = newGlobalObjectRef(surfaceProducer.getSurface());
            textureUpdateCallback.onTextureUpdate(id, wid, surfaceProducer.getWidth(), surfaceProducer.getHeight());
        }
    }

    @Override
    public void onSurfaceCleanup() {
        synchronized (lock) {
            Log.i(TAG, "onSurfaceCleanup");
            textureUpdateCallback.onTextureUpdate(id, 0, surfaceProducer.getWidth(), surfaceProducer.getHeight());
            if (wid != 0) {
                final long widReference = wid;
                handler.postDelayed(() -> deleteGlobalObjectRef(widReference), 5000);
            }
        }
    }

    private void createSurfaceTextureSurface() {
        // The SurfaceTexture fallback is only effective with Android's Skia backend.
        if (surfaceTextureSurface != null) {
            return;
        }
        surfaceTextureSurface = new Surface(surfaceTextureEntry.surfaceTexture());
        wid = newGlobalObjectRef(surfaceTextureSurface);
    }

    private void onSurfaceTextureCleanup() {
        Log.i(TAG, "onSurfaceTextureCleanup");
        textureUpdateCallback.onTextureUpdate(id, 0, surfaceTextureWidth, surfaceTextureHeight);
        if (surfaceTextureSurface != null) {
            try {
                surfaceTextureSurface.release();
            } catch (Throwable e) {
                Log.e(TAG, "onSurfaceTextureCleanup", e);
            }
            surfaceTextureSurface = null;
        }
        if (wid != 0) {
            final long widReference = wid;
            wid = 0;
            handler.postDelayed(() -> deleteGlobalObjectRef(widReference), 5000);
        }
    }

    private static long newGlobalObjectRef(Object object) {
        Log.i(TAG, String.format(Locale.ENGLISH, "newGlobalRef: object = %s", object));
        try {
            return MediaKitAndroidHelper.newGlobalObjectRef(object);
        } catch (Throwable e) {
            Log.e(TAG, "newGlobalRef", e);
            return 0;
        }
    }

    private static void deleteGlobalObjectRef(long ref) {
        if (deletedGlobalObjectRefs.contains(ref)) {
            Log.i(TAG, String.format(Locale.ENGLISH, "deleteGlobalObjectRef: ref = %d ALREADY DELETED", ref));
            return;
        }
        if (deletedGlobalObjectRefs.size() > 100) {
            deletedGlobalObjectRefs.clear();
        }
        deletedGlobalObjectRefs.add(ref);
        Log.i(TAG, String.format(Locale.ENGLISH, "deleteGlobalObjectRef: ref = %d", ref));
        try {
            MediaKitAndroidHelper.deleteGlobalObjectRef(ref);
        } catch (Throwable e) {
            Log.e(TAG, "deleteGlobalObjectRef", e);
        }
    }
}
