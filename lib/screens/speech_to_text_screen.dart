import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'theme.dart'; // your color file

class SpeechToTextScreen extends StatefulWidget {
  const SpeechToTextScreen({super.key});

  @override
  State<SpeechToTextScreen> createState() => _SpeechToTextScreenState();
}

class _SpeechToTextScreenState extends State<SpeechToTextScreen> {
  late stt.SpeechToText _speech;

  String transcript = "Tap the mic and start speaking...";
  bool isListening = false;
  double confidence = 0.0;

  // ✅ Language toggle
  String selectedLanguage = "en_US";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _toggleListening() async {
    debugPrint("Mic tapped");

    if (!isListening) {
      // ✅ Request permission
      var status = await Permission.microphone.request();

      if (!status.isGranted) {
        setState(() {
          transcript = "Microphone permission denied";
        });
        return;
      }

      bool available = await _speech.initialize(
        onStatus: (status) {
          debugPrint("Status: $status");

          if (status == "done" || status == "notListening") {
            setState(() => isListening = false);
          }
        },
        onError: (error) {
          debugPrint("Error: $error");

          // 🔥 Ignore no_match error
          if (error.errorMsg == "error_no_match") return;

          setState(() {
            isListening = false;
            transcript = "Error: ${error.errorMsg}";
          });
        },
      );

      if (available) {
        setState(() {
          isListening = true;
          transcript = "Listening... Speak now";
        });

        _speech.listen(
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 10),
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
          localeId: selectedLanguage, // ✅ Urdu / English
          onResult: (result) {
            setState(() {
              transcript = result.recognizedWords;

              if (result.hasConfidenceRating && result.confidence > 0) {
                confidence = result.confidence;
              }
            });
          },
        );
      } else {
        setState(() {
          transcript = "Speech recognition not available";
          isListening = false;
        });
      }
    } else {
      // ✅ Stop listening
      setState(() => isListening = false);
      await _speech.stop();

      if (mounted) {
        Navigator.of(context).pop(transcript);
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
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
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ Language Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text("English"),
                    selected: selectedLanguage == "en_US",
                    onSelected: (_) {
                      setState(() => selectedLanguage = "en_US");
                    },
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text("اردو"),
                    selected: selectedLanguage == "ur_PK",
                    onSelected: (_) {
                      setState(() => selectedLanguage = "ur_PK");
                    },
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Transcript card
              Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      transcript,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (confidence > 0)
                      Text(
                        "Confidence: ${(confidence * 100).toStringAsFixed(1)}%",
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ✅ Mic Button (FIXED)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(50),
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
                          color: (isListening
                              ? Colors.redAccent
                              : kAppPrimary)
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
              ),

              const SizedBox(height: 30),

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
      ),
    );
  }
}