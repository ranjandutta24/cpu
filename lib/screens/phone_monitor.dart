import 'dart:async';
import 'dart:typed_data';

import 'package:battery_plus/battery_plus.dart';
import 'package:cpu/theme/app_theme.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class PhoneMonitorScreen extends StatefulWidget {
  const PhoneMonitorScreen({super.key});

  @override
  State<PhoneMonitorScreen> createState() => _PhoneMonitorScreenState();
}

class _PhoneMonitorScreenState extends State<PhoneMonitorScreen>
    with SingleTickerProviderStateMixin {
  // ── Native channel ────────────────────────────────────────────────────────
  static const _channel = MethodChannel('com.example.cpu/native_stats');

  // ── Navigation ────────────────────────────────────────────────────────────
  final _scaffoldKey          = GlobalKey<ScaffoldState>();
  late final PageController   _pageCtrl;
  int _selectedPage           = 0; // 0 = Live Processes, 1 = Installed Apps

  // ── State ─────────────────────────────────────────────────────────────────
  int _batteryLevel          = 0;
  BatteryState _batteryState = BatteryState.unknown;
  double _cpuTemp            = -1;
  int _currentMa             = 0;
  int _totalRamMb            = 0;
  int _usedRamMb             = 0;
  int _freeRamMb             = 0;
  String _deviceModel        = '---';
  String _androidVer         = '---';

  // Installed apps
  List<AppInfo> _apps        = [];
  bool _loadingApps          = true;
  String _appSearch          = '';

  // Running processes (from native or ActivityManager usage stats)
  List<Map<String, dynamic>> _runningProcs = [];
  bool _loadingProcs                       = true;

  bool _loadingStats = true;

  final Battery _battery = Battery();
  Timer? _refreshTimer;
  StreamSubscription<BatteryState>? _batterySub;

  // ── Life-cycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: 0);
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      _loadDeviceInfo(),
      _loadNativeStats(),
      _loadApps(),
      _loadRunningProcesses(),
    ]);
    _batterySub = _battery.onBatteryStateChanged.listen((s) {
      if (mounted) setState(() => _batteryState = s);
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _loadNativeStats();
        _loadRunningProcesses();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _batterySub?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── Data loaders ──────────────────────────────────────────────────────────
  Future<void> _loadDeviceInfo() async {
    try {
      final info  = await DeviceInfoPlugin().androidInfo;
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      if (!mounted) return;
      setState(() {
        _deviceModel  = '${info.brand} ${info.model}';
        _androidVer   =
            'Android ${info.version.release}  (SDK ${info.version.sdkInt})';
        _batteryLevel = level;
        _batteryState = state;
      });
    } catch (_) {}
  }

  Future<void> _loadNativeStats() async {
    try {
      final Map raw   = await _channel.invokeMethod('getNativeStats');
      final level     = await _battery.batteryLevel;
      if (!mounted) return;
      setState(() {
        _cpuTemp    = (raw['cpuTemp']    as num?)?.toDouble() ?? -1;
        _currentMa  = (raw['currentMa']  as num?)?.toInt()   ?? 0;
        _totalRamMb = (raw['totalRamMb'] as num?)?.toInt()   ?? 0;
        _usedRamMb  = (raw['usedRamMb']  as num?)?.toInt()   ?? 0;
        _freeRamMb  = (raw['freeRamMb']  as num?)?.toInt()   ?? 0;
        _batteryLevel = level;
        _loadingStats = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _loadApps() async {
    try {
      final apps = await InstalledApps.getInstalledApps(false, true);
      apps.sort((a, b) =>
          (a.name ?? '').toLowerCase().compareTo(
              (b.name ?? '').toLowerCase()));
      if (!mounted) return;
      setState(() {
        _apps        = apps;
        _loadingApps = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingApps = false);
    }
  }

  Future<void> _loadRunningProcesses() async {
    try {
      // Try to get running apps from the native channel.
      // The channel must handle 'getRunningApps' and return a List of maps
      // with keys: name, packageName, [icon (Uint8List)].
      // If not implemented yet, fall back gracefully.
      final List raw =
          await _channel.invokeMethod('getRunningApps') as List? ?? [];
      final procs = raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _runningProcs = procs;
        _loadingProcs = false;
      });
    } catch (_) {
      // Channel not yet implemented — show empty state gracefully
      if (mounted) setState(() => _loadingProcs = false);
    }
  }

  // ── Computed helpers ──────────────────────────────────────────────────────
  Color get _batteryColor {
    if (_batteryState == BatteryState.charging) return AppColors.accentTeal;
    if (_batteryLevel <= 20) return AppColors.error;
    if (_batteryLevel <= 50) return AppColors.warning;
    return AppColors.accentTeal;
  }

  IconData get _batteryIcon {
    if (_batteryState == BatteryState.charging)
      return Icons.battery_charging_full_rounded;
    if (_batteryLevel <= 20) return Icons.battery_1_bar_rounded;
    if (_batteryLevel <= 50) return Icons.battery_4_bar_rounded;
    return Icons.battery_full_rounded;
  }

  String get _stateLabel {
    switch (_batteryState) {
      case BatteryState.charging:    return 'Charging';
      case BatteryState.discharging: return 'Discharging';
      case BatteryState.full:        return 'Full';
      default:                       return 'Unknown';
    }
  }

  Color get _tempColor {
    if (_cpuTemp < 0)  return AppColors.darkTextSecond;
    if (_cpuTemp < 45) return AppColors.accentTeal;
    if (_cpuTemp < 65) return AppColors.warning;
    return AppColors.error;
  }

  double get _ramUsedRatio =>
      _totalRamMb > 0 ? _usedRamMb / _totalRamMb : 0;

  List<AppInfo> get _filteredApps {
    if (_appSearch.isEmpty) return _apps;
    return _apps
        .where((a) => (a.name ?? '')
            .toLowerCase()
            .contains(_appSearch.toLowerCase()))
        .toList();
  }

  // ── Page switch helper ────────────────────────────────────────────────────
  void _goToPage(int index) {
    setState(() => _selectedPage = index);
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
    Navigator.of(context).pop(); // close drawer
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: c.bg,
      drawer: _buildDrawer(c),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.bg, c.bgGradMid2, c.bg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(c),
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _selectedPage = i),
                  children: [
                    _buildLiveProcessesPage(c),
                    _buildInstalledAppsPage(c),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────
  Widget _buildDrawer(AppSurface c) {
    return Drawer(
      backgroundColor: c.surface,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1040),
                  Color(0xFF0D1117),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accentPurple, AppColors.accentTeal],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.phone_android_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Phone Monitor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _deviceModel,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Nav items
          _DrawerNavItem(
            icon: Icons.memory_rounded,
            label: 'Live Processes',
            selected: _selectedPage == 0,
            accent: AppColors.accentPurple,
            onTap: () => _goToPage(0),
          ),
          _DrawerNavItem(
            icon: Icons.apps_rounded,
            label: 'Installed Apps',
            selected: _selectedPage == 1,
            accent: AppColors.accentTeal,
            onTap: () => _goToPage(1),
          ),

          const Spacer(),

          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _LiveDot(color: AppColors.accentPurple),
                const SizedBox(width: 8),
                Text(
                  'Monitoring active',
                  style: TextStyle(
                      color: AppColors.darkTextSecond, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(AppSurface c) {
    final pageLabels = ['Live Processes', 'Installed Apps'];
    final pageIcons  = [Icons.memory_rounded, Icons.apps_rounded];
    final pageColors = [AppColors.accentPurple, AppColors.accentTeal];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          // Hamburger / drawer toggle
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.accentPurple.withOpacity(0.25)),
              ),
              child: const Icon(Icons.menu_rounded,
                  color: AppColors.accentPurple, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Icon(pageIcons[_selectedPage],
              color: pageColors[_selectedPage], size: 20),
          const SizedBox(width: 8),
          Text(
            pageLabels[_selectedPage],
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          _LiveDot(color: pageColors[_selectedPage]),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 1 — Live Processes
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLiveProcessesPage(AppSurface c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device strip
          _buildDeviceStrip(c),
          const SizedBox(height: 16),

          // Metric cards row
          Row(
            children: [
              Expanded(child: _buildBatteryCard(c)),
              const SizedBox(width: 10),
              Expanded(child: _buildTempCard(c)),
            ],
          ),
          const SizedBox(height: 10),
          _buildCurrentCard(c),
          const SizedBox(height: 10),
          _buildRamCard(c),
          const SizedBox(height: 24),

          // Running processes section
          _buildRunningProcessesSection(c),
        ],
      ),
    );
  }

  // ── Device strip ──────────────────────────────────────────────────────────
  Widget _buildDeviceStrip(AppSurface c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.accentPurple.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android_rounded,
              color: AppColors.accentPurple, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_deviceModel,
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_androidVer,
                    style: TextStyle(
                        color: c.textSecond, fontSize: 11.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.accentTeal.withOpacity(0.3)),
            ),
            child: const Text('This Device',
                style: TextStyle(
                    color: AppColors.accentTeal,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Battery card ──────────────────────────────────────────────────────────
  Widget _buildBatteryCard(AppSurface c) {
    return _MetricCard(
      surface: c,
      icon: _batteryIcon,
      color: _batteryColor,
      topLabel: 'Battery',
      value: '$_batteryLevel%',
      bottomLabel: _stateLabel,
      extra: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _batteryLevel / 100,
            minHeight: 5,
            backgroundColor: Colors.black12,
            valueColor: AlwaysStoppedAnimation(_batteryColor),
          ),
        ),
      ),
    );
  }

  // ── Current card ──────────────────────────────────────────────────────────
  Widget _buildCurrentCard(AppSurface c) {
    final isCharging  = _currentMa > 0;
    final absVal      = _currentMa.abs();
    final color       = _currentMa == 0
        ? c.textSecond
        : isCharging
            ? AppColors.accentTeal
            : AppColors.warning;

    final formatted = absVal == 0
        ? '--'
        : absVal >= 1000
            ? '${(absVal ~/ 1000)},${(absVal % 1000).toString().padLeft(3, '0')}'
            : '$absVal';

    final watts = absVal > 0
        ? (absVal * 3.7 / 1000).toStringAsFixed(1)
        : '--';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Icon(
            _currentMa == 0
                ? Icons.power_off_outlined
                : isCharging
                    ? Icons.bolt_rounded
                    : Icons.battery_alert_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current',
                  style: TextStyle(
                      color: c.textSecond,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
              const SizedBox(height: 3),
              Text(
                '$formatted mA',
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const Spacer(),
          Text(
            _currentMa == 0
                ? 'Unavailable'
                : '≈ $watts W  •  ${isCharging ? "IN ↑" : "OUT ↓"}',
            style: TextStyle(color: c.textSecond, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Temp card ─────────────────────────────────────────────────────────────
  Widget _buildTempCard(AppSurface c) {
    return _MetricCard(
      surface: c,
      icon: Icons.thermostat_rounded,
      color: _tempColor,
      topLabel: 'CPU Temp',
      value: _cpuTemp < 0
          ? '--°C'
          : '${_cpuTemp.toStringAsFixed(1)}°C',
      bottomLabel: _cpuTemp < 0
          ? 'N/A'
          : _cpuTemp < 45
              ? 'Cool'
              : _cpuTemp < 65
                  ? 'Warm'
                  : 'Hot!',
    );
  }

  // ── RAM card ──────────────────────────────────────────────────────────────
  Widget _buildRamCard(AppSurface c) {
    final usedGb  = (_usedRamMb / 1024).toStringAsFixed(1);
    final totalGb = (_totalRamMb / 1024).toStringAsFixed(1);
    final freeGb  = (_freeRamMb / 1024).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.accentPurple.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.memory_rounded,
                  color: AppColors.accentPurple, size: 18),
              const SizedBox(width: 8),
              Text('RAM Usage',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_loadingStats)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: AppColors.accentPurple,
                        strokeWidth: 1.5))
              else
                Text('$usedGb / $totalGb GB',
                    style: TextStyle(
                        color: c.textSecond, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _ramUsedRatio,
              minHeight: 8,
              backgroundColor: Colors.black12,
              valueColor: const AlwaysStoppedAnimation(
                  AppColors.accentPurple),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RamChip(
                  label: 'Used',
                  value: '$usedGb GB',
                  color: AppColors.accentPurple,
                  textColor: c.textSecond),
              _RamChip(
                  label: 'Free',
                  value: '$freeGb GB',
                  color: AppColors.accentTeal,
                  textColor: c.textSecond),
              _RamChip(
                  label: 'Total',
                  value: '$totalGb GB',
                  color: c.textSecond,
                  textColor: c.textSecond),
            ],
          ),
        ],
      ),
    );
  }

  // ── Running processes section ─────────────────────────────────────────────
  Widget _buildRunningProcessesSection(AppSurface c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.run_circle_outlined,
                color: AppColors.accentPurple, size: 20),
            const SizedBox(width: 8),
            Text('Running Processes',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (!_loadingProcs)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentPurple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${_runningProcs.length} active',
                    style: const TextStyle(
                        color: AppColors.accentPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_loadingProcs)
          _buildProcsLoading(c)
        else if (_runningProcs.isEmpty)
          _buildProcsEmpty(c)
        else
          _buildProcsList(c),
      ],
    );
  }

  Widget _buildProcsLoading(AppSurface c) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.accentPurple.withOpacity(0.1)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                color: AppColors.accentPurple, strokeWidth: 2),
            SizedBox(height: 14),
            Text('Loading processes…',
                style:
                    TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildProcsEmpty(AppSurface c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.accentPurple.withOpacity(0.1)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.info_outline_rounded,
                color: c.textSecond, size: 32),
            const SizedBox(height: 10),
            Text('No process data available',
                style: TextStyle(color: c.textSecond, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Requires PACKAGE_USAGE_STATS permission\nor native implementation',
                style:
                    TextStyle(color: c.textHint, fontSize: 11.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildProcsList(AppSurface c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.accentPurple.withOpacity(0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _runningProcs.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: c.border.withOpacity(0.4), indent: 60),
        itemBuilder: (_, i) =>
            _ProcessTile(proc: _runningProcs[i], surface: c),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 2 — Installed Apps
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildInstalledAppsPage(AppSurface c) {
    final filtered = _filteredApps;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  const Icon(Icons.apps_rounded,
                      color: AppColors.accentTeal, size: 20),
                  const SizedBox(width: 8),
                  Text('Installed Apps',
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (!_loadingApps)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_apps.length} apps',
                          style: const TextStyle(
                              color: AppColors.accentTeal,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Search bar
              TextField(
                onChanged: (v) => setState(() => _appSearch = v),
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                cursorColor: AppColors.accentTeal,
                decoration: InputDecoration(
                  hintText: 'Search apps…',
                  hintStyle:
                      TextStyle(color: c.textHint, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.accentTeal, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: c.surface,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(
                        color: AppColors.accentTeal, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: _loadingApps
              ? _buildAppsLoading(c)
              : filtered.isEmpty
                  ? _buildAppsEmpty(c)
                  : _buildAppsList(filtered, c),
        ),
      ],
    );
  }

  Widget _buildAppsLoading(AppSurface c) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
              color: AppColors.accentTeal, strokeWidth: 2),
          SizedBox(height: 14),
          Text('Loading apps…',
              style:
                  TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildAppsEmpty(AppSurface c) {
    return Center(
      child: Text('No apps found',
          style: TextStyle(color: c.textSecond, fontSize: 14)),
    );
  }

  Widget _buildAppsList(List<AppInfo> apps, AppSurface c) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: apps.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: c.border.withOpacity(0.4), indent: 56),
      itemBuilder: (_, i) => _AppTile(app: apps[i], surface: c),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drawer nav item
// ─────────────────────────────────────────────────────────────────────────────

class _DrawerNavItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     selected;
  final Color    accent;
  final VoidCallback onTap;

  const _DrawerNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected
            ? accent.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: accent.withOpacity(0.25)),
                  )
                : null,
            child: Row(
              children: [
                Icon(icon,
                    color: selected ? accent : Colors.white38,
                    size: 22),
                const SizedBox(width: 14),
                Text(label,
                    style: TextStyle(
                      color:
                          selected ? accent : Colors.white60,
                      fontSize: 14,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    )),
                if (selected) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: accent),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final AppSurface surface;
  final IconData icon;
  final Color color;
  final String topLabel;
  final String value;
  final String bottomLabel;
  final Widget? extra;

  const _MetricCard({
    required this.surface,
    required this.icon,
    required this.color,
    required this.topLabel,
    required this.value,
    required this.bottomLabel,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(topLabel,
              style: TextStyle(
                  color: surface.textSecond,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(bottomLabel,
              style: TextStyle(
                  color: surface.textSecond, fontSize: 10.5)),
          if (extra != null) extra!,
        ],
      ),
    );
  }
}

class _RamChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color textColor;

  const _RamChip({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: textColor, fontSize: 10.5)),
      ],
    );
  }
}

class _LiveDot extends StatefulWidget {
  final Color color;
  const _LiveDot({required this.color});
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: widget.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: _anim,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: widget.color),
            ),
          ),
          const SizedBox(width: 6),
          Text('Live',
              style: TextStyle(
                  color: widget.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final AppInfo app;
  final AppSurface surface;
  const _AppTile({required this.app, required this.surface});

  @override
  Widget build(BuildContext context) {
    final Uint8List? iconBytes = app.icon;
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: surface.border.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: iconBytes != null && iconBytes.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child:
                        Image.memory(iconBytes, fit: BoxFit.cover),
                  )
                : const Icon(Icons.android_rounded,
                    color: Colors.white24, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.name ?? app.packageName ?? '---',
                  style: TextStyle(
                      color: surface.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  app.packageName ?? '',
                  style: TextStyle(
                      color: surface.textSecond, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (app.versionName != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'v${app.versionName}',
                style: const TextStyle(
                    color: AppColors.accentTeal,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Process tile ──────────────────────────────────────────────────────────────

class _ProcessTile extends StatelessWidget {
  final Map<String, dynamic> proc;
  final AppSurface surface;
  const _ProcessTile({required this.proc, required this.surface});

  @override
  Widget build(BuildContext context) {
    final name    = proc['name'] as String? ?? proc['packageName'] as String? ?? '---';
    final pkg     = proc['packageName'] as String? ?? '';
    final iconBytes = proc['icon'] as Uint8List?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accentPurple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: iconBytes != null && iconBytes.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(iconBytes, fit: BoxFit.cover),
                  )
                : const Icon(Icons.settings_applications_rounded,
                    color: AppColors.accentPurple, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: surface.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(pkg,
                    style: TextStyle(
                        color: surface.textSecond, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Active dot
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentTeal),
          ),
        ],
      ),
    );
  }
}
