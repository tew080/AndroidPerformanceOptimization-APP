import 'package:flutter/services.dart';

/// Service สำหรับสื่อสารกับ Native Android (Kotlin) ผ่าน MethodChannel
class ShizukuService {
  // ชื่อ Channel ต้องตรงกับใน MainActivity.kt
  static const platform = MethodChannel('com.example.optimizer/shizuku');

  /// ตรวจสอบสิทธิ์ Shizuku
  static Future<bool> checkPermission() async {
    try {
      final bool result = await platform.invokeMethod('checkPermission');
      return result;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// ขอสิทธิ์ Notification (Android 13+)
  static Future<void> requestNotificationPermission() async {
    try {
      await platform.invokeMethod('requestNotificationPermission');
    } catch (e) {
      print("Warning: Failed to request notification permission: $e");
    }
  }

  /// ส่งคำสั่ง Shell ไปรัน
  static Future<String> runCommand(String command) async {
    try {
      final String result = await platform.invokeMethod('runCommand', {
        "command": command,
      });
      return result;
    } on PlatformException catch (e) {
      return "Native Error: ${e.message}";
    }
  }

  /// สั่งหยุดคำสั่งปัจจุบัน (Kill process)
  static Future<void> cancelCurrentCommand() async {
    try {
      await platform.invokeMethod('cancelCommand');
    } catch (_) {}
  }

  // --- Background Service Methods ---

  static Future<void> startService(String message) async {
    try {
      await platform.invokeMethod('startService', {"message": message});
    } catch (_) {}
  }

  static Future<void> updateService(
    String message,
    int progress,
    int max,
  ) async {
    try {
      await platform.invokeMethod('updateService', {
        "message": message,
        "progress": progress,
        "max": max,
      });
    } catch (_) {}
  }

  static Future<void> stopService() async {
    try {
      await platform.invokeMethod('stopService');
    } catch (_) {}
  }
}
