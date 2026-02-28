package com.example.kazumi

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class DownloadForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "kazumi_download_channel"
        const val CHANNEL_NAME = "下载服务"
        const val NOTIFICATION_ID = 10086

        const val ACTION_START = "kazumi.action.DOWNLOAD_START"
        const val ACTION_UPDATE = "kazumi.action.DOWNLOAD_UPDATE"
        const val ACTION_STOP = "kazumi.action.DOWNLOAD_STOP"

        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_PROGRESS = "progress"
        const val EXTRA_INDETERMINATE = "indeterminate"

        fun start(context: Context, title: String, text: String) {
            val i = Intent(context, DownloadForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_TEXT, text)
                putExtra(EXTRA_PROGRESS, 0)
                putExtra(EXTRA_INDETERMINATE, true)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(i)
            else context.startService(i)
        }

        fun update(context: Context, title: String, text: String, progress: Int, indeterminate: Boolean = false) {
            val i = Intent(context, DownloadForegroundService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_TEXT, text)
                putExtra(EXTRA_PROGRESS, progress.coerceIn(0, 100))
                putExtra(EXTRA_INDETERMINATE, indeterminate)
            }
            context.startService(i)
        }

        fun stop(context: Context) {
            val i = Intent(context, DownloadForegroundService::class.java).apply { action = ACTION_STOP }
            context.startService(i)
        }
    }

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "正在下载"
                val text = intent.getStringExtra(EXTRA_TEXT) ?: "准备中..."
                val progress = intent.getIntExtra(EXTRA_PROGRESS, 0)
                val indeterminate = intent.getBooleanExtra(EXTRA_INDETERMINATE, true)
                startForeground(NOTIFICATION_ID, buildNotification(title, text, progress, indeterminate))
            }

            ACTION_UPDATE -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "正在下载"
                val text = intent.getStringExtra(EXTRA_TEXT) ?: ""
                val progress = intent.getIntExtra(EXTRA_PROGRESS, 0)
                val indeterminate = intent.getBooleanExtra(EXTRA_INDETERMINATE, false)
                val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                nm.notify(NOTIFICATION_ID, buildNotification(title, text, progress, indeterminate))
            }

            ACTION_STOP -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) stopForeground(STOP_FOREGROUND_REMOVE)
                else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun buildNotification(title: String, text: String, progress: Int, indeterminate: Boolean): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            action = MainActivity.ACTION_OPEN_DOWNLOAD_MANAGER
        }

        val pendingFlags =
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)

        val openPendingIntent = PendingIntent.getActivity(this, 0, openIntent, pendingFlags)

        val pauseIntent = Intent(this, DownloadNotificationActionReceiver::class.java).apply {
            action = DownloadNotificationActionReceiver.ACTION_PAUSE_ALL
        }
        val pausePending = PendingIntent.getBroadcast(this, 1, pauseIntent, pendingFlags)

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(openPendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setProgress(100, progress.coerceIn(0, 100), indeterminate)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(0, "暂停全部", pausePending)

        // Android 12+：更及时显示
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
        }

        return builder.build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_LOW).apply {
                description = "视频下载后台服务"
                setSound(null, null)
                enableVibration(false)
            }
            nm.createNotificationChannel(ch)
        }
    }
}
