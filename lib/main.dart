import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/mcspace.png', width: 200),
            const SizedBox(height: 20),
            const Text('MCSpace iOS Deployment Placeholder'),
          ],
        ),
      ),
    ),
  ));
}
