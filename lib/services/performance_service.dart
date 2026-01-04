import 'package:shared_preferences/shared_preferences.dart';
import 'shizuku_service.dart';

class PerformanceService {
  static const String _prefKey = 'boosted_apps_list';

  /// โหลดรายชื่อแอพที่เคยบันทึกไว้
  static Future<Set<String>> loadBoostedPackages() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? saved = prefs.getStringList(_prefKey);
    return saved?.toSet() ?? {};
  }

  /// บันทึกรายชื่อแอพลงเครื่อง
  static Future<void> _saveBoostedPackages(Set<String> packages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefKey, packages.toList());
  }

  // =========================================================
  // ส่วนเปิดโหมดประสิทธิภาพ (Apply Settings)
  // =========================================================

  static Future<void> enableSystemPerformanceMode() async {
    // 1. Fixed Performance Mode (High Priority)
    // บังคับให้ CPU ทำงานในโหมดประสิทธิภาพสูงสุด
    await ShizukuService.runCommand(
      'cmd power set-fixed-performance-mode-enabled true',
    );
    await ShizukuService.runCommand(
      'cmd power set-mode 0',
    ); // 0 = Interactive/Performance

    // 2. ปิด Animation ทั้งหมด (Visual Speed)
    await ShizukuService.runCommand(
      'settings put global window_animation_scale 0.0',
    );
    await ShizukuService.runCommand(
      'settings put global transition_animation_scale 0.0',
    );
    await ShizukuService.runCommand(
      'settings put global animator_duration_scale 0.0',
    );

    // 3. ปิด Effect เบลอและโปร่งใส (ลดภาระ GPU)
    await ShizukuService.runCommand(
      'settings put global disable_window_blurs 1',
    );
    await ShizukuService.runCommand(
      'settings put global accessibility_reduce_transparency 1',
    );

    // 4. ปรับแต่ง Network (ลด Ping / Latency)
    await ShizukuService.runCommand('settings put global wifi_power_save 0');
    await ShizukuService.runCommand(
      'settings put global mobile_data_always_on 1',
    ); // เปิด Data รอไว้สลับเร็ว

    // 5. ปิด Logs และ Bloatware features (ลดการเขียนไฟล์ background)
    await ShizukuService.runCommand(
      'settings put system send_security_reports 0',
    );
    await ShizukuService.runCommand(
      'settings put secure send_action_app_error 0',
    );
    await ShizukuService.runCommand(
      'settings put global activity_starts_logging_enabled 0',
    );

    // 6. การจัดการ Memory & Power
    await ShizukuService.runCommand(
      'device_config put activity_manager max_cached_processes 1',
    );
    // ปิด Intelligent sleep เพื่อไม่ให้ตัดเน็ตหรือลด cpu เวลาเล่นเกมนานๆ
    await ShizukuService.runCommand(
      'settings put system intelligent_sleep_mode 0',
    );
    await ShizukuService.runCommand(
      'settings put global adaptive_battery_management_enabled 0',
    );

    // 7. Samsung Specific (ถ้าไม่ใช่ Samsung จะไม่เกิด error แต่ไม่มีผล)
    // ปิด Game Optimization Service (GOS) บางส่วน
    await ShizukuService.runCommand(
      'settings put secure game_auto_temperature_control 0',
    );
    await ShizukuService.runCommand('settings put secure game_home_enable 0');
  }

  // =========================================================
  // ส่วนคืนค่าเริ่มต้น (Revert Settings / Restore Defaults)
  // ใช้คำสั่ง 'settings delete' เพื่อให้ระบบกลับไปใช้ค่า Default
  // =========================================================

  static Future<void> disableSystemPerformanceMode() async {
    // 1. คืนค่า Power Mode
    // ปิดโหมด Fixed Performance
    await ShizukuService.runCommand(
      'cmd power set-fixed-performance-mode-enabled false',
    );

    // 2. คืนค่า Animation กลับเป็น 1.0 (ค่ามาตรฐานของ Android)
    await ShizukuService.runCommand(
      'settings put global window_animation_scale 1.0',
    );
    await ShizukuService.runCommand(
      'settings put global transition_animation_scale 1.0',
    );
    await ShizukuService.runCommand(
      'settings put global animator_duration_scale 1.0',
    );

    // 3. คืนค่า GPU Effects (เปิดกลับมาให้สวยงามเหมือนเดิม)
    // disable_window_blurs = 0 หมายถึง "ไม่ต้องปิดเบลอ" (คือให้มีเบลอตามปกติ)
    await ShizukuService.runCommand(
      'settings put global disable_window_blurs 0',
    );
    // accessibility_reduce_transparency = 0 หมายถึง "ไม่ต้องลดความโปร่งใส"
    await ShizukuService.runCommand(
      'settings put global accessibility_reduce_transparency 0',
    );

    // 4. คืนค่า Network
    // wifi_power_save = 1 (เปิดโหมดประหยัดไฟ WiFi ตามปกติของระบบ)
    await ShizukuService.runCommand('settings put global wifi_power_save 1');
    // mobile_data_always_on = 0 (ปิดเน็ตมือถือเมื่อต่อ WiFi เพื่อประหยัดแบต - ค่า Default ทั่วไป)
    await ShizukuService.runCommand(
      'settings put global mobile_data_always_on 0',
    );

    // 5. คืนค่า Logs (เปิดกลับมาเผื่อระบบต้องการใช้ - หรือจะปล่อยปิดไว้ก็ได้ แต่เพื่อความ Original ให้เปิดคืน)
    // หมายเหตุ: ค่าพวกนี้บางเครื่อง Default คือ 0 หรือ 1 ต่างกันไป
    // แต่การ delete ตรงนี้ปลอดภัยกว่าเพราะ user ทั่วไปไม่ได้ไปยุ่ง
    // *แต่ถ้าจะเอาชัวร์ ให้ delete เหมือนเดิมสำหรับพวก Log*
    await ShizukuService.runCommand(
      'settings delete system send_security_reports',
    );
    await ShizukuService.runCommand(
      'settings delete secure send_action_app_error',
    );
    await ShizukuService.runCommand(
      'settings delete global activity_starts_logging_enabled',
    );

    // 6. คืนค่า Memory & Power
    // ลบ config ที่เรายัดไปเพื่อให้ระบบจัดการเอง
    await ShizukuService.runCommand(
      'device_config delete activity_manager max_cached_processes',
    );

    // intelligent_sleep_mode ส่วนใหญ่ default คือ 1 (เปิด) หรือลบทิ้งเพื่อให้ระบบจัดการ
    // ถ้าจะเอาชัวร์ลองใส่ 1 แต่ถ้าไม่ชัวร์ delete ดีกว่าสำหรับค่า System Specific
    await ShizukuService.runCommand(
      'settings delete system intelligent_sleep_mode',
    );

    // Adaptive Battery ปกติจะเปิด (1)
    await ShizukuService.runCommand(
      'settings put global adaptive_battery_management_enabled 1',
    );

    // 7. คืนค่า Samsung Specific
    // ค่าพวกนี้ถ้าสั่งเป็นค่า Default อาจจะผิดพลาดได้ถ้าเครื่องไม่ใช่ Samsung
    // แนะนำให้ delete เหมือนเดิม หรือใส่ try-catch ถ้าจะ force value
    await ShizukuService.runCommand(
      'settings delete secure game_auto_temperature_control',
    );
    await ShizukuService.runCommand('settings delete secure game_home_enable');
  }

  // =========================================================
  // Boost เฉพาะแอพ (Logic เดิม)
  // =========================================================

  static Future<void> boostSpecificApp(String pkgName) async {
    try {
      await ShizukuService.runCommand('cmd deviceidle whitelist +$pkgName');
      await ShizukuService.runCommand('am set-standby-bucket $pkgName active');

      String pidStr = await ShizukuService.runCommand('pidof $pkgName');
      if (pidStr.trim().isNotEmpty) {
        List<String> pids = pidStr.trim().split(RegExp(r'\s+'));
        for (String pid in pids) {
          await ShizukuService.runCommand('renice -n -20 -p $pid');
          await ShizukuService.runCommand(
            'echo -1000 > /proc/$pid/oom_score_adj',
          );
        }
      }
    } catch (e) {
      print("Error boosting app: $e");
    }
  }

  static Future<void> unboostSpecificApp(String pkgName) async {
    try {
      await ShizukuService.runCommand('cmd deviceidle whitelist -$pkgName');

      String pidStr = await ShizukuService.runCommand('pidof $pkgName');
      if (pidStr.trim().isNotEmpty) {
        List<String> pids = pidStr.trim().split(RegExp(r'\s+'));
        for (String pid in pids) {
          await ShizukuService.runCommand('renice -n 0 -p $pid');
          await ShizukuService.runCommand('echo 0 > /proc/$pid/oom_score_adj');
        }
      }
    } catch (e) {
      print("Error unboosting app: $e");
    }
  }

  static Future<void> toggleAppBoost(
    String pkg,
    bool isSelected,
    Set<String> currentList,
  ) async {
    if (isSelected) {
      currentList.add(pkg);
      await boostSpecificApp(pkg);
    } else {
      currentList.remove(pkg);
      await unboostSpecificApp(pkg);
    }

    await _saveBoostedPackages(currentList);

    // Logic: ถ้ามีแอพไหนถูก Boost อยู่ แม้แต่แอพเดียว ให้เปิด System Performance Mode
    // ถ้าไม่มีแอพไหน Boost เลย ให้ปิด System Performance Mode (Revert to default)
    if (currentList.isNotEmpty) {
      await enableSystemPerformanceMode();
    } else {
      await disableSystemPerformanceMode();
    }
  }
}
