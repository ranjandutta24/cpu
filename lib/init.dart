import 'package:cpu/screens/dashboard.dart';
import 'package:cpu/screens/phone_monitor.dart';
import 'package:cpu/theme/app_theme.dart';
import 'package:cpu/utils/function.dart';
import 'package:flutter/material.dart';

class InitScreen extends StatefulWidget {
  const InitScreen({super.key});

  @override
  State<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ip = TextEditingController();

  String? _selected; // 'cpu' | 'mobile' | null

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ip.text = '192.168.31.16';
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ip.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _selectMode(String mode) {
    if (_selected == mode) {
      setState(() => _selected = null);
      _fadeCtrl.reverse();
    } else {
      setState(() => _selected = mode);
      _fadeCtrl.forward(from: 0);
    }
  }

  void _connectCPU() {
    if (_ip.text.trim().isEmpty) return;
    saveIp(_ip.text.trim());
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SystemStatsRow()),
    );
  }

  void _openMobileMonitor() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhoneMonitorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.bg, c.bgGradMid, c.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Logo ─────────────────────────────────────────────
                  const _Logo(),

                  const SizedBox(height: 28),

                  // ── Headline ──────────────────────────────────────────
                  Text(
                    'System Monitor',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose a monitoring mode to get started',
                    style: TextStyle(color: c.textSecond, fontSize: 13.5),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 36),

                  // ── Mode Selector Cards ───────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _ModeCard(
                          selected: _selected == 'cpu',
                          icon: Icons.computer_rounded,
                          label: 'CPU Monitor',
                          subtitle: 'Remote desktop / server',
                          color: AppColors.accentTeal,
                          onTap: () => _selectMode('cpu'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _ModeCard(
                          selected: _selected == 'mobile',
                          icon: Icons.smartphone_rounded,
                          label: 'Mobile Monitor',
                          subtitle: 'This device stats & apps',
                          color: AppColors.accentPurple,
                          onTap: () => _selectMode('mobile'),
                        ),
                      ),
                    ],
                  ),

                  // ── Animated expand area ──────────────────────────────
                  SizeTransition(
                    sizeFactor: _fadeAnim,
                    axisAlignment: -1,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: _selected == 'cpu'
                            ? _CPUConnectPanel(
                                controller: _ip,
                                onConnect: _connectCPU,
                              )
                            : _selected == 'mobile'
                                ? _MobilePanel(onOpen: _openMobileMonitor)
                                : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo
// ─────────────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.accentTealDark, AppColors.accentTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentTeal.withOpacity(0.35),
            blurRadius: 28,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(
        Icons.monitor_heart_outlined,
        size: 40,
        color: Colors.white,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode Selector Card
// ─────────────────────────────────────────────────────────────────────────────

class _ModeCard extends StatefulWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c      = AppColors.of(context);
    final active = widget.selected || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.color.withOpacity(0.08)
                : c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? widget.color.withOpacity(0.6)
                  : widget.color.withOpacity(0.2),
              width: widget.selected ? 1.6 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.selected
                    ? widget.color.withOpacity(0.18)
                    : Colors.black.withOpacity(0.12),
                blurRadius: widget.selected ? 20 : 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: widget.color, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                widget.label,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: TextStyle(color: c.textSecond, fontSize: 11.5),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: widget.selected ? 20 : 14,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: widget.selected
                          ? widget.color
                          : widget.color.withOpacity(0.25),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: widget.color.withOpacity(0.25),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CPU Connect Panel
// ─────────────────────────────────────────────────────────────────────────────

class _CPUConnectPanel extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onConnect;

  const _CPUConnectPanel(
      {required this.controller, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.accentTeal.withOpacity(0.22), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.wifi_tethering_rounded,
                  color: AppColors.accentTeal, size: 18),
              const SizedBox(width: 8),
              Text(
                'Connect to Host',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'IP ADDRESS',
            style: TextStyle(
              color: c.textHint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          // Input field
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
            cursorColor: AppColors.accentTeal,
            decoration: InputDecoration(
              hintText: '192.168.x.x',
              hintStyle: TextStyle(color: c.textHint, fontSize: 14),
              prefixIcon: const Icon(Icons.wifi_outlined,
                  color: AppColors.accentTeal, size: 20),
              isDense: true,
              filled: true,
              fillColor: c.inputFill,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 16, horizontal: 14),
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
                    color: AppColors.accentTeal, width: 1.5),
              ),
            ),
            onSubmitted: (_) => onConnect(),
          ),
          const SizedBox(height: 20),
          // Connect button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [
                    AppColors.accentTealDark,
                    AppColors.accentTeal
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentTeal.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.link_rounded, size: 20),
                label: const Text(
                  'Connect',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile Monitor Panel
// ─────────────────────────────────────────────────────────────────────────────

class _MobilePanel extends StatelessWidget {
  final VoidCallback onOpen;
  const _MobilePanel({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.accentPurple.withOpacity(0.22), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentPurple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.smartphone_rounded,
                    color: AppColors.accentPurple, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mobile Monitor',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Monitor this device in real-time',
                    style:
                        TextStyle(color: c.textSecond, fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _FeatureChip(
                  icon: Icons.battery_full_rounded, label: 'Battery'),
              _FeatureChip(
                  icon: Icons.memory_rounded, label: 'RAM'),
              _FeatureChip(icon: Icons.apps_rounded, label: 'Apps'),
              _FeatureChip(
                  icon: Icons.storage_rounded, label: 'Storage'),
              _FeatureChip(
                  icon: Icons.thermostat_rounded, label: 'Temp'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [
                    AppColors.accentPurpleDark,
                    AppColors.accentPurple
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentPurple.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onOpen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon:
                    const Icon(Icons.open_in_new_rounded, size: 20),
                label: const Text(
                  'Open Monitor',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: AppColors.accentPurple.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accentPurple, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
                color: AppColors.accentPurple,
                fontSize: 11.5,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
