import 'package:flutter/material.dart';
import '../services/shizuku_service.dart';

class ProcessManagerScreen extends StatefulWidget {
  const ProcessManagerScreen({super.key});

  @override
  State<ProcessManagerScreen> createState() => _ProcessManagerScreenState();
}

class _ProcessManagerScreenState extends State<ProcessManagerScreen> {
  List<dynamic> _processes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProcesses();
  }

  Future<void> _loadProcesses() async {
    setState(() => _isLoading = true);
    final list = await ShizukuService.getRunningProcesses();
    if (mounted) {
      setState(() {
        _processes = list;
        _isLoading = false;
      });
    }
  }

  // ฟังก์ชันจัดการแอพ (Kill หรือ Block)
  Future<void> _manageApp(
    String pkgName,
    String ram,
    bool isSystem,
    String action,
  ) async {
    // กำหนดข้อความเตือนตาม Action
    String titleText = "";
    String contentText = "";
    Color confirmColor = Colors.red;
    String btnLabel = "";

    if (action == 'kill') {
      titleText = "Force Stop (Kill)";
      contentText = "Stop running process '$pkgName'?\n(App can auto-restart)";
      btnLabel = "Kill";
    } else if (action == 'block') {
      titleText = "Block / Disable App 🚫";
      contentText =
          "This will DISABLE '$pkgName'.\n\n"
          "• App will vanish from app drawer.\n"
          "• It CANNOT auto-run anymore.\n"
          "• You must enable it back to use it.";
      btnLabel = "Block Forever";
    }

    // ถ้าเป็น System App ต้องเตือนหนักๆ
    if (isSystem) {
      titleText = "⚠️ SYSTEM WARNING";
      confirmColor = Colors.red;
      contentText =
          "WARNING: '$pkgName' is a SYSTEM APP.\n\n"
          "${action == 'block' ? 'BLOCKING' : 'STOPPING'} it may cause bootloop or crash!\n"
          "Do not proceed unless you know what you are doing.";
    }

    // Show Dialog
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          titleText,
          style: TextStyle(color: isSystem ? Colors.red : Colors.white),
        ),
        content: Text(contentText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(btnLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      bool success = false;
      if (action == 'kill') {
        success = await ShizukuService.forceStopApp(pkgName);
      } else if (action == 'block') {
        success = await ShizukuService.disableApp(pkgName);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Success: $action $pkgName" : "Failed"),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        _loadProcesses(); // Refresh list
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Task Manager"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProcesses,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            )
          : _processes.isEmpty
          ? const Center(child: Text("No running apps found"))
          : ListView.builder(
              itemCount: _processes.length,
              itemBuilder: (context, index) {
                final item = _processes[index];
                final pkg = item['pkg'] as String;
                final ram = item['ram_mb'] as int;
                final bool isSystem = item['is_system'] ?? false;

                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  shape: isSystem
                      ? RoundedRectangleBorder(
                          side: const BorderSide(
                            color: Colors.redAccent,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        )
                      : null,
                  child: ListTile(
                    leading: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSystem ? Icons.android_outlined : Icons.person,
                          color: isSystem
                              ? Colors.redAccent
                              : Colors.greenAccent,
                          size: 28,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSystem ? "SYS" : "USER",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isSystem
                                ? Colors.redAccent
                                : Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      pkg,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      "$ram MB",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    // เปลี่ยนปุ่ม Kill เป็น Menu (3 จุด)
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white70),
                      onSelected: (value) {
                        if (value == 'kill') {
                          _manageApp(pkg, ram.toString(), isSystem, 'kill');
                        } else if (value == 'block') {
                          _manageApp(pkg, ram.toString(), isSystem, 'block');
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            // เมนู 1: Kill
                            const PopupMenuItem<String>(
                              value: 'kill',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.stop_circle_outlined,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Force Stop (Temp)'),
                                ],
                              ),
                            ),
                            // เมนู 2: Block
                            const PopupMenuItem<String>(
                              value: 'block',
                              child: Row(
                                children: [
                                  Icon(Icons.block, color: Colors.redAccent),
                                  SizedBox(width: 8),
                                  Text('Block / Disable (Forever)'),
                                ],
                              ),
                            ),
                          ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
