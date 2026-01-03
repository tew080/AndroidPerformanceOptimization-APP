import 'package:flutter/material.dart';
import '../utils/console_logger.dart';
import 'console_loading.dart'; // อย่าลืม import ไฟล์ใหม่

class ConsoleWidget extends StatefulWidget {
  final double height;
  const ConsoleWidget({super.key, this.height = 300});

  @override
  State<ConsoleWidget> createState() => _ConsoleWidgetState();
}

class _ConsoleWidgetState extends State<ConsoleWidget> {
  final ScrollController _scrollController = ScrollController();

  // ฟังก์ชันเลื่อนลงล่างสุดอัตโนมัติ
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D), // ดำสนิท
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: ValueListenableBuilder<List<String>>(
        valueListenable: ConsoleLogger().logs,
        builder: (context, logs, _) {
          // ซ้อน ValueListenableBuilder อีกชั้นเพื่อฟังสถานะ Loading
          return ValueListenableBuilder<bool>(
            valueListenable: ConsoleLogger().isLoading,
            builder: (context, isLoading, _) {
              // สั่งเลื่อนจอทุกครั้งที่มีการเปลี่ยนแปลง
              _scrollToBottom();

              if (logs.isEmpty && !isLoading) {
                return const Center(
                  child: Text(
                    "Ready to execute...",
                    style: TextStyle(
                      color: Colors.grey,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                // ถ้า Loading อยู่ ให้เพิ่มจำนวนรายการอีก 1 บรรทัด
                itemCount: logs.length + (isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  // ถ้าเป็นบรรทัดสุดท้ายและกำลัง Loading ให้โชว์ Animation
                  if (isLoading && index == logs.length) {
                    return const ConsoleLoading();
                  }

                  return Text(
                    logs[index],
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.2,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
