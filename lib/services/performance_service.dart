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

  // ---------------------------------------------------------

  static Future<void> enableSystemPerformanceMode() async {
    await ShizukuService.runCommand('cmd power set-mode 0');
    await ShizukuService.runCommand(
      'device_config put activity_manager max_cached_processes 1',
    );
  }

  static Future<void> disableSystemPerformanceMode() async {
    await ShizukuService.runCommand('cmd power set-mode 1');
    await ShizukuService.runCommand(
      'device_config delete activity_manager max_cached_processes',
    );
  }

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

  /// ฟังก์ชันใหม่: เรียกใช้เพื่อ Toggle และบันทึกค่าทันที
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

    // บันทึกค่าลงเครื่อง
    await _saveBoostedPackages(currentList);

    // จัดการ System Mode
    if (currentList.isNotEmpty) {
      await enableSystemPerformanceMode();
    } else {
      await disableSystemPerformanceMode();
    }
  }
}
