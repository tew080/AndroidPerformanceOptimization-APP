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

                else -> result.notImplemented()
            }
        }
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
}
