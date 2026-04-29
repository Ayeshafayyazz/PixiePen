import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'theme.dart';

class SpeechToTextScreen extends StatefulWidget {
  final String initialText;

  const SpeechToTextScreen({
    super.key,
    this.initialText = '',
  });

  @override
  State<SpeechToTextScreen> createState() => _SpeechToTextScreenState();
}

class _SpeechToTextScreenState extends State<SpeechToTextScreen> {
  late final stt.SpeechToText _speech;
  late final TextEditingController _transcriptController;

  String _statusMessage = "Tap the mic and start speaking...";
  String _textBeforeListening = '';
  bool isListening = false;
  bool _isReturning = false;
  double confidence = 0.0;

  String selectedLanguage = "en_US";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _transcriptController = TextEditingController(text: widget.initialText);
  }

  Future<void> _toggleListening() async {
    debugPrint("Mic tapped");

    if (!isListening) {
      final status = await Permission.microphone.request();

      if (!status.isGranted) {
        setState(() {
          _statusMessage = "Microphone permission denied";
        });
        return;
      }

      final available = await _speech.initialize(
        onStatus: (status) {
          debugPrint("Status: $status");

          if ((status == "done" || status == "notListening") &&
              mounted &&
              isListening &&
              !_isReturning) {
            Future.microtask(_finishAndReturn);
          }
        },
        onError: (error) {
          debugPrint("Error: $error");

          if (error.errorMsg == "error_no_match") return;
          if (!mounted) return;

          setState(() {
            isListening = false;
            _statusMessage = "Error: ${error.errorMsg}";
          });
        },
      );

      if (available) {
        _textBeforeListening = _transcriptController.text.trimRight();
        setState(() {
          isListening = true;
          _statusMessage = "Listening... Speak now";
        });

        await _speech.listen(
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 10),
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
          localeId: selectedLanguage,
          onResult: (result) {
            if (!mounted) return;

            final spokenWords = result.recognizedWords.trim();
            final separator =
                _textBeforeListening.isEmpty || spokenWords.isEmpty ? '' : ' ';
            final updatedText = '$_textBeforeListening$separator$spokenWords';

            setState(() {
              _transcriptController.value = TextEditingValue(
                text: updatedText,
                selection: TextSelection.collapsed(offset: updatedText.length),
              );

              if (result.hasConfidenceRating && result.confidence > 0) {
                confidence = result.confidence;
              }
            });
          },
        );
      } else {
        setState(() {
          _statusMessage = "Speech recognition not available";
          isListening = false;
        });
      }
    } else {
      await _finishAndReturn();
    }
  }

  Future<void> _stopListening() async {
    setState(() => isListening = false);
    await _speech.stop();
  }

  Future<void> _finishAndReturn() async {
    if (_isReturning) return;
    _isReturning = true;

    if (isListening) {
      await _stopListening();
    }

    if (mounted) {
      Navigator.of(context).pop(_transcriptController.text.trim());
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _transcriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return WillPopScope(
      onWillPop: () async {
        await _finishAndReturn();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: kAppPrimary,
          centerTitle: true,
          title: const Text(
            "Speech to Text",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            TextButton(
              onPressed: _finishAndReturn,
              child: const Text(
                "Done",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                      label: const Text("Urdu"),
                      selected: selectedLanguage == "ur_PK",
                      onSelected: (_) {
                        setState(() => selectedLanguage = "ur_PK");
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 30),
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
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _transcriptController,
                        minLines: 6,
                        maxLines: 12,
                        textAlign: TextAlign.start,
                        decoration: InputDecoration(
                          hintText:
                              "Tap the mic and start speaking, or type here...",
                          border: InputBorder.none,
                          hintStyle: textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                        ),
                        style: textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: isListening ? Colors.redAccent : Colors.grey,
                          fontWeight: isListening
                              ? FontWeight.w600
                              : FontWeight.normal,
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
                            color:
                                (isListening ? Colors.redAccent : kAppPrimary)
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
                  isListening ? "Listening..." : "Tap to continue speaking",
                  style: textTheme.bodyMedium?.copyWith(
                    color: isListening ? Colors.redAccent : kAppPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
