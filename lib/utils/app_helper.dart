import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

class AppHelper {
  static Future<List<AppInfo>> getInstalledAppsWithIcons() async {
    // ดึงเฉพาะแอปที่ผู้ใช้ลงเอง (exclude system apps)
    return await InstalledApps.getInstalledApps(
      true, // includeIcon
      false, // excludeSystemApps
    );
  }
}
