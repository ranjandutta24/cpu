import 'dart:convert';

import 'package:cpu/theme/app_theme.dart';
import 'package:cpu/utils/drawer.dart';
import 'package:cpu/utils/function.dart';
import 'package:eventsource/eventsource.dart';
import 'package:flutter/material.dart';

class LiveProcessScreen extends StatefulWidget {
  const LiveProcessScreen({super.key});

  @override
  State<LiveProcessScreen> createState() => _LiveProcessScreenState();
}

class _LiveProcessScreenState extends State<LiveProcessScreen>
    with WidgetsBindingObserver {
  EventSource? _eventSource;

  // System summary
  int _totalProcesses = 0;
  int _runningProcesses = 0;
  int _blockedProcesses = 0;
  DateTime? _lastUpdated;

  // Process list
  List<Map<String, dynamic>> _allProcesses = [];
  List<Map<String, dynamic>> _filtered = [];

  // Sort state
  _SortField _sortField = _SortField.cpu;
  bool _sortAsc = false;

  // Search
  final TextEditingController _search = TextEditingController();
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _search.addListener(_applyFilter);
    _connect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _eventSource?.client.close();
      _connect();
    }
  }

  void _connect() async {
    try {
      final ip = getIp();
      final link = 'http://$ip:3000/detail/live';
      _eventSource = await EventSource.connect(link);
      if (mounted) setState(() => _connected = true);

      _eventSource?.listen((event) {
        if (!mounted) return;
        final raw = event.data ?? '{}';
        final data = jsonDecode(raw) as Map<String, dynamic>;

        final sys = data['system'] as Map<String, dynamic>? ?? {};
        final procs = (data['processes'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

        setState(() {
          _totalProcesses   = (sys['totalProcesses']   as num?)?.toInt() ?? 0;
          _runningProcesses = (sys['runningProcesses'] as num?)?.toInt() ?? 0;
          _blockedProcesses = (sys['blockedProcesses'] as num?)?.toInt() ?? 0;
          _lastUpdated      = DateTime.now();
          _allProcesses     = procs;
          _applyFilter();
        });
      });
    } catch (e) {
      debugPrint('SSE error: $e');
      if (mounted) setState(() => _connected = false);
    }
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    var list = q.isEmpty
        ? List<Map<String, dynamic>>.from(_allProcesses)
        : _allProcesses
            .where((p) =>
                (p['name'] as String? ?? '').toLowerCase().contains(q) ||
                p['pid'].toString().contains(q))
            .toList();

    list.sort((a, b) {
      double aVal, bVal;
      switch (_sortField) {
        case _SortField.pid:
          aVal = (a['pid'] as num?)?.toDouble() ?? 0;
          bVal = (b['pid'] as num?)?.toDouble() ?? 0;
        case _SortField.cpu:
          aVal = (a['cpuPercent'] as num?)?.toDouble() ?? 0;
          bVal = (b['cpuPercent'] as num?)?.toDouble() ?? 0;
        case _SortField.mem:
          aVal = (a['memoryPercent'] as num?)?.toDouble() ?? 0;
          bVal = (b['memoryPercent'] as num?)?.toDouble() ?? 0;
        case _SortField.name:
          return _sortAsc
              ? (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '')
              : (b['name'] as String? ?? '').compareTo(a['name'] as String? ?? '');
      }
      return _sortAsc ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
    });

    _filtered = list;
  }

  void _sort(_SortField field) {
    setState(() {
      if (_sortField == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortField = field;
        _sortAsc = false;
      }
      _applyFilter();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    _eventSource?.client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSec =
        isDark ? AppColors.darkTextSecond : AppColors.lightTextSecond;

    return Scaffold(
      drawer: const CustomDrawer(username: 'Admin', role: 'Admin', email: 'NA'),
      appBar: AppBar(
        title: const Text(
          'Live Processes',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          // Live indicator
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseDot(active: _connected),
                const SizedBox(width: 6),
                Text(
                  _connected ? 'LIVE' : 'OFF',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _connected ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Summary cards ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                _SummaryChip(
                  label: 'Total',
                  value: '$_totalProcesses',
                  color: AppColors.accentTeal,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: 'Running',
                  value: '$_runningProcesses',
                  color: AppColors.success,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: 'Blocked',
                  value: '$_blockedProcesses',
                  color: AppColors.error,
                  isDark: isDark,
                ),
                const Spacer(),
                if (_lastUpdated != null)
                  Text(
                    _fmtTime(_lastUpdated!),
                    style: TextStyle(fontSize: 10, color: textSec),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Search bar ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search by name or PID…',
                prefixIcon: Icon(Icons.search_rounded,
                    size: 18,
                    color: isDark
                        ? AppColors.darkTextSecond
                        : AppColors.lightTextSecond),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded,
                            size: 16,
                            color: isDark
                                ? AppColors.darkTextSecond
                                : AppColors.lightTextSecond),
                        onPressed: () {
                          _search.clear();
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Table header ───────────────────────────
          _TableHeader(
            sortField: _sortField,
            sortAsc: _sortAsc,
            onSort: _sort,
            isDark: isDark,
          ),

          // ── Process rows ───────────────────────────
          Expanded(
            child: _allProcesses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentTeal,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Connecting…',
                            style:
                                TextStyle(color: textSec, fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) => _ProcessRow(
                      proc: _filtered[i],
                      isDark: isDark,
                      isEven: i.isEven,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

// ──────────────────────────────────────────────
// Sort field enum
// ──────────────────────────────────────────────

enum _SortField { pid, name, cpu, mem }

// ──────────────────────────────────────────────
// Summary chip
// ──────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextSecond : AppColors.lightTextSecond,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Table header with sort buttons
// ──────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  final _SortField sortField;
  final bool sortAsc;
  final void Function(_SortField) onSort;
  final bool isDark;

  const _TableHeader({
    required this.sortField,
    required this.sortAsc,
    required this.onSort,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? AppColors.darkSurface
        : AppColors.lightInputFill;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _HeaderCell('PID',  flex: 2, field: _SortField.pid,  sortField: sortField, sortAsc: sortAsc, onSort: onSort, isDark: isDark),
          _HeaderCell('NAME', flex: 5, field: _SortField.name, sortField: sortField, sortAsc: sortAsc, onSort: onSort, isDark: isDark),
          _HeaderCell('CPU %', flex: 2, field: _SortField.cpu, sortField: sortField, sortAsc: sortAsc, onSort: onSort, isDark: isDark, alignRight: true),
          _HeaderCell('MEM %', flex: 2, field: _SortField.mem, sortField: sortField, sortAsc: sortAsc, onSort: onSort, isDark: isDark, alignRight: true),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String title;
  final int flex;
  final _SortField field;
  final _SortField sortField;
  final bool sortAsc;
  final void Function(_SortField) onSort;
  final bool isDark;
  final bool alignRight;

  const _HeaderCell(
    this.title, {
    required this.flex,
    required this.field,
    required this.sortField,
    required this.sortAsc,
    required this.onSort,
    required this.isDark,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = sortField == field;
    final color = active
        ? AppColors.accentTeal
        : (isDark ? AppColors.darkTextSecond : AppColors.lightTextSecond);

    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => onSort(field),
        child: Row(
          mainAxisAlignment:
              alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: color,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 3),
              Icon(
                sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 10,
                color: color,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Process row
// ──────────────────────────────────────────────

class _ProcessRow extends StatelessWidget {
  final Map<String, dynamic> proc;
  final bool isDark;
  final bool isEven;

  const _ProcessRow({
    required this.proc,
    required this.isDark,
    required this.isEven,
  });

  @override
  Widget build(BuildContext context) {
    final cpu = (proc['cpuPercent'] as num?)?.toDouble() ?? 0;
    final mem = (proc['memoryPercent'] as num?)?.toDouble() ?? 0;
    final name = proc['name'] as String? ?? '—';
    final pid  = proc['pid']?.toString() ?? '—';

    // Color-code CPU heat
    Color cpuColor;
    if (cpu >= 50) {
      cpuColor = AppColors.error;
    } else if (cpu >= 15) {
      cpuColor = AppColors.warning;
    } else {
      cpuColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    }

    final rowBg = isDark
        ? (isEven ? AppColors.darkBg : AppColors.darkSurface)
        : (isEven ? AppColors.lightBg : AppColors.lightSurface);

    final textSec = isDark ? AppColors.darkTextSecond : AppColors.lightTextSecond;

    return Container(
      color: rowBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // PID
          Expanded(
            flex: 2,
            child: Text(
              pid,
              style: TextStyle(
                fontSize: 11,
                color: textSec,
                fontFamily: 'monospace',
              ),
            ),
          ),
          // Name + started
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                if ((proc['started'] as String? ?? '').isNotEmpty)
                  Text(
                    proc['started'] as String,
                    style: TextStyle(fontSize: 9, color: textSec),
                  ),
              ],
            ),
          ),
          // CPU %
          Expanded(
            flex: 2,
            child: Text(
              '${cpu.toStringAsFixed(2)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cpuColor,
              ),
            ),
          ),
          // MEM %
          Expanded(
            flex: 2,
            child: Text(
              '${mem.toStringAsFixed(2)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ramChart,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Pulsing live dot
// ──────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final bool active;
  const _PulseDot({required this.active});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? AppColors.success : AppColors.error;
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
