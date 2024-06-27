import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_ntp/flutter_ntp.dart';

void main() {
  runApp(const ExampleWidget());
}

class ExampleWidget extends StatelessWidget {
  const ExampleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('NTP Example')),
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              try {
                DateTime currentTime = await FlutterNTP.now();
                log('Current NTP time: $currentTime');
              } catch (e) {
                log('Error fetching NTP time: $e');
              }
            },
            child: const Text('Fetch NTP Time'),
          ),
        ),
      ),
    );
  }
}
