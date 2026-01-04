import 'dart:typed_data';
import 'package:flutter/material.dart';
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
    final list = await ShizukuService.getDisabledApps();
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
        _allDisabledApps = list;
        _appIcons = iconMap;
        _appNames = nameMap;
        _filterApps(_searchQuery);
        _isLoading = false;
      });
    }
  }

  void _filterApps(String query) {
    setState(() {
      _searchQuery = query;
      _filteredApps = _allDisabledApps.where((app) {
        final pkg = (app['pkg'] as String).toLowerCase();
        final name = (_appNames[pkg] ?? "").toLowerCase();
        return pkg.contains(query.toLowerCase()) ||
            name.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _enableApp(String pkgName) async {
    String appLabel = _appNames[pkgName] ?? pkgName;
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Restore App"),
        content: Text("Do you want to enable '$appLabel' again?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Enable"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ShizukuService.enableApp(pkgName);
      _loadData();
    }
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
                    ),
                    onChanged: _filterApps,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredApps.length,
                    itemBuilder: (context, index) {
                      final pkg = _filteredApps[index]['pkg'];
                      final isSystem =
                          _filteredApps[index]['is_system'] ?? false;
                      final appName = _appNames[pkg] ?? pkg;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        color: const Color(0xFF1E1E1E),
                        child: ListTile(
                          leading: _appIcons[pkg] != null
                              ? Image.memory(_appIcons[pkg]!, width: 32)
                              : const Icon(Icons.block, color: Colors.grey),
                          title: Text(
                            appName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.lineThrough,
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
