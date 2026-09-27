package com.example.kazumi

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** SAF grants are persisted; media_kit opens the original content URI. */
class LocalVideoAccess(private val activity: Activity, messenger: BinaryMessenger) {
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var generation = 0
    private var pickerOpen = false
    private val channel = MethodChannel(messenger, "com.predidit.kazumi/local_video")
    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pick" -> {
                    if (pending != null || pickerOpen) { result.error("BUSY", "文件选择器已打开", null) }
                    else {
                        pending = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            type = "video/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                        }
                        try { pickerOpen = true; activity.startActivityForResult(intent, REQUEST) }
                        catch (error: Exception) { pickerOpen = false; pending = null; result.error("PICK", error.message, null) }
                    }
                }
                "cancel" -> { generation++; pending?.success(null); pending = null; result.success(null) }
                "inspect" -> {
                    val source = call.argument<String>("source")
                    if (source == null) result.error("INVALID", "缺少文件地址", null)
                    else worker.execute {
                        try { val data = inspect(Uri.parse(source)); activity.runOnUiThread { result.success(data) } }
                        catch (error: Exception) { activity.runOnUiThread { result.error("ACCESS", "文件不可访问，请重新选择", null) } }
                    }
                }
                "release" -> {
                    call.argument<String>("source")?.let { release(Uri.parse(it)) }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun release(uri: Uri) {
        try { activity.contentResolver.releasePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) } catch (_: Exception) {}
    }
    private fun inspect(uri: Uri): Map<String, Any?> {
        require(uri.scheme == "content")
        val resolver = activity.contentResolver
        var name = "视频"
        var size: Long = -1
        var modified: Long? = null
        resolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                val modifiedIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
                if (nameIndex >= 0) name = cursor.getString(nameIndex)
                if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) size = cursor.getLong(sizeIndex)
                if (modifiedIndex >= 0 && !cursor.isNull(modifiedIndex)) modified = cursor.getLong(modifiedIndex)
            }
        }
        resolver.openAssetFileDescriptor(uri, "r")?.use { descriptor ->
            if (size < 0) size = descriptor.length
            descriptor.createInputStream().use { require(it.read() != -1) { "文件为空" } }
        } ?: error("无法读取文件")
        require(size != 0L) { "文件为空" }
        return mapOf("source" to uri.toString(), "name" to name, "location" to (uri.authority ?: "设备文档"), "size" to size, "modifiedMs" to modified)
    }
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST) return
        pickerOpen = false
        val result = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return }
        val token = generation
        val existed = activity.contentResolver.persistedUriPermissions.any { it.uri == uri && it.isReadPermission }
        worker.execute {
            try {
                activity.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                val info = inspect(uri)
                activity.runOnUiThread {
                    if (token == generation) result.success(info)
                    else { if (!existed) release(uri); result.success(null) }
                }
            } catch (error: Exception) {
                if (!existed) release(uri)
                activity.runOnUiThread { result.error("ACCESS", "无法取得持久读取授权，请选择设备上的视频", null) }
            }
        }
    }
    fun dispose() { generation++; pending?.success(null); pending = null; channel.setMethodCallHandler(null); worker.shutdown() }
    companion object { const val REQUEST = 7241 }
}
