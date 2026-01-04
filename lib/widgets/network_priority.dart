import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
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
  // เราใช้ activePriorityPkgs ของ widget โดยตรงเพื่อให้สถานะตรงกันเสมอ
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  // 1. โหลดข้อมูลรายชื่อแอป
  Future<void> _loadApps() async {
    try {
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

  // --- LOGIC หลัก: ติ๊กปุ๊บ สั่งทำงานปั๊บ ---
  void _toggleSelection(String pkg, bool isSelected) {
    setState(() {
      if (isSelected) {
        NetworkPriorityScreen.activePriorityPkgs.add(pkg);
      } else {
        NetworkPriorityScreen.activePriorityPkgs.remove(pkg);
      }
    });

    // เตรียมชื่อสำหรับแจ้งเตือน (SnackBar)
    final String appName = _nameCache[pkg] ?? pkg;
    final String msg = isSelected
        ? "Added priority to $appName"
        : "Removed priority from $appName";

    // สั่งรันคำสั่งทันที!
    // เราส่ง List ทั้งหมดไปใหม่ทุกครั้งเพื่อให้แน่ใจว่า Priority ถูกต้อง
    widget.onRun(
      msg,
      OptimizerLogic.getPriorityCommands(
        NetworkPriorityScreen.activePriorityPkgs.toList(),
      ),
    );

    // แจ้งเตือนเล็กๆ
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 1),
        backgroundColor: isSelected ? Colors.blueAccent : Colors.grey,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ฟังก์ชัน Reset ทั้งหมด
  void _resetAll() {
    widget.onRun("Reset Network", OptimizerLogic.getResetNetworkCommands());
    setState(() {
      NetworkPriorityScreen.activePriorityPkgs.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Network restriction disabled")),
    );
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
            onPressed: isSystemActive ? _resetAll : null,
            child: Text(
              "Reset",
              style: TextStyle(
                color: isSystemActive ? Colors.redAccent : Colors.grey,
              ),
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

                const SizedBox(height: 10),

                // --- List ---
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredPackages.length,
                    cacheExtent: 100,
                    itemBuilder: (context, index) {
                      final pkg = filteredPackages[index];
                      final name = _nameCache[pkg] ?? pkg;

                      // เช็คว่า Active อยู่หรือไม่
                      final bool isChecked = NetworkPriorityScreen
                          .activePriorityPkgs
                          .contains(pkg);

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? Colors.blueAccent.withOpacity(
                                  0.1,
                                ) // สีพื้นหลังเมื่อเลือก
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isChecked
                              ? Border.all(
                                  color: Colors.blueAccent.withOpacity(0.3),
                                )
                              : null,
                        ),
                        child: CheckboxListTile(
                          activeColor: Colors.blueAccent,
                          secondary: _buildAppIcon(pkg),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: isChecked
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isChecked ? Colors.blueAccent : null,
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
      // เอา BottomNavigationBar ออกแล้ว
    );
  }
}
