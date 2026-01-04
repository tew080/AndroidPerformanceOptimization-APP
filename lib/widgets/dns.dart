import 'package:flutter/material.dart';
import '../utils/optimizer_logic.dart';

class DnsDialog {
  // เริ่มต้นด้วยสถานะ Off
  static String _lastSelectedLabel = "Off (Default)";

  static void show(BuildContext context, Function(String, List<String>) onRun) {
    final dnsOptions = {
      "Off (Default)": "off",
      "Cloudflare (Family)": "family.cloudflare-dns.com",
      "AdGuard (Block Ads)": "dns.adguard.com",
      "Tiar DNS (Block Ads)": "dot.tiar.app",
      "CloudFlare DNS": "1dot1dot1dot1.cloudflare-dns.com",
      "Google DNS": "dns.google",
      "Next DNS": "anycast.dns.nextdns.io",
      "Quad9 DNS": "dns.quad9.net",
      "Uncensored DNS": "anycast.censurfridns.dk",
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDiagState) => AlertDialog(
          title: const Text("Private DNS (Block Ads)"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Using a private DNS can help block ads in apps and browsers.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _lastSelectedLabel,
                items: dnsOptions.keys
                    .map(
                      (label) => DropdownMenuItem(
                        value: label,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            // ถ้าเป็น Off ให้ใช้สีแดง/เทา เพื่อให้เด่น
                            color: label == "Off (Default)"
                                ? Colors.redAccent
                                : Colors.white,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDiagState(() {
                      _lastSelectedLabel = v;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // เมื่อกด Turn Off ให้เปลี่ยน Label เป็น Off
                _lastSelectedLabel = "Off (Default)";
                onRun(
                  "Disable Private DNS",
                  OptimizerLogic.getDNSCommands("off"),
                );
              },
              child: const Text(
                "Turn Off",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                String dnsHost = dnsOptions[_lastSelectedLabel]!;

                // เช็คว่าถ้าเลือก Off ใน Dropdown แล้วกด Apply ให้รันคำสั่งปิดเหมือนกัน
                if (dnsHost == "off") {
                  onRun(
                    "Disable Private DNS",
                    OptimizerLogic.getDNSCommands("off"),
                  );
                } else {
                  onRun(
                    "Set DNS: $_lastSelectedLabel",
                    OptimizerLogic.getDNSCommands(dnsHost),
                  );
                }
              },
              child: const Text("Apply"),
            ),
          ],
        ),
      ),
    );
  }
}
