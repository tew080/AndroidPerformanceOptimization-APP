package com.example.apo

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.optimizer/shizuku"
    private var currentProcess: Process? = null

    // Cache รายชื่อ System Apps เพื่อลดการดึงข้อมูลซ้ำซ้อน
    private var cachedSystemApps: Set<String>? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Shizuku.addRequestPermissionResultListener { _, _ -> }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
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

                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
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

                "startService" -> {
                    val msg = call.argument<String>("message")
                    startOptimizationService("start", msg)
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
                    val prefs = getSharedPreferences("ApoPrefs", Context.MODE_PRIVATE)
                    prefs.edit().putInt("auto_ram_threshold", threshold).apply()

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

    private fun startOptimizationService(action: String, message: String? = null) {
        val intent = Intent(this, OptimizationService::class.java).apply {
            putExtra("action", action)
            if (message != null) putExtra("message", message)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    // Helper: โหลดรายชื่อ System Apps ครั้งเดียวแล้วเก็บไว้ (Optimize)
    private fun getSystemApps(): Set<String> {
        if (cachedSystemApps != null && cachedSystemApps!!.isNotEmpty()) {
            return cachedSystemApps!!
        }

        val systemApps = mutableSetOf<String>()
        try {
            val pPkg = Shizuku.newProcess(arrayOf("sh", "-c", "pm list packages -s"), null, null)
            val readerPkg = BufferedReader(InputStreamReader(pPkg.inputStream))
            var linePkg: String?
            while (readerPkg.readLine().also { linePkg = it } != null) {
                val pkg = linePkg!!.replace("package:", "").trim()
                systemApps.add(pkg)
            }
            pPkg.waitFor()
        } catch (e: Exception) {
            Log.e("ApoSysApps", "Error loading system apps: ${e.message}")
        }
        cachedSystemApps = systemApps
        return systemApps
    }

    private fun getProcessList(): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) return list

        try {
            val systemApps = getSystemApps() // เรียกใช้ฟังก์ชันกลาง

            val p = Shizuku.newProcess(arrayOf("sh", "-c", "ps -A -o RSS,NAME"), null, null)
            val reader = BufferedReader(InputStreamReader(p.inputStream))
            reader.readLine() // Skip Header

            var line: String?
            while (reader.readLine().also { line = it } != null) {
                val l = line!!.trim()
                val parts = l.split(Regex("\\s+"))

                if (parts.size >= 2) {
                    val rssKb = parts[0].toLongOrNull() ?: 0L
                    val rawName = parts[1]

                    if (rawName.contains(".") && !rawName.startsWith("[")) {
                        val pkgName = rawName.split(":")[0]
                        var isSystem = systemApps.contains(pkgName)

                        if (!isSystem) {
                            if (pkgName.startsWith("com.android.") || pkgName == "android") {
                                isSystem = true
                            }
                        }

                        if (rssKb > 0) {
                            list.add(
                                mapOf(
                                    "pkg" to rawName,
                                    "ram_kb" to rssKb,
                                    "ram_mb" to (rssKb / 1024),
                                    "is_system" to isSystem
                                )
                            )
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
            val systemApps = getSystemApps() // เรียกใช้ฟังก์ชันกลาง

            val p = Shizuku.newProcess(arrayOf("sh", "-c", "pm list packages -d"), null, null)
            val reader = BufferedReader(InputStreamReader(p.inputStream))
            var line: String?

            while (reader.readLine().also { line = it } != null) {
                val pkg = line!!.replace("package:", "").trim()
                if (pkg.isNotEmpty()) {
                    var isSystem = systemApps.contains(pkg)
                    if (!isSystem && (pkg.startsWith("com.android.") || pkg == "android")) {
                        isSystem = true
                    }
                    list.add(mapOf("pkg" to pkg, "is_system" to isSystem))
                }
            }
            p.waitFor()
            list.sortBy { it["pkg"] as String }

        } catch (e: Exception) {
            Log.e("ApoDisabled", "Error: ${e.message}")
        }
        return list
    }

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
