import 'dart:convert';

import 'package:cpu/theme/app_theme.dart';
import 'package:cpu/utils/drawer.dart';
import 'package:cpu/utils/function.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  Map<String, dynamic>? systemInfo;
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchSystemInfo();
  }

  Future<void> _fetchSystemInfo() async {
    try {
      final ip = getIp();
      final response = await http.get(Uri.parse('http://$ip:3000/info'));
      if (response.statusCode == 200) {
        setState(() {
          systemInfo = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Server returned status ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Could not reach server.\n$e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: const CustomDrawer(username: 'Admin', role: 'Admin', email: 'NA'),
      appBar: AppBar(
        title: const Text(
          'System Info',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                isLoading = true;
                errorMessage = '';
                systemInfo = null;
              });
              _fetchSystemInfo();
            },
          ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.accentTeal,
          strokeWidth: 2.5,
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 52,
                  color: isDark
                      ? AppColors.darkTextSecond
                      : AppColors.lightTextSecond),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecond
                      : AppColors.lightTextSecond,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final info = systemInfo!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── CPU ───────────────────────────────────
        _InfoSection(
          icon: Icons.memory_rounded,
          label: 'CPU',
          color: AppColors.cpuChart,
          isDark: isDark,
          tiles: [
            _InfoTile('Manufacturer', info['cpu']?['manufacturer']),
            _InfoTile('Brand', info['cpu']?['brand']),
            _InfoTile('Cores', info['cpu']?['cores']?.toString()),
            _InfoTile('Speed', info['cpu']?['speed']),
          ],
        ),

        const SizedBox(height: 16),

        // ── RAM ───────────────────────────────────
        _InfoSection(
          icon: Icons.storage_rounded,
          label: 'Memory',
          color: AppColors.ramChart,
          isDark: isDark,
          tiles: [
            _InfoTile('Total RAM', info['ram']?['total']),
          ],
        ),

        const SizedBox(height: 16),

        // ── Disk ──────────────────────────────────
        _InfoSection(
          icon: Icons.disc_full_rounded,
          label: 'Disk',
          color: AppColors.diskChart,
          isDark: isDark,
          tiles: [
            _InfoTile('Total Size', info['disk']?['size']),
            _InfoTile('Used', info['disk']?['used']),
          ],
        ),

        const SizedBox(height: 16),

        // ── GPU ───────────────────────────────────
        _InfoSection(
          icon: Icons.videogame_asset_rounded,
          label: 'GPU',
          color: AppColors.warning,
          isDark: isDark,
          tiles: [
            _InfoTile('Model', info['gpu']?['model']),
            _InfoTile('Vendor', info['gpu']?['vendor']),
            _InfoTile('VRAM', info['gpu']?['vramMB'] != null
                ? '${info['gpu']['vramMB']} MB'
                : null),
          ],
        ),

        const SizedBox(height: 16),

        // ── OS ────────────────────────────────────
        _InfoSection(
          icon: Icons.computer_rounded,
          label: 'Operating System',
          color: AppColors.accentTeal,
          isDark: isDark,
          tiles: [
            _InfoTile('Platform', info['os']?['platform']),
            _InfoTile('Distribution', info['os']?['distro']),
            _InfoTile('Release', info['os']?['release']),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Section widget
// ──────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final List<_InfoTile> tiles;

  const _InfoSection({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final labelClr = isDark ? AppColors.darkTextSecond : AppColors.lightTextSecond;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.08 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(width: 10),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: color,
                  ),
                ),
              ],
            ),
          ),

          Divider(color: border, thickness: 1, height: 1),

          // Rows
          ...tiles.map((tile) => tile.build(context, isDark)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Tile model
// ──────────────────────────────────────────────

class _InfoTile {
  final String label;
  final String? value;

  const _InfoTile(this.label, this.value);

  Widget build(BuildContext context, bool isDark) {
    final labelClr = isDark ? AppColors.darkTextSecond : AppColors.lightTextSecond;
    final valClr = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: labelClr,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value ?? '—',
                  style: TextStyle(
                    fontSize: 13,
                    color: valClr,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        Divider(
          color: border.withOpacity(0.5),
          thickness: 1,
          height: 1,
          indent: 16,
          endIndent: 16,
        ),
      ],
    );
  }
}
