import 'dart:async';
import 'package:flutter/material.dart';

class ConsoleLoading extends StatefulWidget {
  const ConsoleLoading({super.key});

  @override
  State<ConsoleLoading> createState() => _ConsoleLoadingState();
}

class _ConsoleLoadingState extends State<ConsoleLoading> {
  // เฟรมอนิเมชั่น (แบบหมุน)
  final List<String> _frames = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
  ];
  // หรือถ้าชอบแบบง่ายๆ ใช้: ['|', '/', '-', '\\'];

  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _frames.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            "${_frames[_currentIndex]} Processing...",
            style: const TextStyle(
              color: Colors.greenAccent,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
