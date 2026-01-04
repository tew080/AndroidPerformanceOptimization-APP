import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import '../services/performance_service.dart';
import '../utils/app_helper.dart';

class PerformanceScreen extends StatefulWidget {
  // 1. เพิ่มตัวแปรรับฟังก์ชัน Callback แบบเดียวกับ NetworkPriorityScreen
  final Function(String, List<String>) onRun;

  const PerformanceScreen({super.key, required this.onRun});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  Set<String> _selectedPackages = {};
  List<String> _allPackageNames = [];
  final Map<String, Uint8List?> _iconCache = {};
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
      final savedPackages = await PerformanceService.loadBoostedPackages();
      final List<AppInfo> apps = await AppHelper.getInstalledApps();
      final List<String> pkgList = [];
      final Map<String, String> nameMap = {};

      for (var app in apps) {
        if (app.packageName != null) {
          final String pkg = app.packageName!;
          final String name = app.appName ?? pkg;
          pkgList.add(pkg);
          nameMap[pkg] = name;
        }
      }

      if (mounted) {
        setState(() {
          _selectedPackages = savedPackages;
          _allPackageNames = pkgList;
          _nameCache.addAll(nameMap);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading apps: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Uint8List?> _getAppIconLazy(String packageName) async {
    if (_iconCache.containsKey(packageName)) {
      return _iconCache[packageName];
    }
    final icon = await AppHelper.getAppIcon(packageName);
    if (mounted && icon != null) {
      _iconCache[packageName] = icon;
    }
    return icon;
  }

  // --- ส่วนที่แก้ไข Logic การทำงาน ---
  void _toggleAppSelection(String pkg, bool isSelected) async {
    // 1. อัปเดต UI ทันที
    setState(() {
      if (isSelected) {
        _selectedPackages.add(pkg);
      } else {
        _selectedPackages.remove(pkg);
      }
    });

    // 2. สร้างคำสั่ง Shell สำหรับแสดงใน Console
    // (คุณสามารถปรับแต่งคำสั่งพวกนี้ตาม Logic จริงใน OptimizerLogic หรือ PerformanceService ได้)
    List<String> commands = [];
    String appName = _nameCache[pkg] ?? pkg;

    if (isSelected) {
      commands.add('echo ">>> Boosting $appName ($pkg)"');
      commands.add('cmd package compile -m speed $pkg');
      commands.add('am set-standby-bucket $pkg active');
      commands.add('echo "Success: $appName is now boosted."');
    } else {
      commands.add('echo ">>> Resetting $appName"');
      commands.add('cmd package compile -m verify $pkg');
      commands.add('echo "Success: $appName returned to normal mode."');
    }

    // 3. เรียก callback onRun เพื่อเปิดหน้าต่าง Console
    widget.onRun(isSelected ? "Boost: $appName" : "Reset: $appName", commands);

    // 4. บันทึกค่าลง SharedPreferences (เรียก Service เดิม)
    await PerformanceService.toggleAppBoost(pkg, isSelected, _selectedPackages);

    if (_selectedPackages.isEmpty && !isSelected) {
      // แจ้งเตือนเพิ่มเติมเมื่อไม่มีแอปเลือกแล้ว
    }
  }

  void _resetAll() async {
    // สร้างคำสั่ง Reset ทั้งหมด
    List<String> commands = [];
    commands.add('echo ">>> Resetting All Performance Settings"');

    for (var pkg in _selectedPackages) {
      commands.add('cmd package compile -m verify $pkg');
    }
    commands.add('echo "All apps reset to default compilation mode."');

    // เรียก Console
    widget.onRun("Reset All Boosters", commands);

    // ล้างค่าในตัวแปรและ Service
    _selectedPackages.clear();
    await PerformanceService.disableSystemPerformanceMode();
    // เรียก toggle dummy เพื่อ save state ว่าว่างเปล่า
    await PerformanceService.toggleAppBoost("dummy", false, _selectedPackages);

    setState(() {});
  }
  // ------------------------------------

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
        return const Icon(Icons.android, size: 35, color: Colors.green);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isSystemBoosted = _selectedPackages.isNotEmpty;
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
                // Status Card (คงเดิม)
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
                    ],
                  ),
                ),

                // Search Bar (คงเดิม)
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

                // List Items (เรียก _toggleAppSelection ที่แก้แล้ว)
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredPackages.length,
                    cacheExtent: 100,
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
