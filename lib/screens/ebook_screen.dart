import 'package:flutter/material.dart';

class EBookScreen extends StatelessWidget {
  const EBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E6), // soft background color
      body: Center(
        child: Text(
          'Coming Soon 🚀',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.deepOrange,
          ),
        ),
      ),
    );
  }
}
