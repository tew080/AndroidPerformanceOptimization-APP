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

  // [เพิ่ม] ดึงรายชื่อแอพที่รันอยู่
  static Future<List<dynamic>> getRunningProcesses() async {
    try {
      final List<dynamic> result = await platform.invokeMethod(
        'getRunningProcesses',
      );
      return result;
    } catch (e) {
      print("Error getting processes: $e");
      return [];
    }
  }

  // [เพิ่ม] สั่งหยุดแอพ (Force Stop)
  static Future<bool> forceStopApp(String packageName) async {
    try {
      // ใช้คำสั่ง am force-stop เพื่อหยุดแอพทันที
      await runCommand("am force-stop $packageName");
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> disableApp(String packageName) async {
    try {
      // ใช้คำสั่ง pm disable-user --user 0
      await runCommand("pm disable-user --user 0 $packageName");
      return true;
    } catch (e) {
      return false;
    }
  }

  /// สั่ง Enable แอพ (ปลดบล็อก)
  static Future<bool> enableApp(String packageName) async {
    try {
      await runCommand("pm enable $packageName");
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<dynamic>> getDisabledApps() async {
    try {
      final List<dynamic> result = await platform.invokeMethod(
        'getDisabledApps',
      );
      return result;
    } catch (e) {
      return [];
    }
  }

  // เปิดโหมด Auto Clean
  static Future<void> startAutoCleaner(int thresholdMb) async {
    try {
      await platform.invokeMethod('startAutoCleaner', {
        "threshold": thresholdMb,
      });
    } catch (_) {}
  }

  // ปิดโหมด Auto Clean
  static Future<void> stopAutoCleaner() async {
    try {
      await platform.invokeMethod('stopAutoCleaner');
    } catch (_) {}
  }

  static Future<bool> isAutoCleanerRunning() async {
    try {
      final bool result = await platform.invokeMethod('isAutoCleanerRunning');
      return result;
    } catch (_) {
      return false;
    }
  }

  static Future<int> getAutoCleanerThreshold() async {
    try {
      final int result = await platform.invokeMethod('getAutoCleanerThreshold');
      return result;
    } catch (_) {
      return 500; // ถ้า error ให้คืนค่า 500
    }
  }

  static Future<void> saveAutoCleanerThreshold(int threshold) async {
    try {
      await platform.invokeMethod('saveAutoCleanerThreshold', {
        "threshold": threshold,
      });
    } catch (_) {}
  }
}
