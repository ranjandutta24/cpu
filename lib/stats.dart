import 'package:cpu/utils/function.dart';
import 'package:flutter/material.dart';
import 'package:eventsource/eventsource.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:async';

class SystemStatsRow extends StatefulWidget {
  const SystemStatsRow({super.key});

  @override
  _SystemStatsRowState createState() => _SystemStatsRowState();
}

class _SystemStatsRowState extends State<SystemStatsRow> {
  Map<String, dynamic> _stats = {
    'cpuUsage': '0.0',
    'ramUsage': '0.0',
    'totalRam': '0.0',
    'diskUsage': '0.0',
  };

  List<FlSpot> _cpuPoints = [];
  List<FlSpot> _ramPoints = [];
  List<String> _timeLabels = [];
  String ip = "";

  Timer? _timer;
  double _xValue = 0;

  @override
  void initState() {
    super.initState();
    ip = getIp();
    _startListening();
  }

// 192.168.31.16
  void _startListening() async {
    try {
      var link = 'http://${ip.toString()}:3000/stats';
      print("dfgg" + link);

      final source = await EventSource.connect(link);

      source.listen((event) {
        final data = jsonDecode(event.data ?? '{}');

        setState(() {
          _stats = data;

          // Update time
          _xValue += 1;
          final now = DateTime.now();
          final formattedTime = "${now.hour}:${now.minute}:${now.second}";
          _timeLabels.add(formattedTime);

          // Add CPU and RAM points
          _cpuPoints.add(FlSpot(
              _xValue, double.tryParse(data['cpuUsage'].toString()) ?? 0));
          _ramPoints.add(FlSpot(
              _xValue, double.tryParse(data['ramUsage'].toString()) ?? 0));

          // Keep only last 30 points
          if (_cpuPoints.length > 30) {
            _cpuPoints.removeAt(0);
            _timeLabels.removeAt(0);
          }
          if (_ramPoints.length > 30) {
            _ramPoints.removeAt(0);
          }
        });
      });
    } catch (e) {
      print("SSE error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Stats'),
        backgroundColor: const Color.fromARGB(255, 138, 173, 32),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStat('CPU', '${_stats['cpuUsage']} %'),
              _buildStat(
                  'RAM', '${_stats['ramUsage']} % of ${_stats['totalRam']} GB'),
              _buildStat('Disk', '${_stats['diskUsage']} %'),
            ],
          ),
          SizedBox(height: 20),
          Text('CPU Usage Over Time',
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          _buildChart(_cpuPoints, Colors.blue),
          SizedBox(height: 20),
          Text('RAM Usage Over Time',
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          _buildChart(_ramPoints, const Color.fromARGB(255, 112, 175, 76)),
        ],
      ),
    );
  }

  Widget _buildChart(List<FlSpot> points, Color color) {
    return Container(
      height: 200,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            // leftTitles: AxisTitles(
            //   sideTitles: SideTitles(showTitles: true),
            // ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < _timeLabels.length) {
                    return Text(_timeLabels[index],
                        style: TextStyle(fontSize: 10));
                  }
                  return Text('');
                },
                reservedSize: 32,
                interval: 5,
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              color: color,
              barWidth: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
