import 'package:flutter/material.dart';
import 'theme.dart'; // 👈 for kAppPrimary

class SpeechToTextScreen extends StatefulWidget {
  const SpeechToTextScreen({super.key});

  @override
  State<SpeechToTextScreen> createState() => _SpeechToTextScreenState();
}

class _SpeechToTextScreenState extends State<SpeechToTextScreen> {
  String transcript = "Tap the mic and start speaking...";
  bool isListening = false;

  void _toggleListening() {
    setState(() {
      isListening = !isListening;
      if (isListening) {
        transcript =
        "Once upon a time, in a magical forest, there lived a curious little dragon...";
      } else {
        transcript += "\n\n[Stopped listening]";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAppPrimary,
        centerTitle: true,
        title: const Text(
          "Speech to Text",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center( // 👈 ensures everything is centered
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Transcript card
            Container(
              width: MediaQuery.of(context).size.width * 0.85, // centered width
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  )
                ],
              ),
              child: SingleChildScrollView(
                child: Text(
                  transcript,
                  textAlign: TextAlign.center, // 👈 text also centered
                  style: textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Mic button
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 90,
                width: 90,
                decoration: BoxDecoration(
                  color: isListening ? Colors.redAccent : kAppPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isListening ? Colors.redAccent : kAppPrimary)
                          .withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  isListening ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Status text
            Text(
              isListening ? "Listening..." : "Tap to start speaking",
              style: textTheme.bodyMedium?.copyWith(
                color: isListening ? Colors.redAccent : kAppPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
