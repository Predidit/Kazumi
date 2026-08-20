package com.example.kazumi

import android.app.PendingIntent
import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.app.RemoteAction
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Bundle
import android.os.StatFs
import android.net.Uri
import android.app.PictureInPictureParams
import android.graphics.drawable.Icon
import android.util.Rational
import android.view.View
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.predidit.kazumi/intent"
    private val STORAGE_CHANNEL = "com.predidit.kazumi/storage"
    private val PIP_CHANNEL = "com.predidit.kazumi/pip"
    private var intentChannel: MethodChannel? = null
    private var pipChannel: MethodChannel? = null

    private var pipIsPlaying = false
    private var pipDanmakuEnabled = false
    private var pipActionReceiverRegistered = false
    private var autoEnterPipOnHomeGesture = false
    private var pipInPlayerPage = false
    private var pipAspectWidth = 16
    private var pipAspectHeight = 9
    private var pipSourceRect: Rect? = null
    private var inPipMode = false
    private var androidFullscreen = false
    private var originalWindowBackground: Drawable? = null
    private var windowBackgroundOverridden = false

    private val actionPipPlayPause = "com.predidit.kazumi.pip.PLAY_PAUSE"
    private val actionPipForward = "com.predidit.kazumi.pip.FORWARD"
    private val actionPipToggleDanmaku = "com.predidit.kazumi.pip.TOGGLE_DANMAKU"

    // Ratios outside [1:2.39, 2.39:1] make enterPictureInPictureMode throw.
    private val maxPipAspectRatio = 2.39f

    private val pipActionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: android.content.Context?, intent: Intent?) {
            val action = intent?.action ?: return
            when (action) {
                actionPipPlayPause -> notifyFlutterPipAction("play_pause")
                actionPipForward -> notifyFlutterPipAction("forward")
                actionPipToggleDanmaku -> notifyFlutterPipAction("toggle_danmaku")
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerPipActionReceiverIfNeeded()
    }

    override fun onDestroy() {
        unregisterPipActionReceiverIfNeeded()
        super.onDestroy()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && androidFullscreen) {
            applySystemBarsState()
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        syncPictureInPictureMode()
    }

    @Suppress("DEPRECATION")
    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode)
        syncPictureInPictureMode()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        intentChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        intentChannel?.setMethodCallHandler { call, result ->
            if (call.method == "openWithMime") {
                val url = call.argument<String>("url")
                val mimeType = call.argument<String>("mimeType")
                if (url != null && mimeType != null) {
                    openWithMime(url, mimeType)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "URL and MIME type required", null)
                }
            } else if (call.method == "checkIfInMultiWindowMode") {
                val isInMultiWindow = checkIfInMultiWindowMode()
                result.success(isInMultiWindow)
            } else if (call.method == "getAndroidSdkVersion") {
                val sdkVersion = getAndroidSdkVersion()
                result.success(sdkVersion)
            } else if (call.method == "enterFullscreen") {
                enterAndroidFullscreen()
                result.success(null)
            } else if (call.method == "exitFullscreen") {
                exitAndroidFullscreen()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getAvailableStorage") {
                val path = call.argument<String>("path") ?: filesDir.absolutePath
                val availableBytes = getAvailableStorage(path)
                result.success(availableBytes)
            } else {
                result.notImplemented()
            }
        }

        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
        pipChannel?.setMethodCallHandler { call, result ->
            if (call.method == "isPictureInPictureSupported") {
                result.success(isPictureInPictureSupported())
            } else if (call.method == "enterPictureInPictureMode") {
                pipAspectWidth = call.argument<Int>("width") ?: pipAspectWidth
                pipAspectHeight = call.argument<Int>("height") ?: pipAspectHeight
                val entered = enterPictureInPicture()
                result.success(entered)
            } else if (call.method == "updatePictureInPictureActions") {
                val playing = call.argument<Boolean>("playing") ?: false
                val danmakuEnabled = call.argument<Boolean>("danmakuEnabled") ?: false
                pipAspectWidth = call.argument<Int>("width") ?: pipAspectWidth
                pipAspectHeight = call.argument<Int>("height") ?: pipAspectHeight
                updatePipSourceRect(call)
                updatePictureInPictureActions(playing, danmakuEnabled)
                result.success(true)
            } else if (call.method == "setAndroidAutoEnterPIPEnabled") {
                autoEnterPipOnHomeGesture = call.argument<Boolean>("enabled") ?: false
                refreshPictureInPictureParamsIfNeeded()
                result.success(true)
            } else if (call.method == "setAndroidPIPInPlayerPage") {
                pipInPlayerPage = call.argument<Boolean>("inPlayerPage") ?: false
                if (!pipInPlayerPage) {
                    pipSourceRect = null
                }
                refreshWindowBackground()
                refreshPictureInPictureParamsIfNeeded()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun openWithMime(url: String, mimeType: String) {
        val intent = Intent()
        intent.action = Intent.ACTION_VIEW
        intent.setDataAndType(Uri.parse(url), mimeType)
        startActivity(intent)
    }

    private fun checkIfInMultiWindowMode(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            this.isInMultiWindowMode 
        } else {
            false 
        }
    }

    private fun getAndroidSdkVersion(): Int {
        return Build.VERSION.SDK_INT
    }

    private fun enterAndroidFullscreen() {
        androidFullscreen = true
        applySystemBarsState()
    }

    private fun exitAndroidFullscreen() {
        androidFullscreen = false
        applySystemBarsState()
    }

    // System bars belong to the full size window; replayed on leaving PiP.
    private fun applySystemBarsState() {
        if (inPipMode) {
            return
        }
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        if (androidFullscreen) {
            controller.systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            controller.hide(WindowInsetsCompat.Type.systemBars())
        } else {
            controller.show(WindowInsetsCompat.Type.systemBars())
        }
    }

    // Single entry point: the mode callback and the configuration change both
    // route here, whichever the OEM delivers first.
    private fun syncPictureInPictureMode() {
        val current = isInPictureInPictureMode
        if (current == inPipMode) {
            return
        }
        inPipMode = current
        pipChannel?.invokeMethod("onModeChanged", mapOf("isInPipMode" to current))
        refreshWindowBackground()
        if (!current) {
            applySystemBarsState()
        }
    }

    // The window background shows through the Flutter surface while a resized
    // surface has no frame yet, so the light theme would paint the picture in
    // picture transition white.
    private fun refreshWindowBackground() {
        val blackBackground = inPipMode || pipInPlayerPage
        if (blackBackground == windowBackgroundOverridden) {
            return
        }
        if (blackBackground) {
            originalWindowBackground = window.decorView.background
            window.setBackgroundDrawable(ColorDrawable(Color.BLACK))
        } else {
            window.setBackgroundDrawable(originalWindowBackground)
            originalWindowBackground = null
        }
        windowBackgroundOverridden = blackBackground
    }

    private fun isPictureInPictureSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return false
        }
        return packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun enterPictureInPicture(): Boolean {
        if (!isPictureInPictureSupported()) {
            return false
        }
        if (isInPictureInPictureMode) {
            return true
        }
        return try {
            enterPictureInPictureMode(buildPictureInPictureParams())
        } catch (e: Exception) {
            false
        }
    }

    private fun updatePictureInPictureActions(
        playing: Boolean,
        danmakuEnabled: Boolean
    ) {
        if (!isPictureInPictureSupported()) {
            return
        }
        pipIsPlaying = playing
        pipDanmakuEnabled = danmakuEnabled
        refreshPictureInPictureParamsIfNeeded()
    }

    // In picture in picture the rect would describe the small window, so the
    // pre-PiP one is kept as the expand back target.
    private fun updatePipSourceRect(call: MethodCall) {
        if (inPipMode) {
            return
        }
        val left = call.argument<Int>("sourceLeft") ?: return
        val top = call.argument<Int>("sourceTop") ?: return
        val right = call.argument<Int>("sourceRight") ?: return
        val bottom = call.argument<Int>("sourceBottom") ?: return
        if (right <= left || bottom <= top) {
            return
        }
        pipSourceRect = Rect(left, top, right, bottom)
    }

    private fun buildPipSourceRectHint(): Rect? {
        val rect = pipSourceRect ?: return null
        val contentView = window.decorView.findViewById<View>(android.R.id.content) ?: return null
        val contentBounds = Rect()
        if (!contentView.getGlobalVisibleRect(contentBounds)) {
            return null
        }
        val hint = Rect(rect)
        hint.offset(contentBounds.left, contentBounds.top)
        if (!hint.intersect(contentBounds) || hint.isEmpty) {
            return null
        }
        return hint
    }

    private fun buildPipAspectRatio(): Rational {
        val width = if (pipAspectWidth > 0) pipAspectWidth else 16
        val height = if (pipAspectHeight > 0) pipAspectHeight else 9
        val ratio = width.toFloat() / height.toFloat()
        return when {
            ratio > maxPipAspectRatio -> Rational(239, 100)
            ratio < 1f / maxPipAspectRatio -> Rational(100, 239)
            else -> Rational(width, height)
        }
    }

    private fun buildPictureInPictureParams(): PictureInPictureParams {
        val actions = buildPipActions()
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(buildPipAspectRatio())
        buildPipSourceRectHint()?.let { builder.setSourceRectHint(it) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(autoEnterPipOnHomeGesture && pipInPlayerPage)
            // The crossfade alternative is driven by a window snapshot, which
            // holds no video surface and fades through an empty window.
            builder.setSeamlessResizeEnabled(true)
        }
        if (actions.isNotEmpty()) {
            builder.setActions(actions)
        }
        return builder.build()
    }

    private fun refreshPictureInPictureParamsIfNeeded() {
        if (!isPictureInPictureSupported()) {
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                setPictureInPictureParams(buildPictureInPictureParams())
            } catch (e: Exception) {
                // The activity can reject params while it is not resumed.
            }
        }
    }

    private fun buildPipActions(): List<RemoteAction> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return emptyList()
        }

        val allActions = mutableListOf<RemoteAction>(
            createPipAction(
                action = actionPipToggleDanmaku,
                requestCode = 1003,
                iconRes = if (pipDanmakuEnabled) R.drawable.ic_pip_danmaku_on else R.drawable.ic_pip_danmaku_off,
                title = if (pipDanmakuEnabled) "Danmaku On" else "Danmaku Off",
                description = if (pipDanmakuEnabled) "Turn off danmaku" else "Turn on danmaku",
                enabled = true
            ),
            createPipAction(
                action = actionPipPlayPause,
                requestCode = 1001,
                iconRes = if (pipIsPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                title = if (pipIsPlaying) "Pause" else "Play",
                description = if (pipIsPlaying) "Pause playback" else "Play playback",
                enabled = true
            ),
            createPipAction(
                action = actionPipForward,
                requestCode = 1002,
                iconRes = R.drawable.ic_pip_forward_80,
                title = "Forward",
                description = "Forward by custom seconds",
                enabled = true
            )
        )

        val maxActions = maxNumPictureInPictureActions
        if (allActions.size > maxActions) {
            allActions.subList(maxActions, allActions.size).clear()
        }
        return allActions
    }

    private fun createPipAction(
        action: String,
        requestCode: Int,
        iconRes: Int,
        title: String,
        description: String,
        enabled: Boolean
    ): RemoteAction {
        val intent = Intent(action).setPackage(packageName)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return RemoteAction(
            Icon.createWithResource(this, iconRes),
            title,
            description,
            pendingIntent
        ).apply {
            setEnabled(enabled)
        }
    }

    private fun notifyFlutterPipAction(action: String) {
        pipChannel?.invokeMethod("onAction", mapOf("action" to action))
    }

    private fun registerPipActionReceiverIfNeeded() {
        if (pipActionReceiverRegistered || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val filter = IntentFilter().apply {
            addAction(actionPipPlayPause)
            addAction(actionPipForward)
            addAction(actionPipToggleDanmaku)
        }
        ContextCompat.registerReceiver(
            this,
            pipActionReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
        pipActionReceiverRegistered = true
    }

    private fun unregisterPipActionReceiverIfNeeded() {
        if (!pipActionReceiverRegistered) {
            return
        }
        unregisterReceiver(pipActionReceiver)
        pipActionReceiverRegistered = false
    }

    private fun getAvailableStorage(path: String): Long {
        return try {
            val stat = StatFs(path)
            stat.availableBlocksLong * stat.blockSizeLong
        } catch (e: Exception) {
            -1L
        }
    }
}
