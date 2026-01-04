import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import '../utils/Optimizer_Logic.dart';
import '../utils/app_helper.dart';

class NetworkPriorityScreen extends StatefulWidget {
  final Function(String, List<String>) onRun;

  const NetworkPriorityScreen({super.key, required this.onRun});

  // ใช้ static เพื่อจำสถานะข้ามการเปิด-ปิดหน้าจอ
  static String? activePriorityPkg;
  static String? activePriorityName;

  @override
  State<NetworkPriorityScreen> createState() => _NetworkPriorityScreenState();
}

class _NetworkPriorityScreenState extends State<NetworkPriorityScreen> {
  List<AppInfo> allApps = [];
  String searchQuery = "";
  String? selectedPkg;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // ดึงค่าล่าสุดที่เคยเลือกไว้มาแสดงใน Radio
    selectedPkg = NetworkPriorityScreen.activePriorityPkg;
    _loadApps();
  }

  Future<void> _loadApps() async {
    final apps = await AppHelper.getInstalledAppsWithIcons();
    setState(() {
      allApps = apps;
      isLoading = false;
    });
  }

  Widget _buildAppIcon(Uint8List? iconBytes) {
    if (iconBytes == null || iconBytes.isEmpty) {
      return const Icon(Icons.android, size: 35, color: Colors.green);
    }
    return Image.memory(
      iconBytes,
      width: 35,
      height: 35,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.android, size: 35, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = allApps.where((app) {
      final name = (app.name ?? "").toLowerCase();
      final package = (app.packageName ?? "").toLowerCase();
      return name.contains(searchQuery.toLowerCase()) ||
          package.contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Network Priority"),
        actions: [
          TextButton(
            onPressed: () {
              widget.onRun(
                "Reset Network",
                OptimizerLogic.getResetNetworkCommands(),
              );
              setState(() {
                NetworkPriorityScreen.activePriorityPkg = null;
                NetworkPriorityScreen.activePriorityName = null;
                selectedPkg = null;
              });
              // แจ้งเตือนเมื่อรีเซ็ต
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Network restriction disabled")),
              );
            },
            child: const Text(
              "Reset",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- การ์ดแสดงสถานะ Active ---
                if (NetworkPriorityScreen.activePriorityPkg != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blueAccent.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt, color: Colors.orange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Currently Prioritized:",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                "${NetworkPriorityScreen.activePriorityName}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Badge(
                          label: Text("Running"),
                          backgroundColor: Colors.orange,
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search app name...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => setState(() => searchQuery = v),
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    itemCount: filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = filteredApps[index];
                      // เช็คว่าแอปนี้คือแอปที่กำลัง Active อยู่หรือไม่
                      final bool isCurrentlyActive =
                          NetworkPriorityScreen.activePriorityPkg ==
                          app.packageName;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentlyActive
                              ? Colors.blueAccent.withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: RadioListTile<String>(
                          secondary: _buildAppIcon(app.icon),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  app.name ?? "Unknown",
                                  style: TextStyle(
                                    fontWeight: isCurrentlyActive
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isCurrentlyActive)
                                const Badge(
                                  label: Text("ACTIVE"),
                                  backgroundColor: Colors.blueAccent,
                                ),
                            ],
                          ),
                          subtitle: Text(
                            app.packageName ?? "",
                            style: const TextStyle(fontSize: 11),
                          ),
                          value: app.packageName ?? "",
                          groupValue: selectedPkg,
                          onChanged: (v) => setState(() => selectedPkg = v),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 4,
            ),
            onPressed: selectedPkg == null
                ? null
                : () {
                    // 1. หาข้อมูลแอปที่เลือกจากลิสต์ทั้งหมด
                    final selectedApp = allApps.firstWhere(
                      (a) => a.packageName == selectedPkg,
                    );

                    // 2. อัปเดตสถานะทันทีเพื่อให้ Badge และ Card เปลี่ยนสีโดยไม่ปิดหน้าจอ
                    setState(() {
                      NetworkPriorityScreen.activePriorityPkg = selectedPkg;
                      NetworkPriorityScreen.activePriorityName =
                          selectedApp.name;
                    });

                    // 3. สั่งรันคำสั่งผ่าน Shizuku/ADB
                    widget.onRun(
                      "Priority Boost: ${selectedApp.name}",
                      OptimizerLogic.getPriorityCommands([selectedPkg!]),
                    );

                    // 4. แสดงข้อความแจ้งเตือนความสำเร็จ
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "🚀 ${selectedApp.name} is now prioritized!",
                        ),
                        backgroundColor: Colors.blueAccent,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
            child: const Text(
              "Apply Network Priority",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
