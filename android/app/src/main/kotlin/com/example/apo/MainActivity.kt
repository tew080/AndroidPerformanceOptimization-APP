package com.example.apo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.InputStreamReader
import android.util.Log
import android.app.ActivityManager

class MainActivity : FlutterActivity() {
    // ชื่อ Channel ต้องตรงกับฝั่ง Dart 100%
    private val CHANNEL = "com.example.optimizer/shizuku"
    private var currentProcess: Process? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Listener สำหรับผลการขอสิทธิ์ Shizuku
        Shizuku.addRequestPermissionResultListener { _, _ -> }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // --- 1. ตรวจสอบสิทธิ์ Shizuku ---
                "checkPermission" -> {
                    if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        if (!Shizuku.shouldShowRequestPermissionRationale()) {
                            Shizuku.requestPermission(0)
                        }
                        result.success(false)
                    }
                }

                // --- 2. ขอสิทธิ์แจ้งเตือน (Android 13+) [FIXED CODE] ---
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        // ใช้ android.Manifest แบบเต็มยศ เพื่อแก้ปัญหา Unresolved reference
                        if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
                            result.success(false)
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }

                // --- 3. รันคำสั่ง Shell ---
                "runCommand" -> {
                    val command = call.argument<String>("command")
                    if (command != null) {
                        Thread {
                            val output = executeShizukuCommand(command)
                            runOnUiThread { result.success(output) }
                        }.start()
                    } else {
                        result.error("INVALID", "Command is null", null)
                    }
                }

                // --- 4. ยกเลิกคำสั่ง (Kill Process) ---
                "cancelCommand" -> {
                    if (currentProcess != null) {
                        try {
                            currentProcess!!.destroy()
                            currentProcess = null
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    } else {
                        result.success(false)
                    }
                }

                // --- 5. จัดการ Background Service ---
                "startService" -> {
                    val msg = call.argument<String>("message")
                    val intent = Intent(this, OptimizationService::class.java).apply {
                        putExtra("action", "start")
                        putExtra("message", msg)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }

                "updateService" -> {
                    val intent = Intent(this, OptimizationService::class.java).apply {
                        putExtra("action", "update")
                        putExtra("message", call.argument<String>("message"))
                        putExtra("progress", call.argument<Int>("progress"))
                        putExtra("max", call.argument<Int>("max"))
                    }
                    startService(intent)
                    result.success(true)
                }

                "stopService" -> {
                    val intent = Intent(this, OptimizationService::class.java).apply {
                        putExtra("action", "stop")
                    }
                    startService(intent)
                    result.success(true)
                }
                // [เพิ่ม case นี้] ดึงรายชื่อ Process และ RAM
                "getRunningProcesses" -> {
                    Thread {
                        val processes = getProcessList()
                        runOnUiThread { result.success(processes) }
                    }.start()
                }

                "getDisabledApps" -> {
                    Thread {
                        val apps = getDisabledAppList()
                        runOnUiThread { result.success(apps) }
                    }.start()
                }

                "startAutoCleaner" -> {
                    val threshold = call.argument<Int>("threshold") ?: 500

                    // [เพิ่ม] บันทึกค่าลง Memory เครื่อง (SharedPreferences)
                    val prefs = getSharedPreferences("ApoPrefs", Context.MODE_PRIVATE)
                    prefs.edit().putInt("auto_ram_threshold", threshold).apply()

                    // รัน Service ตามปกติ
                    val intent = Intent(this, OptimizationService::class.java).apply {
                        putExtra("action", "start_auto")
                        putExtra("threshold", threshold)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }

                "stopAutoCleaner" -> {
                    val intent = Intent(this, OptimizationService::class.java).apply {
                        putExtra("action", "stop_auto")
                    }
                    startService(intent)
                    result.success(true)
                }

                "getAutoCleanerThreshold" -> {
                    val prefs = getSharedPreferences("ApoPrefs", Context.MODE_PRIVATE)
                    // ค่า default 500 ถ้าไม่เคยตั้ง
                    val savedThreshold = prefs.getInt("auto_ram_threshold", 500)
                    result.success(savedThreshold)
                }

                "saveAutoCleanerThreshold" -> {
                    val threshold = call.argument<Int>("threshold") ?: 500
                    val prefs = getSharedPreferences("ApoPrefs", Context.MODE_PRIVATE)
                    prefs.edit().putInt("auto_ram_threshold", threshold).apply()
                    result.success(true)
                }

                "isAutoCleanerRunning" -> {
                    val isRunning = isServiceRunning(OptimizationService::class.java)
                    result.success(isRunning)
                }

                else -> result.notImplemented()
            }
        }
    }

    // [เพิ่มฟังก์ชันนี้ต่อท้าย] อ่าน Process ด้วยคำสั่ง ps
    private fun getProcessList(): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()

        if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
            return list
        }

        try {
            // 1. ดึงรายชื่อ System Package ทั้งหมดมาก่อน (เก็บใส่ Set เพื่อค้นหาเร็วๆ)
            // คำสั่ง: pm list packages -s (s = system)
            val systemApps = mutableSetOf<String>()
            val pPkg = Shizuku.newProcess(arrayOf("sh", "-c", "pm list packages -s"), null, null)
            val readerPkg = BufferedReader(InputStreamReader(pPkg.inputStream))
            var linePkg: String?
            while (readerPkg.readLine().also { linePkg = it } != null) {
                // output จะเป็น "package:com.android.systemui" -> ตัด "package:" ออก
                val pkg = linePkg!!.replace("package:", "").trim()
                systemApps.add(pkg)
            }
            pPkg.waitFor()

            // 2. ดึง Process ที่รันอยู่ (ps)
            val p = Shizuku.newProcess(arrayOf("sh", "-c", "ps -A -o RSS,NAME"), null, null)
            val reader = BufferedReader(InputStreamReader(p.inputStream))

            reader.readLine() // ข้าม Header
            var line: String?

            while (reader.readLine().also { line = it } != null) {
                val l = line!!.trim()
                val parts = l.split(Regex("\\s+"))

                if (parts.size >= 2) {
                    val rssKb = parts[0].toLongOrNull() ?: 0L
                    val rawName = parts[1]

                    // กรองเอาเฉพาะที่มี . (ว่าเป็นชื่อ package)
                    if (rawName.contains(".") && !rawName.startsWith("[")) {

                        // ตัดชื่อหลัง : ออก (เช่น com.telegram.messenger:push -> com.telegram.messenger)
                        val pkgName = rawName.split(":")[0]

                        // 3. ตรวจสอบ: ถ้าชื่อนี้อยู่ในรายการ System Apps ที่เราดึงมา -> คือ System
                        var isSystem = systemApps.contains(pkgName)

                        // ข้อยกเว้น: แอพที่เป็นของ Google หรือ Android แต่ไม่อยู่ใน list (บางทีเป็น Service)
                        // ให้เช็คจากชื่อเอา (กันเหนียว)
                        if (!isSystem) {
                            if (pkgName.startsWith("com.android.") || pkgName == "android") {
                                isSystem = true
                            }
                        }

                        if (rssKb > 0) {
                            val map = mapOf(
                                "pkg" to rawName,
                                "ram_kb" to rssKb,
                                "ram_mb" to (rssKb / 1024),
                                "is_system" to isSystem // ส่งค่าที่ถูกต้อง 100%
                            )
                            list.add(map)
                        }
                    }
                }
            }
            p.waitFor()
            list.sortByDescending { it["ram_kb"] as Long }

        } catch (e: Exception) {
            Log.e("ApoProcess", "Error: ${e.message}")
        }
        return list
    }

    private fun getDisabledAppList(): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) return list

        try {
            // 1. ดึงรายชื่อ System Apps ทั้งหมดไว้เทียบ (เหมือนเดิม)
            val systemApps = mutableSetOf<String>()
            val pSys = Shizuku.newProcess(arrayOf("sh", "-c", "pm list packages -s"), null, null)
            val rSys = BufferedReader(InputStreamReader(pSys.inputStream))
            var lSys: String?
            while (rSys.readLine().also { lSys = it } != null) {
                systemApps.add(lSys!!.replace("package:", "").trim())
            }
            pSys.waitFor()

            // 2. ดึงรายชื่อแอพที่ถูก Disable (pm list packages -d)
            // -d = disabled only
            val p = Shizuku.newProcess(arrayOf("sh", "-c", "pm list packages -d"), null, null)
            val reader = BufferedReader(InputStreamReader(p.inputStream))
            var line: String?

            while (reader.readLine().also { line = it } != null) {
                // output format: package:com.example.app
                val pkg = line!!.replace("package:", "").trim()

                if (pkg.isNotEmpty()) {
                    // เช็คว่าเป็น System App หรือไม่
                    var isSystem = systemApps.contains(pkg)
                    if (!isSystem && (pkg.startsWith("com.android.") || pkg == "android")) {
                        isSystem = true
                    }

                    list.add(
                        mapOf(
                            "pkg" to pkg,
                            "is_system" to isSystem
                        )
                    )
                }
            }
            p.waitFor()
            // เรียงตามตัวอักษร
            list.sortBy { it["pkg"] as String }

        } catch (e: Exception) {
            Log.e("ApoDisabled", "Error: ${e.message}")
        }
        return list
    }

    // ฟังก์ชันรันคำสั่งผ่าน Shizuku
    private fun executeShizukuCommand(command: String): String {
        return try {
            currentProcess = Shizuku.newProcess(arrayOf("sh", "-c", command), null, null)
            val reader = BufferedReader(InputStreamReader(currentProcess!!.inputStream))
            val output = StringBuilder()
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                output.append(line).append("\n")
            }
            currentProcess!!.waitFor()
            currentProcess = null
            output.toString()
        } catch (e: Exception) {
            currentProcess = null
            "Error: ${e.message}"
        }
    }

    @Suppress("DEPRECATION")
    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        for (service in manager.getRunningServices(Int.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }
}
