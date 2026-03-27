import 'dart:convert';
import 'dart:async';

import 'package:cpu/theme/app_theme.dart';
import 'package:cpu/utils/drawer.dart';
import 'package:cpu/utils/function.dart';
import 'package:eventsource/eventsource.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SystemStatsRow extends StatefulWidget {
  const SystemStatsRow({super.key});

  @override
  State<SystemStatsRow> createState() => _SystemStatsRowState();
}

class _SystemStatsRowState extends State<SystemStatsRow>
    with WidgetsBindingObserver {
  Map<String, dynamic> _stats = {
    'cpuUsage': '0.0',
    'ramUsage': '0.0',
    'totalRam': '0.0',
    'diskUsage': '0.0',
  };

  EventSource? _eventSource;
  List<FlSpot> _cpuPoints = [];
  List<FlSpot> _ramPoints = [];
  List<String> _timeLabels = [];
  String ip = '';
  double _xValue = 0;

  @override
  void initState() {
    super.initState();
    ip = getIp();
    _startListening();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _eventSource?.client.close();
      _startListening();
    }
  }

  void _startListening() async {
    try {
      final link = 'http://$ip:3000/stats';
      _eventSource = await EventSource.connect(link);
      _eventSource?.listen((event) {
        final data = jsonDecode(event.data ?? '{}');
        setState(() {
          _stats = data;
          _xValue += 1;
          final now = DateTime.now();
          _timeLabels.add('${now.hour}:${now.minute.toString().padLeft(2, '0')}');
          _cpuPoints.add(FlSpot(_xValue, double.tryParse(data['cpuUsage'].toString()) ?? 0));
          _ramPoints.add(FlSpot(_xValue, double.tryParse(data['ramUsage'].toString()) ?? 0));
          if (_cpuPoints.length > 30) {
            _cpuPoints.removeAt(0);
            _timeLabels.removeAt(0);
          }
          if (_ramPoints.length > 30) _ramPoints.removeAt(0);
        });
      });
    } catch (e) {
      debugPrint('SSE error: $e');
    }
  }

  double _parseDouble(String key) =>
      double.tryParse(_stats[key]?.toString() ?? '0') ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cpu  = _parseDouble('cpuUsage');
    final ram  = _parseDouble('ramUsage');
    final disk = _parseDouble('diskUsage');
    final totalRam = _stats['totalRam']?.toString() ?? '0';

    return Scaffold(
      drawer: const CustomDrawer(username: 'Admin', role: 'Admin', email: 'NA'),
      appBar: AppBar(
        title: const Text(
          'System Monitor',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Icon(Icons.circle, size: 10,
              color: AppColors.success.withOpacity(0.85)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section label ──────────────────────────
            _sectionLabel('Live Stats', isDark),
            const SizedBox(height: 12),

            // ── Stat cards row ─────────────────────────
            Row(
              children: [
                Expanded(child: _StatCard(
                  label: 'CPU',
                  value: cpu,
                  subtitle: '${cpu.toStringAsFixed(1)} %',
                  icon: Icons.memory_rounded,
                  color: AppColors.cpuChart,
                  isDark: isDark,
                )),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(
                  label: 'RAM',
                  value: ram,
                  subtitle: '${ram.toStringAsFixed(1)} %\n$totalRam GB',
                  icon: Icons.storage_rounded,
                  color: AppColors.ramChart,
                  isDark: isDark,
                )),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(
                  label: 'Disk',
                  value: disk,
                  subtitle: '${disk.toStringAsFixed(1)} %',
                  icon: Icons.disc_full_rounded,
                  color: AppColors.diskChart,
                  isDark: isDark,
                )),
              ],
            ),

            const SizedBox(height: 28),

            // ── CPU Chart ──────────────────────────────
            _sectionLabel('CPU Usage Over Time', isDark),
            const SizedBox(height: 12),
            _ChartCard(
              points: _cpuPoints,
              timeLabels: _timeLabels,
              color: AppColors.cpuChart,
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            // ── RAM Chart ──────────────────────────────
            _sectionLabel('RAM Usage Over Time', isDark),
            const SizedBox(height: 12),
            _ChartCard(
              points: _ramPoints,
              timeLabels: _timeLabels,
              color: AppColors.ramChart,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: isDark ? AppColors.darkTextSecond : AppColors.lightTextSecond,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSource?.client.close();
    super.dispose();
  }
}

// ──────────────────────────────────────────────
// Stat Card Widget
// ──────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final double value;   // 0 – 100
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.12 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular progress with icon
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (value.clamp(0, 100)) / 100,
                  strokeWidth: 5,
                  backgroundColor: border,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextSecond : AppColors.lightTextSecond,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Chart Card Widget
// ──────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final List<FlSpot> points;
  final List<String> timeLabels;
  final Color color;
  final bool isDark;

  const _ChartCard({
    required this.points,
    required this.timeLabels,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg      = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final grid    = isDark ? AppColors.darkBorder.withOpacity(0.5) : AppColors.lightBorder;
    final txtClr  = isDark ? AppColors.darkTextSecond : AppColors.lightTextSecond;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: points.isEmpty
          ? Center(
              child: Text(
                'Waiting for data…',
                style: TextStyle(color: txtClr, fontSize: 13),
              ),
            )
          : LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: grid,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 25,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}%',
                        style: TextStyle(fontSize: 9, color: txtClr),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 5,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < timeLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              timeLabels[idx],
                              style: TextStyle(fontSize: 9, color: txtClr),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(1)}%',
                      TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
                    )).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: points,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: color,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withOpacity(0.22),
                          color.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
