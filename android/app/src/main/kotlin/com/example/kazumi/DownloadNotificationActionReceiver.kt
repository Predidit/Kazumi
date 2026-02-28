package com.example.kazumi

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class DownloadNotificationActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return

        // 先落地，避免 Flutter 不在时丢事件
        val sp = context.getSharedPreferences("kazumi_download", Context.MODE_PRIVATE)
        sp.edit().putString("pending_action", action).apply()

        MainActivity.dispatchDownloadActionToFlutter(action)
    }

    companion object {
        const val ACTION_PAUSE_ALL = "kazumi.action.PAUSE_ALL"
    }
}
