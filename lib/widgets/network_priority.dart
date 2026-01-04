import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart'; // Import เพื่อใช้ Class AppInfo
import '../utils/optimizer_logic.dart';
import '../utils/app_helper.dart';

class NetworkPriorityScreen extends StatefulWidget {
  final Function(String, List<String>) onRun;

  const NetworkPriorityScreen({super.key, required this.onRun});

  // ใช้ Static เพื่อจำค่า apps ที่เลือกไว้ แม้จะออกจากหน้านี้ไปแล้ว
  static Set<String> activePriorityPkgs = {};

  @override
  State<NetworkPriorityScreen> createState() => _NetworkPriorityScreenState();
}

class _NetworkPriorityScreenState extends State<NetworkPriorityScreen> {
  List<String> _allPackageNames = [];

  // Cache สำหรับชื่อแอป (โหลดเร็ว)
  final Map<String, String> _nameCache = {};
  // Cache สำหรับไอคอน (โหลดช้า -> ใช้ Lazy Load)
  final Map<String, Uint8List?> _iconCache = {};

  String searchQuery = "";
  Set<String> _selectedPkgs = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // ดึงค่าเก่าที่เคย Active ไว้มาแสดงผล
    _selectedPkgs = Set.from(NetworkPriorityScreen.activePriorityPkgs);
    _loadApps();
  }

  // 1. โหลดข้อมูลรายชื่อแอป (เอาแค่ชื่อกับ pkg ยังไม่เอารูป)
  Future<void> _loadApps() async {
    try {
      // เรียกใช้ AppHelper ตัวใหม่ (คืนค่าเป็น List<AppInfo>)
      final List<AppInfo> apps = await AppHelper.getInstalledApps();

      final List<String> pkgList = [];
      final Map<String, String> nameMap = {};

      for (var app in apps) {
        // เช็ค null ตามมาตรฐานใหม่
        if (app.packageName != null) {
          final String pkg = app.packageName!;
          final String name = app.appName ?? pkg;

          pkgList.add(pkg);
          nameMap[pkg] = name;
        }
      }

      if (mounted) {
        setState(() {
          _allPackageNames = pkgList;
          _nameCache.addAll(nameMap);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading apps: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 2. ฟังก์ชัน Lazy Load Icon
  Future<Uint8List?> _getAppIconLazy(String packageName) async {
    if (_iconCache.containsKey(packageName)) {
      return _iconCache[packageName];
    }
    // เรียก Helper ที่เราแก้เป็น .iconBytes แล้ว
    final icon = await AppHelper.getAppIcon(packageName);
    if (mounted && icon != null) {
      _iconCache[packageName] = icon;
    }
    return icon;
  }

  // 3. Widget สร้าง Icon แบบ Async
  Widget _buildAppIcon(String pkg) {
    return FutureBuilder<Uint8List?>(
      future: _getAppIconLazy(pkg),
      builder: (context, snapshot) {
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.isNotEmpty) {
          return Image.memory(
            snapshot.data!,
            width: 35,
            height: 35,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.android, size: 35, color: Colors.grey),
          );
        }
        return const Icon(Icons.android, size: 35, color: Colors.grey);
      },
    );
  }

  void _toggleSelection(String pkg, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedPkgs.add(pkg);
      } else {
        _selectedPkgs.remove(pkg);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filter รายชื่อตามคำค้นหา
    final filteredPackages = _allPackageNames.where((pkg) {
      final name = (_nameCache[pkg] ?? "").toLowerCase();
      final query = searchQuery.toLowerCase();
      return pkg.toLowerCase().contains(query) || name.contains(query);
    }).toList();

    bool isSystemActive = NetworkPriorityScreen.activePriorityPkgs.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Network Priority"),
        actions: [
          TextButton(
            onPressed: () {
              // ปุ่ม Reset (ล้างค่าทั้งหมด)
              widget.onRun(
                "Reset Network",
                OptimizerLogic.getResetNetworkCommands(),
              );
              setState(() {
                NetworkPriorityScreen.activePriorityPkgs.clear();
                _selectedPkgs.clear();
              });
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
                if (isSystemActive)
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
                        const Icon(Icons.bolt, color: Colors.orange, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Network Priority Active",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                "${NetworkPriorityScreen.activePriorityPkgs.length} Apps Prioritized",
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

                // --- Search Bar ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search app name...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    onChanged: (v) => setState(() => searchQuery = v),
                  ),
                ),

                // --- Selection Info ---
                if (_selectedPkgs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Selected: ${_selectedPkgs.length} apps",
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // --- List ---
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredPackages.length,
                    cacheExtent: 100, // ช่วยให้ scroll ลื่น
                    itemBuilder: (context, index) {
                      final pkg = filteredPackages[index];
                      final name = _nameCache[pkg] ?? pkg;

                      final bool isSelected = _selectedPkgs.contains(pkg);
                      final bool isCurrentlyRunning = NetworkPriorityScreen
                          .activePriorityPkgs
                          .contains(pkg);

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentlyRunning
                              ? Colors.blueAccent.withOpacity(0.1)
                              : (isSelected
                                    ? Colors.grey.withOpacity(0.1)
                                    : Colors.transparent),
                          borderRadius: BorderRadius.circular(10),
                          border: isCurrentlyRunning
                              ? Border.all(
                                  color: Colors.blueAccent.withOpacity(0.3),
                                )
                              : null,
                        ),
                        child: CheckboxListTile(
                          activeColor: Colors.blueAccent,
                          // ใช้ Lazy Load Icon Widget
                          secondary: _buildAppIcon(pkg),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: isSelected || isCurrentlyRunning
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isCurrentlyRunning
                                  ? Colors.blueAccent
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            pkg,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          value: isSelected,
                          onChanged: (bool? value) {
                            if (value != null) {
                              _toggleSelection(pkg, value);
                            }
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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
            onPressed: _selectedPkgs.isEmpty
                ? null
                : () {
                    // Save Active State
                    setState(() {
                      NetworkPriorityScreen.activePriorityPkgs = Set.from(
                        _selectedPkgs,
                      );
                    });

                    // สร้างข้อความ Log สวยๆ
                    final selectedNames = _allPackageNames
                        .where((pkg) => _selectedPkgs.contains(pkg))
                        .map((pkg) => _nameCache[pkg] ?? pkg)
                        .take(3)
                        .join(", ");

                    final suffix = _selectedPkgs.length > 3 ? "..." : "";

                    // ส่งคำสั่งไปทำงาน
                    widget.onRun(
                      "Multi-Priority: ${_selectedPkgs.length} apps",
                      OptimizerLogic.getPriorityCommands(
                        _selectedPkgs.toList(),
                      ),
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "🚀 Prioritizing: $selectedNames $suffix",
                        ),
                        backgroundColor: Colors.blueAccent,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
            child: Text(
              "Apply Priority (${_selectedPkgs.length})",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
