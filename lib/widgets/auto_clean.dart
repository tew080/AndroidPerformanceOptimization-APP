import 'package:flutter/material.dart';
import '../services/shizuku_service.dart';

class AutoCleanScreen extends StatefulWidget {
  const AutoCleanScreen({super.key});

  @override
  State<AutoCleanScreen> createState() => _AutoCleanScreenState();
}

class _AutoCleanScreenState extends State<AutoCleanScreen> {
  bool _isEnabled = false;
  double _threshold = 500; // ค่าเริ่มต้น 500 MB

  @override
  void initState() {
    super.initState();
    _checkServiceStatus(); // <--- เรียกฟังก์ชันเช็คสถานะ
  }

  // ฟังก์ชันเช็คสถานะจริงจาก Android
  Future<void> _checkServiceStatus() async {
    // 1. เช็คว่ารันอยู่ไหม
    bool running = await ShizukuService.isAutoCleanerRunning();

    // 2. ดึงค่า MB ที่เคยตั้งไว้ (ไม่ว่าจะรันอยู่หรือไม่ ก็ควรดึงค่าล่าสุดมาโชว์)
    int savedThreshold = await ShizukuService.getAutoCleanerThreshold();

    if (mounted) {
      setState(() {
        _isEnabled = running;
        _threshold = savedThreshold
            .toDouble(); // อัปเดต Slider ให้ตรงกับค่าเดิม
      });
    }
  }

  void _toggleService(bool value) {
    setState(() {
      _isEnabled = value;
    });

    if (_isEnabled) {
      // เปิดใช้งาน ส่งค่า Threshold ไปด้วย
      ShizukuService.startAutoCleaner(_threshold.toInt());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Auto-Clean STARTED (< ${_threshold.toInt()} MB)"),
        ),
      );
    } else {
      // ปิดใช้งาน
      ShizukuService.stopAutoCleaner();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Auto-Clean STOPPED")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Auto RAM Cleaner")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // การ์ดแสดงสถานะ
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isEnabled
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: _isEnabled ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEnabled ? Icons.autorenew : Icons.power_settings_new,
                    color: _isEnabled ? Colors.greenAccent : Colors.redAccent,
                    size: 40,
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEnabled ? "Status: ACTIVE" : "Status: INACTIVE",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _isEnabled
                            ? "Cleaning when RAM < ${_threshold.toInt()} MB"
                            : "Service is stopped",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Switch เปิด/ปิด
            SwitchListTile(
              title: const Text("Enable Auto-Clean"),
              subtitle: const Text("Keep monitoring RAM in background"),
              value: _isEnabled,
              activeColor: Colors.greenAccent,
              onChanged: _toggleService,
            ),

            const Divider(height: 40),

            // Slider ปรับค่า
            const Text(
              "Trigger Threshold (MB)",
              style: TextStyle(color: Colors.greenAccent, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              "${_threshold.toInt()} MB",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _threshold,
              min: 100,
              max: 1000,
              divisions: 19,
              activeColor: Colors.greenAccent,
              label: "${_threshold.toInt()} MB",
              onChanged: _isEnabled
                  ? null // ห้ามปรับตอนรันอยู่ (ต้องปิดก่อนค่อยปรับ)
                  : (value) {
                      setState(() {
                        _threshold = value;
                      });
                    },
              // 2. [เพิ่ม] เมื่อปล่อยมือ ให้บันทึกค่าทันที
              onChangeEnd: (value) async {
                int val = value.toInt();

                // บันทึกค่าลงเมมโมรี่ทันที (ไม่ว่าจะเปิดหรือปิดอยู่)
                await ShizukuService.saveAutoCleanerThreshold(val);

                // ถ้า Service เปิดอยู่ ให้ Restart Service ใหม่ด้วยค่าใหม่ทันที (Real-time update)
                if (_isEnabled) {
                  await ShizukuService.startAutoCleaner(val);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Updated threshold to $val MB"),
                        duration: const Duration(milliseconds: 1000),
                      ),
                    );
                  }
                }
              },
            ),

            // ลบข้อความเตือนสีส้มเดิมทิ้ง (เพราะเราปรับได้ตลอดแล้ว)
            const Text(
              "You can adjust this anytime. System will update immediately.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),

            if (_isEnabled)
              const Text(
                "Stop service to adjust threshold",
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),

            const Spacer(),
            const Text(
              "Note: System will detect the current game/app (Top App) and kill other background apps automatically.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
