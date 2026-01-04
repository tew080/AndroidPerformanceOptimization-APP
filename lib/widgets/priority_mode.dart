import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart'; // Import เพื่อใช้ Class AppInfo
import '../services/performance_service.dart';
import '../utils/app_helper.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  Set<String> _selectedPackages = {};

  // เก็บ List ของ Package Name แทน Object ก้อนใหญ่
  List<String> _allPackageNames = [];

  // Cache สำหรับเก็บรูปที่โหลดเสร็จแล้ว
  final Map<String, Uint8List?> _iconCache = {};
  // Cache สำหรับชื่อแอป (โหลดมารอไว้เลยเพราะ Text ไฟล์เล็ก โหลดเร็ว)
  final Map<String, String> _nameCache = {};

  String _searchQuery = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);

    try {
      // 1. โหลด List ที่เคย Boost ไว้
      final savedPackages = await PerformanceService.loadBoostedPackages();

      // 2. โหลดรายชื่อแอป (ใช้ AppHelper ตัวใหม่)
      // getInstalledApps() จะคืนค่า List<AppInfo> โดยยังไม่มี icon data (เร็ว)
      final List<AppInfo> apps = await AppHelper.getInstalledApps();

      final List<String> pkgList = [];
      final Map<String, String> nameMap = {};

      for (var app in apps) {
        // เช็ค Null Safety ตามมาตรฐาน library ใหม่
        if (app.packageName != null) {
          final String pkg = app.packageName!;
          // ถ้าไม่มีชื่อแอป ให้ใช้ package name แทน
          final String name = app.appName ?? pkg;

          pkgList.add(pkg);
          nameMap[pkg] = name;
        }
      }

      if (mounted) {
        setState(() {
          _selectedPackages = savedPackages;
          _allPackageNames = pkgList; // เก็บแค่ List String
          _nameCache.addAll(nameMap); // เก็บชื่อเข้า Cache เลย
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading apps: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Lazy Load Icon: ดึงรูปเมื่อต้องแสดงผลเท่านั้น
  Future<Uint8List?> _getAppIconLazy(String packageName) async {
    if (_iconCache.containsKey(packageName)) {
      return _iconCache[packageName];
    }
    // เรียกฟังก์ชันดึงรูปจาก AppHelper (ซึ่งเราแก้เป็น .iconBytes แล้ว)
    final icon = await AppHelper.getAppIcon(packageName);
    if (mounted && icon != null) {
      _iconCache[packageName] = icon;
    }
    return icon;
  }

  void _toggleAppSelection(String pkg, bool isSelected) async {
    await PerformanceService.toggleAppBoost(pkg, isSelected, _selectedPackages);
    setState(() {});

    if (_selectedPackages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All optimizations stopped (Normal Mode)"),
            backgroundColor: Colors.grey,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _resetAll() async {
    for (var pkg in _selectedPackages.toList()) {
      await PerformanceService.unboostSpecificApp(pkg);
    }
    _selectedPackages.clear();
    await PerformanceService.disableSystemPerformanceMode();
    // เรียก toggle แบบ dummy เพื่อให้มั่นใจว่า save state ล่าสุดแล้ว
    await PerformanceService.toggleAppBoost("dummy", false, _selectedPackages);

    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Performance mode reset to Balanced")),
      );
    }
  }

  // Widget สร้าง Icon แบบ Asynchronous
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
            gaplessPlayback: true, // ลดอาการกระพริบ
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.android, size: 35, color: Colors.grey),
          );
        }
        // ระหว่างรอโหลด หรือถ้าไม่มีรูป
        return const Icon(Icons.android, size: 35, color: Colors.green);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isSystemBoosted = _selectedPackages.isNotEmpty;

    // Filter จาก _allPackageNames โดยใช้ชื่อจาก _nameCache
    final filteredPackages = _allPackageNames.where((pkg) {
      final name = (_nameCache[pkg] ?? "").toLowerCase();
      final query = _searchQuery.toLowerCase();
      return pkg.toLowerCase().contains(query) || name.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Game / App Booster"),
        actions: [
          TextButton(
            onPressed: isSystemBoosted ? _resetAll : null,
            child: Text(
              "Reset",
              style: TextStyle(
                color: isSystemBoosted ? Colors.redAccent : Colors.grey,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- 1. Status Card ---
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isSystemBoosted
                        ? Colors.redAccent.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSystemBoosted
                          ? Colors.redAccent.withOpacity(0.5)
                          : Colors.green.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSystemBoosted
                            ? Icons.local_fire_department
                            : Icons.eco,
                        color: isSystemBoosted
                            ? Colors.redAccent
                            : Colors.green,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Current Mode:",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              isSystemBoosted
                                  ? "HIGH PERFORMANCE"
                                  : "BALANCED / POWER SAVE",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSystemBoosted
                                    ? Colors.redAccent
                                    : Colors.green,
                                fontSize: 16,
                              ),
                            ),
                            if (isSystemBoosted)
                              Text(
                                "Boosting ${_selectedPackages.length} apps",
                                style: const TextStyle(fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      if (isSystemBoosted)
                        const Badge(
                          label: Text("ACTIVE"),
                          backgroundColor: Colors.redAccent,
                        ),
                    ],
                  ),
                ),

                // --- 2. Search Bar ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search app to boost...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),

                const SizedBox(height: 10),

                // --- 3. List Item ---
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredPackages.length,
                    cacheExtent: 100, // ช่วยให้ scroll ลื่นขึ้น
                    itemBuilder: (context, index) {
                      final pkg = filteredPackages[index];
                      final name = _nameCache[pkg] ?? pkg;
                      final isChecked = _selectedPackages.contains(pkg);

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? Colors.redAccent.withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: CheckboxListTile(
                          activeColor: Colors.redAccent,
                          // ใช้ Lazy Load Widget ที่เราสร้างไว้
                          secondary: _buildAppIcon(pkg),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: isChecked
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isChecked ? Colors.redAccent : null,
                            ),
                          ),
                          subtitle: Text(
                            pkg,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          value: isChecked,
                          onChanged: (bool? value) {
                            if (value != null) {
                              _toggleAppSelection(pkg, value);
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
    );
  }
}
