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
  Map<String, Uint8List?> _appIcons = {};
  Map<String, String> _appNames = {};
  String _searchQuery = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 1. Get processes from Shizuku
    final processList = await ShizukuService.getRunningProcesses();

    // 2. Get App Info (Icons & Names) from system
    final installedApps = await AppHelper.getInstalledAppsWithIcons();
    final Map<String, Uint8List?> iconMap = {};
    final Map<String, String> nameMap = {};

    for (var app in installedApps) {
      if (app.packageName != null) {
        iconMap[app.packageName!] = app.icon;
        nameMap[app.packageName!] = app.name ?? app.packageName!;
      }
    }

    if (mounted) {
      setState(() {
        _allProcesses = processList;
        _appIcons = iconMap;
        _appNames = nameMap;
        _filterProcesses(_searchQuery);
        _isLoading = false;
      });
    }
  }

  void _filterProcesses(String query) {
    setState(() {
      _searchQuery = query;
      _filteredProcesses = _allProcesses.where((process) {
        final pkg = (process['pkg'] as String).toLowerCase();
        final name = (_appNames[pkg] ?? "").toLowerCase();
        return pkg.contains(query.toLowerCase()) ||
            name.contains(query.toLowerCase());
      }).toList();
    });
  }

  Widget _buildAppIcon(String pkgName, bool isSystem) {
    final iconBytes = _appIcons[pkgName];
    if (iconBytes != null && iconBytes.isNotEmpty) {
      return Image.memory(iconBytes, width: 32, height: 32);
    }
    return Icon(
      isSystem ? Icons.settings_suggest : Icons.android,
      color: isSystem ? Colors.redAccent : Colors.greenAccent,
      size: 28,
    );
  }

  Future<void> _manageApp(String pkgName, bool isSystem, String action) async {
    String titleText = action == 'kill' ? "Force Stop" : "Disable App";
    String appLabel = _appNames[pkgName] ?? pkgName;

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
        _loadData();
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
                    itemBuilder: (context, index) {
                      final item = _filteredProcesses[index];
                      final pkg = item['pkg'] as String;
                      final ram = item['ram_mb'] as int;
                      final bool isSystem = item['is_system'] ?? false;
                      final appName = _appNames[pkg] ?? pkg;

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
                          title: Text(
                            appName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
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
