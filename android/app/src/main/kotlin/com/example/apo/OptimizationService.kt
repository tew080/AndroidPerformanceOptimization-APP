package com.example.apo

import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.InputStreamReader

class OptimizationService : Service() {

    private val CHANNEL_ID = "OptimizerChannel"
    private val NOTIFICATION_ID = 1

    // State Variables (แยกสถานะกัน)
    private var isAutoCleanEnabled = false
    private var isGeneralModeEnabled = false // สำหรับ Game Booster / Network Priority

    private var minRamThresholdMb = 500
    private var currentGeneralMessage = "Optimization Active" // ข้อความของโหมดทั่วไป

    private val handler = Handler(Looper.getMainLooper())
    private val checkInterval = 10000L // 10 วินาที

    private val cleanRunnable = object : Runnable {
        override fun run() {
            if (isAutoCleanEnabled) {
                try {
                    checkAndCleanRam()
                } catch (e: Exception) {
                    Log.e("ApoService", "Error in loop: ${e.message}")
                }
                handler.postDelayed(this, checkInterval)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.getStringExtra("action")

        when (action) {
            // --- Auto Clean Logic ---
            "start_auto" -> {
                val threshold = intent.getIntExtra("threshold", 500)
                minRamThresholdMb = threshold
                isAutoCleanEnabled = true

                // เริ่ม Loop เช็ค RAM
                handler.removeCallbacks(cleanRunnable)
                handler.post(cleanRunnable)

                updateServiceNotification()
            }

            "stop_auto" -> {
                isAutoCleanEnabled = false
                handler.removeCallbacks(cleanRunnable)

                // เช็คว่าจะปิด Service เลยไหม
                checkAndStopSelf()
            }

            // --- General Logic (Game Booster / Network) ---
            "start" -> {
                val msg = intent.getStringExtra("message") ?: "Optimizing..."
                currentGeneralMessage = msg
                isGeneralModeEnabled = true

                updateServiceNotification()
            }

            "update" -> {
                // อัปเดตข้อความเฉยๆ ไม่เปลี่ยนสถานะ
                val msg = intent.getStringExtra("message") ?: currentGeneralMessage
                currentGeneralMessage = msg
                updateServiceNotification()
            }

            "stop" -> {
                isGeneralModeEnabled = false
                // เช็คว่าจะปิด Service เลยไหม
                checkAndStopSelf()
            }
        }

        return START_STICKY
    }

    // ฟังก์ชันรวมข้อความ Notification และอัปเดต
    private fun updateServiceNotification() {
        val displayText = StringBuilder()

        if (isGeneralModeEnabled) {
            displayText.append(currentGeneralMessage)
        }

        if (isAutoCleanEnabled) {
            if (displayText.isNotEmpty()) displayText.append(" | ")
            displayText.append("Auto-Clean (<${minRamThresholdMb}MB)")
        }

        if (displayText.isEmpty()) {
            displayText.append("Service Running...")
        }

        startForeground(NOTIFICATION_ID, buildNotification(displayText.toString()))
    }

    // ฟังก์ชันตัดสินใจว่าจะปิด Service หรือไม่
    private fun checkAndStopSelf() {
        // ถ้าทั้ง 2 โหมดปิดหมดแล้ว ค่อยทำลาย Service ทิ้ง
        if (!isAutoCleanEnabled && !isGeneralModeEnabled) {
            stopForeground(true)
            stopSelf()
        } else {
            // ถ้ายังมีอย่างใดอย่างหนึ่งเปิดอยู่ ให้อัปเดต Notification แทน
            updateServiceNotification()
        }
    }

    // --- Logic การเช็ค RAM (เหมือนเดิมที่แก้แล้ว) ---
    private fun checkAndCleanRam() {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mi = ActivityManager.MemoryInfo()
        am.getMemoryInfo(mi)

        val availMb = mi.availMem / 1024 / 1024
        if (availMb < minRamThresholdMb) {
            Log.d("ApoAuto", "RAM Low detected! Triggering cleanup...")
            performCleanup()
        }
    }

    private fun performCleanup() {
        Thread {
            try {
                // 1. หา Top App
                val p = Shizuku.newProcess(
                    arrayOf("sh", "-c", "dumpsys activity activities | grep mResumedActivity"),
                    null,
                    null
                )
                val reader = BufferedReader(InputStreamReader(p.inputStream))
                var line: String?
                var topAppPackage = ""

                while (reader.readLine().also { line = it } != null) {
                    val safeLine = line ?: continue
                    if (safeLine.contains("u0 ") && safeLine.contains("/")) {
                        try {
                            val afterU0 = safeLine.substringAfter("u0 ")
                            val component = afterU0.substringBefore(" ")
                            topAppPackage = component.substringBefore("/")
                            if (topAppPackage.isNotEmpty()) break
                        } catch (e: Exception) {
                            Log.e("ApoAuto", "Parse error: ${e.message}")
                        }
                    }
                }
                p.waitFor()

                if (topAppPackage.isEmpty()) return@Thread

                // 2. ฆ่า Process อื่นๆ
                val myPackage = packageName
                val pList = Shizuku.newProcess(arrayOf("sh", "-c", "ps -A -o NAME"), null, null)
                val rList = BufferedReader(InputStreamReader(pList.inputStream))
                rList.readLine() // skip header

                val killCommands = StringBuilder()
                var count = 0

                while (rList.readLine().also { line = it } != null) {
                    val pkg = line?.trim() ?: continue
                    if (pkg.contains(".") &&
                        pkg != topAppPackage &&
                        pkg != myPackage &&
                        pkg != "com.android.systemui" &&
                        !pkg.startsWith("com.google.android.inputmethod")
                    ) {
                        killCommands.append("am force-stop $pkg\n")
                        count++
                    }
                }
                pList.waitFor()

                if (killCommands.isNotEmpty()) {
                    if (killCommands.length <= 100000) {
                        Shizuku.newProcess(arrayOf("sh", "-c", killCommands.toString()), null, null).waitFor()
                        Log.d("ApoAuto", "Batch cleaned $count apps.")
                    }
                }

            } catch (e: Exception) {
                Log.e("ApoAuto", "Error cleaning: ${e.message}")
            }
        }.start()
    }

    private fun buildNotification(text: String): Notification {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Android Optimizer")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setShowWhen(false)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE) // เพิ่มบรรทัดนี้เพื่อลดการหน่วง
        return builder.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Optimization Service", NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
