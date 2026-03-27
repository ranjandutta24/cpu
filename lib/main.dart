import 'package:cpu/init.dart';
import 'package:cpu/theme/app_theme.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const CpuMonitorApp());
}

class CpuMonitorApp extends StatelessWidget {
  const CpuMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'System Monitor',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system, // follows device setting
      home: const InitScreen(),
    );
  }
}
