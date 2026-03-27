import 'dart:async';
import 'dart:typed_data';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

// ── Colour tokens ─────────────────────────────────────────────────────────────
const _bg     = Color(0xFF0D1117);
const _card   = Color(0xFF161B22);
const _teal   = Color(0xFF3DD9B3);
const _purple = Color(0xFF7B61FF);
const _red    = Color(0xFFFF6B6B);
const _amber  = Color(0xFFFFB347);

class PhoneMonitorScreen extends StatefulWidget {
  const PhoneMonitorScreen({super.key});

  @override
  State<PhoneMonitorScreen> createState() => _PhoneMonitorScreenState();
}

class _PhoneMonitorScreenState extends State<PhoneMonitorScreen> {
  // ── Native channel ───────────────────────────────────────────────────────────
  static const _channel = MethodChannel('com.example.cpu/native_stats');

  // ── State ────────────────────────────────────────────────────────────────────
  int _batteryLevel     = 0;
  BatteryState _batteryState = BatteryState.unknown;
  double _cpuTemp       = -1;
  int _currentMa        = 0;
  int _totalRamMb       = 0;
  int _usedRamMb        = 0;
  int _freeRamMb        = 0;
  String _deviceModel   = '---';
  String _androidVer    = '---';
  List<AppInfo> _apps   = [];
  bool _loadingApps     = true;
  bool _loadingStats    = true;
  String _appSearch     = '';

  final Battery _battery      = Battery();
  Timer? _refreshTimer;
  StreamSubscription<BatteryState>? _batterySub;

  // ── Life-cycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      _loadDeviceInfo(),
      _loadNativeStats(),
      _loadApps(),
    ]);
    _batterySub = _battery.onBatteryStateChanged.listen((s) {
      if (mounted) setState(() => _batteryState = s);
    });
    // Refresh live stats every 3 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadNativeStats();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _batterySub?.cancel();
    super.dispose();
  }

  // ── Data loaders ─────────────────────────────────────────────────────────────
  Future<void> _loadDeviceInfo() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      if (!mounted) return;
      setState(() {
        _deviceModel  = '${info.brand} ${info.model}';
        _androidVer   = 'Android ${info.version.release}  (SDK ${info.version.sdkInt})';
        _batteryLevel = level;
        _batteryState = state;
      });
    } catch (_) {}
  }

  Future<void> _loadNativeStats() async {
    try {
      final Map raw = await _channel.invokeMethod('getNativeStats');
      final level   = await _battery.batteryLevel;
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
      // includeSystemApps=false, withIcon=true
      final apps = await InstalledApps.getInstalledApps(false, true);
      apps.sort((a, b) =>
          (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _loadingApps = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingApps = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  Color get _batteryColor {
    if (_batteryState == BatteryState.charging) return _teal;
    if (_batteryLevel <= 20) return _red;
    if (_batteryLevel <= 50) return _amber;
    return _teal;
  }

  IconData get _batteryIcon {
    if (_batteryState == BatteryState.charging) return Icons.battery_charging_full_rounded;
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
    if (_cpuTemp < 0)  return Colors.white38;
    if (_cpuTemp < 45) return _teal;
    if (_cpuTemp < 65) return _amber;
    return _red;
  }

  double get _ramUsedRatio =>
      _totalRamMb > 0 ? _usedRamMb / _totalRamMb : 0;

  List<AppInfo> get _filteredApps {
    if (_appSearch.isEmpty) return _apps;
    return _apps
        .where((a) =>
            (a.name ?? '').toLowerCase().contains(_appSearch.toLowerCase()))
        .toList();
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bg, Color(0xFF0F1F2E), _bg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Device info strip
                      _buildDeviceStrip(),
                      const SizedBox(height: 16),
                      // Battery + Temp row
                      Row(
                        children: [
                          Expanded(child: _buildBatteryCard()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildCurrentCard()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTempCard()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // RAM card
                      _buildRamCard(),
                      const SizedBox(height: 20),
                      // Apps
                      _buildAppsSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Bar ──────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _purple.withOpacity(0.25)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _purple, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Phone Monitor',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          // Live dot
          _LiveDot(color: _purple),
        ],
      ),
    );
  }

  // ── Device strip ─────────────────────────────────────────────────────────────
  Widget _buildDeviceStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _purple.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android_rounded, color: _purple, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_deviceModel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_androidVer,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 11.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _teal.withOpacity(0.3)),
            ),
            child: const Text('This Device',
                style: TextStyle(
                    color: _teal, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Battery card ─────────────────────────────────────────────────────────────
  Widget _buildBatteryCard() {
    return _MetricCard(
      icon: _batteryIcon,
      color: _batteryColor,
      topLabel: 'Battery',
      value: '$_batteryLevel%',
      bottomLabel: _stateLabel,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _batteryLevel / 100,
            minHeight: 5,
            backgroundColor: Colors.white.withOpacity(0.07),
            valueColor: AlwaysStoppedAnimation(_batteryColor),
          ),
        ),
      ),
    );
  }

  // ── Current card ─────────────────────────────────────────────────────────────
  Widget _buildCurrentCard() {
    final isCharging = _currentMa > 0;
    final display    = _currentMa == 0
        ? '-- mA'
        : '${_currentMa.abs()} mA';
    return _MetricCard(
      icon: isCharging
          ? Icons.bolt_rounded
          : Icons.battery_alert_rounded,
      color: isCharging ? _teal : _amber,
      topLabel: 'Current',
      value: display,
      bottomLabel: isCharging ? 'Charging' : 'Draining',
    );
  }

  // ── Temp card ────────────────────────────────────────────────────────────────
  Widget _buildTempCard() {
    final display = _cpuTemp < 0
        ? '--°C'
        : '${_cpuTemp.toStringAsFixed(1)}°C';
    return _MetricCard(
      icon: Icons.thermostat_rounded,
      color: _tempColor,
      topLabel: 'CPU Temp',
      value: display,
      bottomLabel: _cpuTemp < 0
          ? 'N/A'
          : _cpuTemp < 45
              ? 'Cool'
              : _cpuTemp < 65
                  ? 'Warm'
                  : 'Hot!',
    );
  }

  // ── RAM card ─────────────────────────────────────────────────────────────────
  Widget _buildRamCard() {
    final usedGb  = (_usedRamMb / 1024).toStringAsFixed(1);
    final totalGb = (_totalRamMb / 1024).toStringAsFixed(1);
    final freeGb  = (_freeRamMb / 1024).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _purple.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.memory_rounded, color: _purple, size: 18),
              const SizedBox(width: 8),
              const Text('RAM',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_loadingStats)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child:
                        CircularProgressIndicator(color: _purple, strokeWidth: 1.5))
              else
                Text('$usedGb / $totalGb GB',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _ramUsedRatio,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.07),
              valueColor: const AlwaysStoppedAnimation(_purple),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RamChip(label: 'Used', value: '$usedGb GB', color: _purple),
              _RamChip(label: 'Free', value: '$freeGb GB', color: _teal),
              _RamChip(
                  label: 'Total',
                  value: '$totalGb GB',
                  color: Colors.white38),
            ],
          ),
        ],
      ),
    );
  }

  // ── Apps section ─────────────────────────────────────────────────────────────
  Widget _buildAppsSection() {
    final filtered = _filteredApps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.apps_rounded, color: _teal, size: 18),
            const SizedBox(width: 8),
            const Text('Installed Apps',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_apps.length} apps',
                style: const TextStyle(
                    color: _teal, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Search bar
        TextField(
          onChanged: (v) => setState(() => _appSearch = v),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: _teal,
          decoration: InputDecoration(
            hintText: 'Search apps...',
            hintStyle:
                TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: _teal, size: 20),
            isDense: true,
            filled: true,
            fillColor: _card,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: _teal, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // App list
        _loadingApps
            ? _buildAppsLoading()
            : filtered.isEmpty
                ? _buildAppsEmpty()
                : _buildAppsList(filtered),
      ],
    );
  }

  Widget _buildAppsLoading() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _teal.withOpacity(0.1)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _teal, strokeWidth: 2),
            SizedBox(height: 14),
            Text('Loading apps…',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppsEmpty() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _teal.withOpacity(0.1)),
      ),
      child: Center(
        child: Text('No apps found',
            style:
                TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
      ),
    );
  }

  Widget _buildAppsList(List<AppInfo> apps) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _teal.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: apps.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: Colors.white.withOpacity(0.05),
          indent: 60,
        ),
        itemBuilder: (_, i) => _AppTile(app: apps[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String topLabel;
  final String value;
  final String bottomLabel;
  final Widget? child;

  const _MetricCard({
    required this.icon,
    required this.color,
    required this.topLabel,
    required this.value,
    required this.bottomLabel,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 14,
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
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(bottomLabel,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 10.5)),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _RamChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _RamChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.35), fontSize: 10.5)),
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
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.color.withOpacity(0.3)),
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
  const _AppTile({required this.app});

  @override
  Widget build(BuildContext context) {
    final Uint8List? iconBytes = app.icon;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // App icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: iconBytes != null && iconBytes.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(iconBytes, fit: BoxFit.cover),
                  )
                : const Icon(Icons.android_rounded,
                    color: Colors.white24, size: 26),
          ),
          const SizedBox(width: 12),
          // Name & package
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.name ?? app.packageName ?? '---',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  app.packageName ?? '',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Version badge
          if (app.versionName != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'v${app.versionName}',
                style: const TextStyle(
                    color: _purple, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
