import 'package:cpu/stats.dart';
import 'package:cpu/utils/function.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InitScreen extends StatefulWidget {
  const InitScreen({super.key});
  @override
  State<InitScreen> createState() {
    return _InitScreenState();
  }
}

class _InitScreenState extends State<InitScreen> {
  final TextEditingController _ip = TextEditingController();
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _ip.text = "192.168.31.16";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ip'),
      ),
      body: Column(
        children: [
          TextField(
            controller: _ip,
            decoration: InputDecoration(
              // prefixIcon: Icon(icon, color: colorTheme(context)['primary']),
              labelText: 'IP Address',
              isDense: true,
              labelStyle: const TextStyle(
                color: Color.fromARGB(255, 87, 87, 87),
              ),
              filled: true,
              fillColor: const Color.fromARGB(255, 240, 240, 240),

              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: Color.fromARGB(255, 31, 98, 108),
                ), // Set your desired border color
                borderRadius: BorderRadius.circular(9.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: Color.fromARGB(255, 61, 157, 170),
                ), // Set your desired border color
                borderRadius: BorderRadius.circular(9.0),
              ),
              // border: OutlineInputBorder(
              //   borderRadius: BorderRadius.circular(16.0),
              //   borderSide: BorderSide.none,
              // ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              saveIp(_ip.text);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const SystemStatsRow(),
                ),
              );
              print(_ip.text);
            },
            style: ElevatedButton.styleFrom(
              // backgroundColor:
              //     colorTheme(context)['primary'],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              textStyle: const TextStyle(fontSize: 18),
            ),
            child: const Text(
              'Enter',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
