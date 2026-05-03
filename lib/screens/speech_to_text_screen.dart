import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
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
  final ScrollController _scrollController = ScrollController();

  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isReturning = false;
  double _confidence = 0.0;

  String _savedText = '';
  String _liveWords = '';
  String _statusMessage = 'Tap the mic and start speaking...';
  String _selectedLanguage = 'en_US';

  String get _transcript {
    final saved = _savedText.trim();
    final live = _liveWords.trim();
    if (saved.isEmpty) return live;
    if (live.isEmpty) return saved;
    return '$saved $live';
  }

  bool get _isUrduSelected => _selectedLanguage == 'ur_PK';

  bool _containsUrdu(String value) {
    return RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]').hasMatch(value);
  }

  TextDirection _textDirectionFor(String value) {
    return _isUrduSelected || _containsUrdu(value)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  TextAlign _textAlignFor(TextDirection direction) {
    return direction == TextDirection.rtl ? TextAlign.right : TextAlign.left;
  }

  Alignment _alignmentFor(TextDirection direction) {
    return direction == TextDirection.rtl
        ? Alignment.centerRight
        : Alignment.centerLeft;
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _savedText = widget.initialText.trim();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          if (!mounted) return;
          _commitLiveWords();
          setState(() {
            _isListening = false;
            _statusMessage = 'Speech stopped. Tap mic to continue.';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _speechEnabled = available;
        _statusMessage = available
            ? 'Tap the mic and start speaking...'
            : 'Speech recognition not available';
      });
    } catch (e) {
      debugPrint('Speech initialize error: $e');
      if (!mounted) return;
      setState(() {
        _speechEnabled = false;
        _statusMessage = 'Speech recognition not available';
      });
    }
  }

  void _onSpeechStatus(String status) {
    debugPrint('Speech status: $status');
    if (!mounted || _isReturning) return;

    if (status == 'listening') {
      setState(() {
        _isListening = true;
        _statusMessage = 'Listening... Speak now';
      });
      return;
    }

    if (status == 'done' || status == 'notListening') {
      _commitLiveWords();
      setState(() {
        _isListening = false;
        _statusMessage = 'Tap mic to continue speaking';
      });
    }
  }

  Future<void> _startListening() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Microphone permission denied');
      return;
    }

    if (!_speechEnabled) {
      await _initializeSpeech();
      if (!_speechEnabled) return;
    }

    if (!mounted) return;
    setState(() {
      _liveWords = '';
      _confidence = 0.0;
      _isListening = true;
      _statusMessage = 'Listening... Speak now';
    });

    try {
      await _startSpeechSession();
    } catch (e) {
      debugPrint('Speech listen error: $e');
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _statusMessage = 'Speech stopped. Tap mic to continue.';
      });
    }
  }

  Future<void> _startSpeechSession() async {
    await _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(minutes: 10),
      pauseFor: const Duration(seconds: 20),
      localeId: _selectedLanguage,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
        autoPunctuation: true,
      ),
    );
  }

  Future<void> _stopListening() async {
    _commitLiveWords();
    await _speech.stop();
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _statusMessage = 'Tap mic to continue speaking';
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;

    setState(() {
      _liveWords = result.recognizedWords;
      if (result.hasConfidenceRating && result.confidence > 0) {
        _confidence = result.confidence;
      }
    });

    _scrollTranscriptToEnd();
  }

  Future<void> _finishAndReturn() async {
    if (_isReturning) return;
    _isReturning = true;
    _commitLiveWords();

    if (_speech.isListening) {
      await _speech.stop();
    }

    if (mounted) {
      Navigator.of(context).pop(_transcript.trim());
    }
  }

  void _commitLiveWords() {
    final live = _liveWords.trim();
    if (live.isEmpty) return;

    final saved = _savedText.trim();
    _savedText = saved.isEmpty ? live : '$saved $live';
    _liveWords = '';
  }

  void _scrollTranscriptToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final transcript = _transcript.trim();
    final transcriptDirection = _textDirectionFor(transcript);
    final transcriptAlign = _textAlignFor(transcriptDirection);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finishAndReturn();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: kAppPrimary,
          centerTitle: true,
          title: const Text(
            'Speech to Text',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            TextButton(
              onPressed: _finishAndReturn,
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('English'),
                        selected: _selectedLanguage == 'en_US',
                        onSelected: _isListening
                            ? null
                            : (_) => setState(
                                  () => _selectedLanguage = 'en_US',
                                ),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('Urdu'),
                        selected: _selectedLanguage == 'ur_PK',
                        onSelected: _isListening
                            ? null
                            : (_) => setState(
                                  () => _selectedLanguage = 'ur_PK',
                                ),
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
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 160,
                            maxHeight: 280,
                          ),
                          child: Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              reverse: _isUrduSelected,
                              padding: const EdgeInsets.only(right: 12),
                              child: Align(
                                alignment: _alignmentFor(transcriptDirection),
                                child: Directionality(
                                  textDirection: transcriptDirection,
                                  child: Text(
                                    transcript.isEmpty
                                        ? 'Tap the mic and start speaking...'
                                        : transcript,
                                    textAlign: transcriptAlign,
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontSize: 16,
                                      height: 1.5,
                                      color: transcript.isEmpty
                                          ? Colors.grey.shade500
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color:
                                _isListening ? Colors.redAccent : Colors.grey,
                            fontWeight: _isListening
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_confidence > 0)
                          Text(
                            'Confidence: ${(_confidence * 100).toStringAsFixed(1)}%',
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
                      onTap: _isListening ? _stopListening : _startListening,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 90,
                        width: 90,
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.redAccent : kAppPrimary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening
                                      ? Colors.redAccent
                                      : kAppPrimary)
                                  .withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    _isListening ? 'Listening...' : 'Tap to continue speaking',
                    style: textTheme.bodyMedium?.copyWith(
                      color: _isListening ? Colors.redAccent : kAppPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
