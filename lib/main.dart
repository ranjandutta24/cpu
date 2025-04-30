import 'package:cpu/init.dart';
import 'package:cpu/stats.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: Text("System Monitor")),
      body: SafeArea(child: Center(child: InitScreen())),
    ),
  ));
}
