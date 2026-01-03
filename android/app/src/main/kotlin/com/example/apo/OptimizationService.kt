package com.example.apo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class OptimizationService : Service() {

    private val CHANNEL_ID = "OptimizerChannel"
    private val NOTIFICATION_ID = 1

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.getStringExtra("action")
        val message = intent?.getStringExtra("message") ?: "Optimizing..."
        val progress = intent?.getIntExtra("progress", 0) ?: 0
        val max = intent?.getIntExtra("max", 0) ?: 0

        if (action == "start") {
            val notification = buildNotification(message, progress, max)
            startForeground(NOTIFICATION_ID, notification)
        } else if (action == "update") {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, buildNotification(message, progress, max))
        } else if (action == "stop") {
            stopForeground(true)
            stopSelf()
        }

        return START_NOT_STICKY
    }

    private fun buildNotification(text: String, progress: Int, max: Int): android.app.Notification {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Android Optimizer Working")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_download) // เปลี่ยนไอคอนได้
            .setOnlyAlertOnce(true)
            .setOngoing(true)

        if (max > 0) {
            builder.setProgress(max, progress, false)
        } else {
            builder.setProgress(0, 0, true) // Indeterminate
        }

        return builder.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Optimization Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
