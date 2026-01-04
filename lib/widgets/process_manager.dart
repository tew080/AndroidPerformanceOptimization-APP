import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/shizuku_service.dart';
import '../utils/app_helper.dart';

class ProcessManagerScreen extends StatefulWidget {
  const ProcessManagerScreen({super.key});

  @override
  State<ProcessManagerScreen> createState() => _ProcessManagerScreenState();
}

class _ProcessManagerScreenState extends State<ProcessManagerScreen> {
  List<dynamic> _allProcesses = [];
  List<dynamic> _filteredProcesses = [];

  // Cache สำหรับเก็บรูปที่โหลดเสร็จแล้ว เพื่อลดการทำงานซ้ำ
  final Map<String, Uint8List?> _iconCache = {};
  // Cache สำหรับชื่อแอป
  final Map<String, String> _nameCache = {};

  String _searchQuery = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. ดึงเฉพาะ Process ที่รันอยู่ (เร็วมาก ไม่ค้างแน่นอน)
      final processList = await ShizukuService.getRunningProcesses();

      // OPTIONAL: ถ้าอยากโหลดชื่อแอปมารอไว้ก่อน (เฉพาะแอปที่รันอยู่ ไม่ใช่ทั้งเครื่อง)
      // คุณอาจจะเขียน Logic เพิ่มตรงนี้ได้ แต่ถ้าเอาเร็ว ปล่อยว่างไว้แล้วโหลด Lazy เอา

      if (mounted) {
        setState(() {
          _allProcesses = processList;
          _filterProcesses(_searchQuery);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading processes: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterProcesses(String query) {
    setState(() {
      _searchQuery = query;
      _filteredProcesses = _allProcesses.where((process) {
        final pkg = (process['pkg'] as String).toLowerCase();
        // ค้นหาจากชื่อที่แคชไว้ หรือถ้าไม่มีก็หาจาก package name
        final name = (_nameCache[pkg] ?? "").toLowerCase();
        return pkg.contains(query.toLowerCase()) ||
            name.contains(query.toLowerCase());
      }).toList();
    });
  }

  // ฟังก์ชันดึงรูปทีละตัว (Lazy Load)
  Future<Uint8List?> _getAppIconLazy(String packageName) async {
    if (_iconCache.containsKey(packageName)) {
      return _iconCache[packageName];
    }
    // *** สำคัญ: ต้องไปเพิ่มฟังก์ชัน getAppIcon ใน AppHelper ***
    final icon = await AppHelper.getAppIcon(packageName);
    _iconCache[packageName] = icon;
    return icon;
  }

  // ฟังก์ชันดึงชื่อทีละตัว (Lazy Load)
  Future<String> _getAppNameLazy(String packageName) async {
    if (_nameCache.containsKey(packageName)) {
      return _nameCache[packageName]!;
    }
    // *** สำคัญ: ต้องไปเพิ่มฟังก์ชัน getAppName ใน AppHelper ***
    final name = await AppHelper.getAppName(packageName);
    _nameCache[packageName] = name;
    return name;
  }

  Widget _buildAppIcon(String pkgName, bool isSystem) {
    // ใช้ FutureBuilder เพื่อโหลดรูปแยกต่างหาก ไม่ขวาง UI หลัก
    return FutureBuilder<Uint8List?>(
      future: _getAppIconLazy(pkgName),
      builder: (context, snapshot) {
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.isNotEmpty) {
          return Image.memory(
            snapshot.data!,
            width: 32,
            height: 32,
            gaplessPlayback: true,
          );
        }
        // ระหว่างโหลด หรือถ้าไม่มีรูป ให้แสดง Icon
        return Icon(
          isSystem ? Icons.settings_suggest : Icons.android,
          color: isSystem
              ? Colors.redAccent.withOpacity(0.5)
              : Colors.greenAccent.withOpacity(0.5),
          size: 28,
        );
      },
    );
  }

  Future<void> _manageApp(String pkgName, bool isSystem, String action) async {
    String titleText = action == 'kill' ? "Force Stop" : "Disable App";
    String appLabel = _nameCache[pkgName] ?? pkgName;

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(isSystem ? "⚠️ System Warning" : titleText),
        content: Text(
          "Do you want to $action '$appLabel'?\n${isSystem ? 'This might cause system instability.' : ''}",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSystem ? Colors.red : Colors.blue,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action.toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      bool success = action == 'kill'
          ? await ShizukuService.forceStopApp(pkgName)
          : await ShizukuService.disableApp(pkgName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Success" : "Failed"),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData(); // Reload list
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Task Manager"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search apps or packages...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.05),
                    ),
                    onChanged: _filterProcesses,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredProcesses.length,
                    // optimization: กำหนด cacheExtent เพื่อให้โหลดรูปรอไว้ล่วงหน้าเล็กน้อยตอนไถหน้าจอ
                    cacheExtent: 100,
                    itemBuilder: (context, index) {
                      final item = _filteredProcesses[index];
                      final pkg = item['pkg'] as String;
                      final ram = item['ram_mb'] as int;
                      final bool isSystem = item['is_system'] ?? false;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSystem
                                ? Colors.redAccent.withOpacity(0.2)
                                : Colors.white10,
                          ),
                        ),
                        child: ListTile(
                          leading: _buildAppIcon(pkg, isSystem),
                          title: FutureBuilder<String>(
                            // โหลดชื่อแบบ Lazy เหมือนกัน
                            future: _getAppNameLazy(pkg),
                            initialData:
                                pkg, // โชว์ pkg name ไปก่อนระหว่างรอชื่อจริง
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? pkg,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                          subtitle: Text(
                            "$pkg\nRAM: $ram MB",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (val) => _manageApp(pkg, isSystem, val),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'kill',
                                child: Text("Force Stop"),
                              ),
                              const PopupMenuItem(
                                value: 'block',
                                child: Text("Disable App"),
                              ),
                            ],
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
