package com.example.kazumi

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.storage.StorageManager
import android.provider.DocumentsContract
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Grants storage access and picks a local directory when the user changes the
 * download location. Downloads then use the plain filesystem path.
 */
class DownloadDirectoryHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.predidit.kazumi/download_directory"
        private const val ACCESS_REQUEST = 53010
        private const val DIRECTORY_REQUEST = 53011
        private const val EXTERNAL_DOCUMENTS = "com.android.externalstorage.documents"
    }

    private var accessResult: MethodChannel.Result? = null
    private var directoryResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestStorageAccess" -> requestStorageAccess(result)
            "pickDirectory" -> pickDirectory(call.argument<String>("initialDirectory"), result)
            else -> result.notImplemented()
        }
    }

    private fun isBusy(result: MethodChannel.Result): Boolean {
        if (accessResult == null && directoryResult == null) return false
        result.error("DIRECTORY_BUSY", "Another directory request is in progress", null)
        return true
    }

    private fun hasStorageAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(activity, Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    @Suppress("DEPRECATION")
    private fun requestStorageAccess(result: MethodChannel.Result) {
        if (isBusy(result)) return
        if (hasStorageAccess()) {
            result.success(true)
            return
        }
        accessResult = result
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val appSettings = Intent(
                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:${activity.packageName}")
                )
                try {
                    activity.startActivityForResult(appSettings, ACCESS_REQUEST)
                } catch (_: android.content.ActivityNotFoundException) {
                    activity.startActivityForResult(
                        Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION), ACCESS_REQUEST
                    )
                }
            } else {
                activity.requestPermissions(
                    arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE),
                    ACCESS_REQUEST
                )
            }
        } catch (e: Exception) {
            accessResult = null
            result.error("STORAGE_ACCESS_FAILED", "Failed to open storage access settings: ${e.message}", null)
        }
    }

    @Suppress("DEPRECATION")
    private fun pickDirectory(initialDirectory: String?, result: MethodChannel.Result) {
        if (isBusy(result)) return
        if (!hasStorageAccess()) {
            result.error("STORAGE_ACCESS_DENIED", "Storage access is not granted", null)
            return
        }
        directoryResult = result
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                putExtra(Intent.EXTRA_LOCAL_ONLY, true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && initialDirectory != null) {
                    initialUri(File(initialDirectory))?.let {
                        putExtra(DocumentsContract.EXTRA_INITIAL_URI, it)
                    }
                }
            }
            activity.startActivityForResult(intent, DIRECTORY_REQUEST)
        } catch (e: Exception) {
            directoryResult = null
            result.error("DIRECTORY_PICKER_FAILED", "Failed to open directory picker: ${e.message}", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            ACCESS_REQUEST -> finishAccessRequest()
            DIRECTORY_REQUEST -> {
                val result = directoryResult ?: return
                directoryResult = null
                if (resultCode != Activity.RESULT_OK) {
                    result.success(null)
                    return
                }
                try {
                    val uri = data?.data
                    val directory = uri?.let { resolveDirectory(it) }
                    if (directory == null) {
                        result.error(
                            "UNSUPPORTED_DIRECTORY",
                            "Only directories on local storage volumes are supported",
                            null
                        )
                    } else {
                        result.success(directory.canonicalPath)
                    }
                } catch (e: Exception) {
                    result.error("INVALID_DIRECTORY", "Failed to resolve the selected directory: ${e.message}", null)
                }
            }
        }
    }

    fun onRequestPermissionsResult(requestCode: Int) {
        if (requestCode == ACCESS_REQUEST) finishAccessRequest()
    }

    private fun finishAccessRequest() {
        val result = accessResult ?: return
        accessResult = null
        // Settings activities commonly return RESULT_CANCELED even after a grant.
        result.success(hasStorageAccess())
    }

    @Suppress("DEPRECATION")
    private fun storageRoots(): List<Pair<String, File>> {
        val roots = mutableListOf("primary" to Environment.getExternalStorageDirectory())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val manager = activity.getSystemService(StorageManager::class.java)
            manager.storageVolumes.forEach { volume ->
                val id = volume.uuid
                val directory = volume.directory
                if (id != null && directory != null) roots.add(id to directory)
            }
        } else {
            // getExternalFilesDirs exposes mounted removable volumes on older APIs.
            activity.getExternalFilesDirs(null).filterNotNull().forEach { directory ->
                val rootPath = directory.absolutePath.substringBefore("/Android/data/")
                val root = File(rootPath)
                if (rootPath != directory.absolutePath && root.name != "0") {
                    roots.add(root.name to root)
                }
            }
        }
        return roots
    }

    private fun resolveDirectory(uri: Uri): File? {
        // A document URI is not a filesystem path. Only resolve known local
        // storage volumes, never invent a path for cloud/virtual providers.
        if (uri.scheme != "content" || uri.authority != EXTERNAL_DOCUMENTS ||
            !DocumentsContract.isTreeUri(uri)) return null
        val documentId = DocumentsContract.getTreeDocumentId(uri)
        val separator = documentId.indexOf(':')
        if (separator < 0) return null
        val volumeId = documentId.substring(0, separator)
        val root = storageRoots().firstOrNull { it.first.equals(volumeId, ignoreCase = true) }?.second
            ?: return null
        val directory = File(root, documentId.substring(separator + 1))
        return if (contains(root, directory)) directory else null
    }

    private fun initialUri(directory: File): Uri? {
        val entry = storageRoots().firstOrNull { contains(it.second, directory) } ?: return null
        val relative = directory.canonicalFile.relativeTo(entry.second.canonicalFile).path
        return DocumentsContract.buildDocumentUri(EXTERNAL_DOCUMENTS, "${entry.first}:$relative")
    }

    private fun contains(root: File, directory: File): Boolean {
        val rootPath = root.canonicalPath
        val directoryPath = directory.canonicalPath
        return directoryPath == rootPath || directoryPath.startsWith(rootPath + File.separator)
    }

    fun dispose() {
        accessResult?.error("ACTIVITY_CLOSED", "Activity destroyed during storage access request", null)
        directoryResult?.error("ACTIVITY_CLOSED", "Activity destroyed during directory selection", null)
        accessResult = null
        directoryResult = null
    }
}
