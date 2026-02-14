package com.example.kazumi

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.StatFs
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.predidit.kazumi/intent"
    private val STORAGE_CHANNEL = "com.predidit.kazumi/storage"

    private val DOWNLOAD_FG_CHANNEL = "kazumi/download_fg"
    private val NOTIF_PERMISSION_CHANNEL = "kazumi/notification_permission"
    private val DOWNLOAD_ACTIONS_CHANNEL = "kazumi/download_actions"

    private val REQ_POST_NOTIFICATIONS = 10001
    private var pendingPermissionResult: MethodChannel.Result? = null

    companion object {
        const val ACTION_OPEN_DOWNLOAD_MANAGER = "kazumi.action.OPEN_DOWNLOAD_MANAGER"
        private var downloadActionsChannel: MethodChannel? = null

        fun dispatchDownloadActionToFlutter(action: String) {
            val id = when (action) {
                DownloadNotificationActionReceiver.ACTION_PAUSE_ALL -> "pause_all"
                else -> action
            }
            downloadActionsChannel?.invokeMethod("onAction", mapOf("id" to id))
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openWithMime" -> {
                    val url = call.argument<String>("url")
                    val mimeType = call.argument<String>("mimeType")
                    if (url != null && mimeType != null) {
                        openWithMime(url, mimeType)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "URL and MIME type required", null)
                    }
                }
                "checkIfInMultiWindowMode" -> result.success(checkIfInMultiWindowMode())
                "getAndroidSdkVersion" -> result.success(getAndroidSdkVersion())
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAvailableStorage" -> {
                    val path = call.argument<String>("path") ?: filesDir.absolutePath
                    result.success(getAvailableStorage(path))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_FG_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val title = call.argument<String>("title") ?: "正在下载"
                    val text = call.argument<String>("text") ?: "准备中..."
                    DownloadForegroundService.start(this, title, text)
                    result.success(true)
                }
                "update" -> {
                    val title = call.argument<String>("title") ?: "正在下载"
                    val text = call.argument<String>("text") ?: ""
                    val progress = call.argument<Int>("progress") ?: 0
                    val indeterminate = call.argument<Boolean>("indeterminate") ?: false
                    DownloadForegroundService.update(this, title, text, progress, indeterminate)
                    result.success(true)
                }
                "stop" -> {
                    DownloadForegroundService.stop(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 通知权限
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_PERMISSION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "check" -> result.success(isNotificationPermissionGranted())
                "request" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    if (isNotificationPermissionGranted()) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    if (pendingPermissionResult != null) {
                        result.error("IN_PROGRESS", "Permission request already in progress", null)
                        return@setMethodCallHandler
                    }
                    pendingPermissionResult = result
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        REQ_POST_NOTIFICATIONS
                    )
                }
                else -> result.notImplemented()
            }
        }

        downloadActionsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_ACTIONS_CHANNEL)
        handleIntentForDownloadManager(intent)
        flushPendingDownloadAction()
    }

    private fun flushPendingDownloadAction() {
        val sp = getSharedPreferences("kazumi_download", Context.MODE_PRIVATE)
        val pending = sp.getString("pending_action", null) ?: return
        sp.edit().remove("pending_action").apply()
        dispatchDownloadActionToFlutter(pending)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntentForDownloadManager(intent)
    }

    private fun handleIntentForDownloadManager(intent: Intent?) {
        if (intent?.action == ACTION_OPEN_DOWNLOAD_MANAGER) {
            dispatchDownloadActionToFlutter(ACTION_OPEN_DOWNLOAD_MANAGER)
            // 防止同一 intent 在某些机型/系统行为下重复触发
            intent.action = null
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_POST_NOTIFICATIONS) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun isNotificationPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) true
        else ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    private fun openWithMime(url: String, mimeType: String) {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse(url), mimeType)
        }
        startActivity(intent)
    }

    private fun checkIfInMultiWindowMode(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && this.isInMultiWindowMode
    }

    private fun getAndroidSdkVersion(): Int {
        return Build.VERSION.SDK_INT
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
