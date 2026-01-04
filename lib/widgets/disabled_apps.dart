import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart'; // Import package ใหม่เพื่อให้รู้จัก Class AppInfo
import '../services/shizuku_service.dart';
import '../utils/app_helper.dart';

class DisabledAppsScreen extends StatefulWidget {
  const DisabledAppsScreen({super.key});

  @override
  State<DisabledAppsScreen> createState() => _DisabledAppsScreenState();
}

class _DisabledAppsScreenState extends State<DisabledAppsScreen> {
  List<dynamic> _allDisabledApps = [];
  List<dynamic> _filteredApps = [];

  // Cache สำหรับเก็บรูปและชื่อ
  final Map<String, Uint8List?> _iconCache = {};
  final Map<String, String> _nameCache = {};

  String _searchQuery = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // 1. ดึงรายชื่อแอปที่ถูกปิด (Disabled Apps) จาก Shizuku
      final list = await ShizukuService.getDisabledApps();

      // 2. ดึงชื่อแอปทั้งหมดมาเทียบ (ใช้ AppHelper ตัวใหม่)
      // getInstalledApps() ตอนนี้คืนค่าเป็น List<AppInfo>
      final List<AppInfo> installedApps = await AppHelper.getInstalledApps();
      final Map<String, String> nameMap = {};

      for (var app in installedApps) {
        // AppInfo ตัวใหม่ค่าเป็น Nullable ต้องเช็คก่อน
        if (app.packageName != null) {
          nameMap[app.packageName!] = app.appName ?? app.packageName!;
        }
      }

      if (mounted) {
        setState(() {
          _allDisabledApps = list;
          _nameCache.addAll(nameMap);
          _filterApps(_searchQuery);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading disabled apps: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Lazy Load Icon: โหลดรูปเมื่อจำเป็นต้องแสดงผล
  Future<Uint8List?> _getAppIconLazy(String packageName) async {
    if (_iconCache.containsKey(packageName)) {
      return _iconCache[packageName];
    }
    // เรียกใช้ฟังก์ชันดึงรูปจาก AppHelper (ซึ่งเราแก้ให้ใช้ .iconBytes แล้ว)
    final icon = await AppHelper.getAppIcon(packageName);
    if (mounted && icon != null) {
      _iconCache[packageName] = icon;
    }
    return icon;
  }

  void _filterApps(String query) {
    setState(() {
      _searchQuery = query;
      _filteredApps = _allDisabledApps.where((app) {
        final pkg = (app['pkg'] as String).toLowerCase();
        // ค้นหาจากชื่อใน Cache หรือใช้ pkg name ถ้าไม่มีชื่อ
        final name = (_nameCache[pkg] ?? pkg).toLowerCase();
        return pkg.contains(query.toLowerCase()) ||
            name.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _enableApp(String pkgName) async {
    String appLabel = _nameCache[pkgName] ?? pkgName;
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Restore App"),
        content: Text("Do you want to enable '$appLabel' again?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Enable", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // เรียก Service เพื่อ Enable แอป
      await ShizukuService.enableApp(pkgName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("App Enabled Successfully")),
        );
        _loadData(); // Reload list
      }
    }
  }

  // Widget สร้าง Icon
  Widget _buildAppIcon(String pkg) {
    return FutureBuilder<Uint8List?>(
      future: _getAppIconLazy(pkg),
      builder: (context, snapshot) {
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.isNotEmpty) {
          return Image.memory(
            snapshot.data!,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.android, color: Colors.grey, size: 32),
          );
        }
        // Icon สำหรับแอปที่ยังโหลดไม่เสร็จหรือไม่มีรูป
        return const Icon(Icons.block, color: Colors.grey, size: 32);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Blocked Apps")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search blocked apps...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    onChanged: _filterApps,
                  ),
                ),
                Expanded(
                  child: _filteredApps.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.check_circle_outline,
                                size: 60,
                                color: Colors.green,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "No blocked apps found",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredApps.length,
                          itemBuilder: (context, index) {
                            final item = _filteredApps[index];
                            final pkg = item['pkg'] as String;
                            final appName = _nameCache[pkg] ?? pkg;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              color: const Color(0xFF1E1E1E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                leading: _buildAppIcon(pkg),
                                title: Text(
                                  appName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration
                                        .lineThrough, // ขีดฆ่าชื่อ
                                    decorationColor: Colors.red,
                                    decorationThickness: 2.0,
                                  ),
                                ),
                                subtitle: Text(
                                  pkg,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: "Restore App",
                                  icon: const Icon(
                                    Icons.settings_backup_restore,
                                    color: Colors.greenAccent,
                                  ),
                                  onPressed: () => _enableApp(pkg),
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
