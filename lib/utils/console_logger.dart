import 'package:flutter/foundation.dart';

class ConsoleLogger {
  static final ConsoleLogger _instance = ConsoleLogger._internal();
  factory ConsoleLogger() => _instance;
  ConsoleLogger._internal();

  final ValueNotifier<List<String>> logs = ValueNotifier([]);

  // [เพิ่ม] ตัวบอกสถานะ Loading
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  void log(String message) {
    final currentLogs = List<String>.from(logs.value);
    currentLogs.add(message);
    logs.value = currentLogs;
  }

  void clear() {
    logs.value = [];
    isLoading.value = false; // Reset สถานะ
  }

  // [เพิ่ม] ฟังก์ชันเปิด/ปิด Loading
  void startLoading() => isLoading.value = true;
  void stopLoading() => isLoading.value = false;

  void info(String msg) => log("[INFO] $msg");
  void success(String msg) => log("✅ $msg");
  void error(String msg) => log("❌ $msg");
  void cmd(String msg) => log(">_ $msg");
}
