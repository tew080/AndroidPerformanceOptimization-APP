import 'package:flutter/material.dart';
import '../services/shizuku_service.dart';

class DisabledAppsScreen extends StatefulWidget {
  const DisabledAppsScreen({super.key});

  @override
  State<DisabledAppsScreen> createState() => _DisabledAppsScreenState();
}

class _DisabledAppsScreenState extends State<DisabledAppsScreen> {
  List<dynamic> _disabledApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final list = await ShizukuService.getDisabledApps();
    if (mounted) {
      setState(() {
        _disabledApps = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _enableApp(String pkgName) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Enable App?"),
        content: Text(
          "Restore '$pkgName'?\nIt will appear on your launcher again.",
        ),
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
      bool success = await ShizukuService.enableApp(pkgName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Enabled $pkgName" : "Failed"),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        _loadData(); // รีเฟรชรายการ
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Blocked Apps (Disabled)"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            )
          : _disabledApps.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "No blocked apps found",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _disabledApps.length,
              itemBuilder: (context, index) {
                final item = _disabledApps[index];
                final pkg = item['pkg'] as String;
                final bool isSystem = item['is_system'] ?? false;

                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.block, // ไอคอนโดนบล็อก
                      color: isSystem
                          ? Colors.red.withOpacity(0.7)
                          : Colors.grey,
                    ),
                    title: Text(
                      pkg,
                      style: TextStyle(
                        color: Colors.white70,
                        decoration: TextDecoration
                            .lineThrough, // ขีดฆ่าชื่อให้รู้ว่าใช้ไม่ได้
                      ),
                    ),
                    subtitle: Text(
                      isSystem ? "System App" : "User App",
                      style: TextStyle(
                        fontSize: 12,
                        color: isSystem ? Colors.redAccent : Colors.greenAccent,
                      ),
                    ),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.2),
                        foregroundColor: Colors.greenAccent,
                      ),
                      onPressed: () => _enableApp(pkg),
                      icon: const Icon(Icons.settings_backup_restore, size: 18),
                      label: const Text("Enable"),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
