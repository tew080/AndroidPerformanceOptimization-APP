import 'shizuku_service.dart';
import '../utils/console_logger.dart';

/// ตัวจัดการคิวงาน (Task Executor)
class ExecutorService {
  static bool _stopRequested = false;

  /// สั่งหยุดการทำงานทั้งหมดทันที
  static void stop() {
    _stopRequested = true;
    ShizukuService.cancelCurrentCommand(); // Kill shell process
    ShizukuService.stopService(); // ปิด Notification
    ConsoleLogger().stopLoading(); // หยุด Animation หน้าจอ
  }

  /// ฟังก์ชันรันชุดคำสั่งทั่วไป (แสดงผลใน Console)
  static Future<void> executeScript(String label, List<String> commands) async {
    final logger = ConsoleLogger();
    _stopRequested = false;

    logger.clear();
    logger.info("Starting: $label");
    logger.info("--------------------------------");
    logger.startLoading();

    // เริ่ม Background Service (Notification)
    await ShizukuService.startService("Preparing Compilation...");

    // ตรวจสอบสิทธิ์ก่อนเริ่ม
    bool hasPermission = await ShizukuService.checkPermission();
    if (!hasPermission) {
      logger.error("Shizuku Permission Denied!");
      logger.stopLoading();
      return;
    }

    try {
      for (String cmd in commands) {
        if (_stopRequested) {
          logger.error("🛑 Operation Cancelled");
          break;
        }

        logger.cmd(cmd);
        // หน่วงเวลาเล็กน้อยเพื่อความสวยงาม (Optional)
        await Future.delayed(const Duration(milliseconds: 200));

        String result = await ShizukuService.runCommand(cmd);
        if (result.trim().isNotEmpty) {
          logger.log(result.trim());
        }
      }

      if (!_stopRequested) {
        logger.success("Operation Finished!");
      }
    } catch (e) {
      logger.error("Error: $e");
    } finally {
      logger.stopLoading();
      await ShizukuService.stopService(); // ปิด Notification เมื่อจบ
    }
  }

  /// ฟังก์ชัน Compile AOT (ทำงานนาน + มี Notification)
  static Future<void> compileAllApps(String mode) async {
    final logger = ConsoleLogger();
    _stopRequested = false;

    logger.clear();
    logger.info("Starting AOT Compilation ($mode)...");
    logger.startLoading();

    // เริ่ม Background Service (Notification)
    await ShizukuService.startService("Preparing Compilation...");

    try {
      bool hasPermission = await ShizukuService.checkPermission();
      if (!hasPermission) {
        logger.error("Permission Denied");
        return;
      }

      // 1. ดึงรายชื่อแอพ User (-3)
      String listOutput = await ShizukuService.runCommand(
        "pm list packages -3",
      );

      if (_stopRequested) return;

      List<String> packages = listOutput
          .split('\n')
          .where((line) => line.startsWith('package:'))
          .map((line) => line.replaceAll('package:', '').trim())
          .toList();

      logger.info("Found ${packages.length} user apps.");

      int count = 0;
      for (String pkg in packages) {
        if (_stopRequested) break;

        count++;
        // อัปเดตทั้ง Console และ Notification
        String statusMsg = "Compiling $count/${packages.length}";
        logger.cmd("$statusMsg: $pkg");
        await ShizukuService.updateService(statusMsg, count, packages.length);

        // คำสั่ง Compile
        await ShizukuService.runCommand("cmd package compile -m $mode -f $pkg");
      }

      if (!_stopRequested) {
        logger.success("✅ All Compilation Finished!");
        await ShizukuService.updateService(
          "Done!",
          packages.length,
          packages.length,
        );
        await Future.delayed(const Duration(seconds: 2)); // โชว์ว่าเสร็จแป๊บนึง
      } else {
        logger.error("🛑 Cancelled by User");
      }
    } catch (e) {
      logger.error("Error: $e");
    } finally {
      logger.stopLoading();
      await ShizukuService.stopService(); // ปิด Notification เมื่อจบ
    }
  }

  // [เพิ่มใหม่] ฟังก์ชันสำหรับตั้งค่า Skia แล้ว Restart Apps + SystemUI
  static Future<void> applySkiaAndRestart(
    String label,
    List<String> skiaCommands,
  ) async {
    final logger = ConsoleLogger();
    _stopRequested = false;

    logger.clear();
    logger.info("Applying: $label");
    logger.startLoading();

    try {
      // 1. ตรวจสอบสิทธิ์
      bool hasPermission = await ShizukuService.checkPermission();
      if (!hasPermission) {
        logger.error("Permission Denied");
        return;
      }

      // 2. รันคำสั่งตั้งค่า Skia (Set Props)
      logger.info("Setting properties...");
      for (String cmd in skiaCommands) {
        if (_stopRequested) break;
        logger.cmd(cmd);
        await ShizukuService.runCommand(cmd);
      }

      if (_stopRequested) {
        logger.error("🛑 Operation Cancelled");
        return;
      }

      // 3. ดึงรายชื่อแอพทั้งหมดเพื่อเตรียม Force Stop (Reload)
      logger.info("Fetching running apps to reload...");
      String listOutput = await ShizukuService.runCommand("pm list packages");

      // แปลงเป็น List ชื่อ Package
      List<String> packages = listOutput
          .split('\n')
          .where((line) => line.startsWith('package:'))
          .map((line) => line.replaceAll('package:', '').trim())
          .toList();

      // ชื่อ package ของแอพเราเอง (ต้องตรงกับใน build.gradle / AndroidManifest)
      // *สำคัญ* เพื่อไม่ให้แอพฆ่าตัวเองตาย
      const String myPackage = "com.example.apo";

      int count = 0;
      logger.info("Reloading apps (Force Stop)...");

      // 4. วนลูป Force Stop ทีละแอพ (ยกเว้นตัวเอง)
      for (String pkg in packages) {
        if (_stopRequested) break;

        // ถ้าเป็นแอพตัวเอง ให้ข้ามไป
        if (pkg == myPackage) continue;

        // (Optional) ข้ามแอพ System สำคัญๆ ได้ถ้าต้องการ แต่ใน Batch ต้นฉบับเขา Kill หมด
        // if (pkg == "com.android.systemui") continue;

        count++;
        // ไม่ต้อง Log ทุกบรรทัดก็ได้ถ้าเยอะไป จะได้เร็วขึ้น
        if (count % 5 == 0) logger.log("Reloading: $pkg");

        await ShizukuService.runCommand("am force-stop $pkg");
      }

      // 5. Restart SystemUI
      if (!_stopRequested) {
        logger.info("Forcing crash: System UI (to apply changes)");
        await Future.delayed(const Duration(seconds: 1));

        // คำสั่ง Crash SystemUI เพื่อให้มัน Restart
        await ShizukuService.runCommand("am crash com.android.systemui");

        logger.success("✅ Done! System UI should restart now.");
      }
    } catch (e) {
      logger.error("Error: $e");
    } finally {
      logger.stopLoading();
    }
  }
}
