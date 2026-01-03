import 'package:flutter/material.dart';
import 'services/shizuku_service.dart';
import 'services/executor_service.dart';
import 'utils/optimizer_logic.dart';
import 'widgets/console_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/process_manager.dart';
import 'widgets/disabled_apps.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Android Optimizer',
      debugShowCheckedModeBanner: false, // ปิดป้าย Debug มุมขวาบน
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.greenAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(secondary: Colors.greenAccent),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _statusLog = "Checking status...";
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  // เริ่มต้นการทำงานของแอพ
  Future<void> _initApp() async {
    await ShizukuService.requestNotificationPermission(); // ขอสิทธิ์แจ้งเตือน
    await _checkShizuku(); // เช็ค Shizuku
  }

  Future<void> _checkShizuku() async {
    bool granted = await ShizukuService.checkPermission();
    if (mounted) {
      setState(() {
        _hasPermission = granted;
        _statusLog = granted ? "Shizuku Connected" : "Shizuku Not Connected";
      });
    }
  }

  // --- Core Runners ---

  void _run(String label, List<String> commands) {
    if (!_ensurePermission()) return;
    _showConsole(label);
    ExecutorService.executeScript(label, commands);
  }

  void _runCompile(String label, String mode) {
    if (!_ensurePermission()) return;
    _showConsole(label);
    ExecutorService.compileAllApps(mode);
  }

  bool _ensurePermission() {
    if (!_hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please allow Shizuku permission first!")),
      );
      return false;
    }
    return true;
  }

  // --- UI Components ---

  void _showConsole(String label) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7, // สูง 70%
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.terminal, color: Colors.greenAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Minimizing to background..."),
                          ),
                        );
                      },
                      child: const Text("Hide"),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      onPressed: () {
                        ExecutorService.stop();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Console Output
              const Expanded(child: ConsoleWidget(height: double.infinity)),
            ],
          ),
        ),
      ),
    );
  }

  // --- Dialog Builders (Separated for Clean Code) ---

  void _showRamDialog() {
    int selected = 8;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select Device RAM"),
        content: DropdownButtonFormField<int>(
          value: selected,
          items: [2, 3, 4, 6, 8, 12, 16, 24]
              .map((e) => DropdownMenuItem(value: e, child: Text("$e GB")))
              .toList(),
          onChanged: (v) => selected = v!,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _run(
                "Set RAM $selected GB",
                OptimizerLogic.getRamOptimizationCommands(selected),
              );
            },
            child: const Text("Apply"),
          ),
        ],
      ),
    );
  }

  void _showRefreshRateDialog() {
    int hz = 120;
    bool isVivo = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDiagState) => AlertDialog(
          title: const Text("Max Refresh Rate"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: hz,
                items: [60, 90, 120, 144, 165]
                    .map(
                      (e) => DropdownMenuItem(value: e, child: Text("$e Hz")),
                    )
                    .toList(),
                onChanged: (v) => setDiagState(() => hz = v!),
              ),
              CheckboxListTile(
                title: const Text("Vivo/iQOO Mode"),
                value: isVivo,
                onChanged: (v) => setDiagState(() => isVivo = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _run(
                  "Set $hz Hz",
                  OptimizerLogic.getRefreshRateCommands(hz, isVivo),
                );
              },
              child: const Text("Apply"),
            ),
          ],
        ),
      ),
    );
  }

  void _showSkiaDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select Skia Engine"),
        content: const Text(
          "Warning: This will force stop all apps and restart System UI.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runSkiaTask(
                "Set SkiaGL (OpenGL)",
                OptimizerLogic.getSkiaCommands(false),
              );
            },
            child: const Text("SkiaGL"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runSkiaTask(
                "Set SkiaVK (Vulkan)",
                OptimizerLogic.getSkiaCommands(true),
              );
            },
            child: const Text("SkiaVK"),
          ),
        ],
      ),
    );
  }

  // Helper function ใหม่สำหรับเรียก Skia Task
  void _runSkiaTask(String label, List<String> commands) {
    if (!_ensurePermission()) return;
    _showConsole(label); // เปิดหน้า Console

    // เรียกใช้ฟังก์ชันพิเศษที่เราสร้างใน ExecutorService
    ExecutorService.applySkiaAndRestart(label, commands);
  }

  void _showBloatwareDialog() {
    TextEditingController pkgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Bloatware Manager"),
        content: TextField(
          controller: pkgCtrl,
          decoration: const InputDecoration(
            labelText: "Package Name (e.g. com.google.youtube)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (pkgCtrl.text.isNotEmpty) {
                Navigator.pop(ctx);
                _run("Uninstall ${pkgCtrl.text}", [
                  "pm uninstall -k --user 0 ${pkgCtrl.text}",
                ]);
              }
            },
            child: const Text("Uninstall", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              if (pkgCtrl.text.isNotEmpty) {
                Navigator.pop(ctx);
                _run("Reinstall ${pkgCtrl.text}", [
                  "pm install-existing ${pkgCtrl.text}",
                ]);
              }
            },
            child: const Text("Reinstall"),
          ),
        ],
      ),
    );
  }

  void _showGpuDialog() {
    bool snapdragon = false;
    bool tuning = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDiagState) => AlertDialog(
          title: const Text("GPU & HW Accel"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text("Snapdragon SOC"),
                value: snapdragon,
                onChanged: (v) => setDiagState(() => snapdragon = v!),
              ),
              CheckboxListTile(
                title: const Text("Enable Perf. Tuning"),
                value: tuning,
                onChanged: (v) => setDiagState(() => tuning = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _run(
                  "GPU Optimization",
                  OptimizerLogic.getGpuOptimization(snapdragon, tuning),
                );
              },
              child: const Text("Apply"),
            ),
          ],
        ),
      ),
    );
  }

  void _showTouchDialog() {
    TextEditingController ctrl = TextEditingController(text: "250");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Touch Timer (ms)"),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _run(
                "Touch Opt ${ctrl.text}ms",
                OptimizerLogic.getTouchOptimization(ctrl.text),
              );
            },
            child: const Text("Apply"),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://github.com/tew080');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Android Optimizer"),
        actions: [
          IconButton(onPressed: _checkShizuku, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: _hasPermission
                ? Colors.green.withOpacity(0.2)
                : Colors.red.withOpacity(0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _hasPermission ? Icons.check_circle : Icons.error,
                  color: _hasPermission ? Colors.greenAccent : Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _statusLog,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Menu List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection("Display & Graphics"),
                _buildBtn(
                  "Set Refresh Rate",
                  Icons.refresh,
                  _showRefreshRateDialog,
                ),
                _buildBtn("Skia Render Engine", Icons.brush, _showSkiaDialog),
                _buildBtn(
                  "Disable V-Sync",
                  Icons.speed,
                  () =>
                      _run("Disable V-Sync", OptimizerLogic.getDisableVSync()),
                ),
                _buildBtn(
                  "Disable Anti-Aliasing",
                  Icons.blur_off,
                  () => _run("Disable AA", OptimizerLogic.getDisableAA()),
                ),
                _buildBtn(
                  "Refresh Rate Optimization",
                  Icons.settings_display,
                  () => _run(
                    "Refresh Rate Opt",
                    OptimizerLogic.getRefreshRateOptimization(),
                  ),
                ),

                _buildSection("System & Hardware"),
                _buildBtn("RAM Optimization", Icons.memory, _showRamDialog),
                _buildBtn(
                  "Touch Optimization",
                  Icons.touch_app,
                  _showTouchDialog,
                ),
                _buildBtn(
                  "GPU & Hardware Accel",
                  Icons.developer_board,
                  _showGpuDialog,
                ),

                _buildSection("Maintenance"),
                _buildBtn(
                  "Idle Maintenance",
                  Icons.cleaning_services,
                  () => _run("Idle Maint.", ["sm idle-maint run"]),
                ),
                _buildBtn(
                  "Force TRIM Storage",
                  Icons.storage,
                  () => _run("TRIM", ["sm fstrim"]),
                ),
                _buildBtn(
                  "Background Dex Opt",
                  Icons.schedule,
                  () => _run("Bg Dex Opt", ["cmd package bg-dexopt-job"]),
                ),

                _buildBtn(
                  "Clean Junk & Cache",
                  Icons.cleaning_services_outlined,
                  // แก้ไขตรงนี้: ใช้ _run แทนการเรียก ExecutorService ตรงๆ
                  () => _run(
                    "Deep Cleaning...", // ข้อความที่จะโชว์หัวข้อใน Console
                    OptimizerLogic.getJunkCleanerCommands(), // ชุดคำสั่งจากไฟล์ logic
                  ),
                ),

                _buildSection("Compilation (High Performance)"),
                _buildBtn(
                  "AOT Compile (Speed Mode)",
                  Icons.rocket_launch,
                  () => _runCompile("AOT Compile (Speed)", "speed"),
                ),
                _buildBtn(
                  "AOT Compile (Profile Mode)",
                  Icons.timer,
                  () => _runCompile("AOT Compile (Profile)", "speed-profile"),
                ),
                _buildSection("APP & Task Manager"),
                _buildBtn("Running Processes Manager", Icons.list_alt, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProcessManagerScreen(),
                    ),
                  );
                }),
                _buildBtn(
                  "Blocked Apps Manager", // ชื่อปุ่ม
                  Icons.phonelink_erase, // ไอคอน
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DisabledAppsScreen(),
                      ),
                    );
                  },
                ),
                _buildBtn(
                  "Bloatware Manager",
                  Icons.delete_forever,
                  _showBloatwareDialog,
                ),

                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center, // จัดกึ่งกลาง
                  children: [
                    // ส่วนข้อความปกติ
                    const Text(
                      "v1.0.1 | Github: ",
                      style: TextStyle(color: Colors.grey),
                    ),
                    // ส่วนที่เป็นปุ่มกด
                    InkWell(
                      onTap: _launchURL, // เรียกฟังก์ชันเปิดเว็บ
                      child: const Text(
                        "tew080",
                        style: TextStyle(
                          color:
                              Colors.blueAccent, // เปลี่ยนสีให้รู้ว่าเป็นลิงก์
                          decoration: TextDecoration.underline, // ขีดเส้นใต้
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBtn(String text, IconData icon, VoidCallback onTap) {
    return Card(
      color: const Color(0xFF252525),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(text),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: _hasPermission ? onTap : null, // Disable ถ้าไม่มี Permission
        enabled: _hasPermission,
      ),
    );
  }
}
