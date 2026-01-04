import 'dart:typed_data';
import 'package:flutter_device_apps/flutter_device_apps.dart';

class AppHelper {
  /// 1. ดึงรายชื่อแอป (โหลดเร็ว: ไม่เอารูป)
  static Future<List<AppInfo>> getInstalledApps() async {
    return await FlutterDeviceApps.listApps(
      includeSystem: true, // เอา System Apps ด้วย (ตามโจทย์ Optimizer)
      onlyLaunchable: false, // เอา Service/Background apps ด้วย
      includeIcons: false, // สำคัญ: false เพื่อความเร็ว
    );
  }

  /// 2. ดึงรูปไอคอน (Lazy Load)
  static Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      // สั่ง includeIcon: true เพื่อดึงรูป
      final app = await FlutterDeviceApps.getApp(
        packageName,
        includeIcon: true,
      );

      // *** จุดที่แก้: ใช้ .iconBytes ตามเอกสาร ***
      return app?.iconBytes;
    } catch (e) {
      return null;
    }
  }

  /// 3. ดึงชื่อแอป
  static Future<String> getAppName(String packageName) async {
    try {
      final app = await FlutterDeviceApps.getApp(
        packageName,
        includeIcon: false,
      );
      return app?.appName ?? packageName;
    } catch (e) {
      return packageName;
    }
  }
}
