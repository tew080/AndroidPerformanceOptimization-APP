package com.example.apo

import android.app.ActivityManager
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

    // ตัวแปรสำหรับ Auto Cleaner
    private var isAutoCleanEnabled = false
    private var minRamThresholdMb = 500 // ค่า Default 500MB
    private val handler = Handler(Looper.getMainLooper())
    private val checkInterval = 10000L // เช็คทุกๆ 10 วินาที

    // Loop ตรวจสอบ RAM
    private val cleanRunnable = object : Runnable {
        override fun run() {
            if (isAutoCleanEnabled) {
                checkAndCleanRam()
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
            "start_auto" -> {
                // เริ่มระบบ Auto Clean
                val threshold = intent.getIntExtra("threshold", 500)
                startAutoClean(threshold)
            }

            "stop_auto" -> {
                // หยุดระบบ Auto Clean
                stopAutoClean()
            }

            "start" -> {
                // (โค้ดเดิม) start ปกติ
                val msg = intent.getStringExtra("message") ?: "Running..."
                startForeground(NOTIFICATION_ID, buildNotification(msg))
            }

            "stop" -> {
                stopForeground(true)
                stopSelf()
            }
        }

        return START_STICKY
    }

    private fun startAutoClean(threshold: Int) {
        minRamThresholdMb = threshold
        isAutoCleanEnabled = true

        // เริ่ม Loop
        handler.removeCallbacks(cleanRunnable)
        handler.post(cleanRunnable)

        // อัปเดต Notification
        val notif = buildNotification("Auto-RAM Cleaner Active (Threshold: ${threshold}MB)")
        startForeground(NOTIFICATION_ID, notif)
    }

    private fun stopAutoClean() {
        isAutoCleanEnabled = false
        handler.removeCallbacks(cleanRunnable)
        stopForeground(true)
        stopSelf()
    }

    // --- ฟังก์ชันตรวจสอบและล้าง RAM ---
    private fun checkAndCleanRam() {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mi = ActivityManager.MemoryInfo()
        am.getMemoryInfo(mi)

        val availMb = mi.availMem / 1024 / 1024
        // Log.d("ApoAuto", "RAM Check: ${availMb}MB / Threshold: ${minRamThresholdMb}MB")

        if (availMb < minRamThresholdMb) {
            Log.d("ApoAuto", "RAM Low! Triggering cleanup...")
            performCleanup()
        }
    }

    private fun performCleanup() {
        Thread {
            try {
                // 1. หา Top App (แอพที่เปิดอยู่) ผ่าน Shizuku
                // ใช้คำสั่ง dumpsys activity เพื่อหา ResumedActivity
                val p = Shizuku.newProcess(
                    arrayOf("sh", "-c", "dumpsys activity activities | grep mResumedActivity"),
                    null,
                    null
                )
                val reader = BufferedReader(InputStreamReader(p.inputStream))
                var line: String?
                var topAppPackage = ""

                // Output example: mResumedActivity: ActivityRecord{... u0 com.pubg.imobile/...}
                while (reader.readLine().also { line = it } != null) {
                    if (line!!.contains("u0 ")) {
                        val parts = line!!.split("u0 ")[1].split("/")
                        if (parts.isNotEmpty()) {
                            topAppPackage = parts[0].trim()
                            break
                        }
                    }
                }
                p.waitFor()

                Log.d("ApoAuto", "Top App Detected: $topAppPackage")

                // 2. ดึงรายการแอพทั้งหมด แล้วสั่ง Kill (ยกเว้น Top App และ ตัวเอง)
                val myPackage = packageName // com.example.apo

                // ดึงรายการ process
                val pList = Shizuku.newProcess(arrayOf("sh", "-c", "ps -A -o NAME"), null, null)
                val rList = BufferedReader(InputStreamReader(pList.inputStream))

                // ข้าม header
                rList.readLine()

                val killedApps = mutableListOf<String>()

                while (rList.readLine().also { line = it } != null) {
                    val pkg = line!!.trim()

                    // เงื่อนไขการฆ่า:
                    // 1. ต้องเป็นชื่อ package (มีจุด)
                    // 2. ไม่ใช่ Top App
                    // 3. ไม่ใช่ App ตัวเอง
                    // 4. ไม่ใช่ System UI (กันพลาด)
                    if (pkg.contains(".") &&
                        pkg != topAppPackage &&
                        pkg != myPackage &&
                        pkg != "com.android.systemui"
                    ) {

                        Shizuku.newProcess(arrayOf("sh", "-c", "am force-stop $pkg"), null, null).waitFor()
                        killedApps.add(pkg)
                    }
                }

                Log.d("ApoAuto", "Cleaned ${killedApps.size} apps. Saved RAM for $topAppPackage")

                // (Optional) ส่งเสียงหรือแจ้งเตือนว่าเคลียร์แล้ว
                // updateNotification("Cleaned RAM for $topAppPackage")

            } catch (e: Exception) {
                Log.e("ApoAuto", "Error cleaning: ${e.message}")
            }
        }.start()
    }

    // ... (ส่วน buildNotification และ createNotificationChannel เดิม เก็บไว้เหมือนเดิม) ...
    private fun buildNotification(text: String): android.app.Notification {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Android Optimizer")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setShowWhen(false)
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
