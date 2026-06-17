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
  final TextEditingController _transcriptController = TextEditingController();

  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isReturning = false;
  /// True after mic start until user taps Stop / Done — OS may still end a
  /// segment after silence; we then auto-resume [listen] so dictation continues.
  bool _dictationSessionActive = false;
  int _listenResumeGeneration = 0;
  double _confidence = 0.0;

  String _liveWords = '';
  /// Avoid appending the same dictation twice when stop/status both commit.
  String _lastAppendedLive = '';
  String _statusMessage = 'Tap the mic and start speaking...';
  String _selectedLanguage = 'en_US';

  String get _transcript {
    final saved = _transcriptController.text.trim();
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
    _transcriptController.text = widget.initialText.trim();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          if (!mounted) return;
          _dictationSessionActive = false;
          _listenResumeGeneration++;
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
      if (_dictationSessionActive && !_isReturning) {
        _commitLiveWords();
        _scheduleResumeListenAfterPause();
        return;
      }
      setState(() {
        _isListening = false;
        _statusMessage = 'Tap mic to continue speaking';
      });
    }
  }

  void _scheduleResumeListenAfterPause() {
    final gen = ++_listenResumeGeneration;
    Future(() async {
      await Future<void>.delayed(const Duration(milliseconds: 160));
      if (!mounted || gen != _listenResumeGeneration) return;
      if (!_dictationSessionActive || _isReturning) return;
      if (_speech.isListening) return;

      try {
        await _startSpeechSession();
        if (!mounted || !_dictationSessionActive || _isReturning) return;
        setState(() {
          _isListening = true;
          _statusMessage = 'Listening... Speak now';
        });
      } catch (e) {
        debugPrint('Resume listen after pause failed: $e');
        if (!mounted) return;
        setState(() {
          _dictationSessionActive = false;
          _isListening = false;
          _statusMessage = 'Tap mic to continue speaking';
        });
      }
    });
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
    _commitLiveWords();
    _lastAppendedLive = '';
    if (!mounted) return;

    _dictationSessionActive = true;
    _listenResumeGeneration++;
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
        _dictationSessionActive = false;
        _isListening = false;
        _statusMessage = 'Speech stopped. Tap mic to continue.';
      });
    }
  }

  Future<void> _startSpeechSession() async {
    await _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(minutes: 30),
      pauseFor: const Duration(minutes: 5),
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
    _dictationSessionActive = false;
    _listenResumeGeneration++;
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
    _dictationSessionActive = false;
    _listenResumeGeneration++;
    _commitLiveWords();

    if (_speech.isListening) {
      await _speech.stop();
    }

    if (mounted) {
      Navigator.of(context).pop(_transcriptController.text.trim());
    }
  }

  String _speechDedupeKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(
          RegExp(r'[^\w\s\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _speechWordKeys(String value) {
    final key = _speechDedupeKey(value);
    if (key.isEmpty) return const [];
    return key.split(' ');
  }

  String _dropAlreadySavedSpeechPrefix(String live, String saved) {
    final liveWords = live.split(RegExp(r'\s+'));
    final liveKeys = liveWords
        .map(_speechDedupeKey)
        .where((k) => k.isNotEmpty)
        .toList();
    final savedKeys = _speechWordKeys(saved);
    final maxOverlap = liveKeys.length < savedKeys.length
        ? liveKeys.length
        : savedKeys.length;

    for (var overlap = maxOverlap; overlap > 0; overlap--) {
      final savedSuffix = savedKeys.sublist(savedKeys.length - overlap);
      final livePrefix = liveKeys.take(overlap).toList();
      var same = true;
      for (var i = 0; i < overlap; i++) {
        if (savedSuffix[i] != livePrefix[i]) {
          same = false;
          break;
        }
      }
      if (same) {
        return liveWords.skip(overlap).join(' ').trim();
      }
    }
    return live;
  }

  void _commitLiveWords() {
    var live = _liveWords.trim();
    if (live.isEmpty) return;
    final saved = _transcriptController.text.trim();
    live = _dropAlreadySavedSpeechPrefix(live, saved);
    final liveKey = _speechDedupeKey(live);
    if (liveKey.isEmpty) {
      _liveWords = '';
      return;
    }

    final lastKey = _speechDedupeKey(_lastAppendedLive);
    if (liveKey == lastKey) {
      _liveWords = '';
      return;
    }

    final savedKey = _speechDedupeKey(saved);
    if (savedKey.isNotEmpty &&
        (savedKey == liveKey || savedKey.endsWith(' $liveKey'))) {
      _liveWords = '';
      _lastAppendedLive = live;
      return;
    }

    _transcriptController.text = saved.isEmpty ? live : '$saved $live';
    _transcriptController.selection = TextSelection.collapsed(
      offset: _transcriptController.text.length,
    );
    _lastAppendedLive = live;
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
    _dictationSessionActive = false;
    _listenResumeGeneration++;
    _speech.stop();
    _scrollController.dispose();
    _transcriptController.dispose();
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
                            child: Directionality(
                              textDirection: transcriptDirection,
                              child: TextField(
                                controller: _transcriptController,
                                scrollController: _scrollController,
                                minLines: 8,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                textAlign: transcriptAlign,
                                style: textTheme.bodyLarge?.copyWith(
                                  fontSize: 16,
                                  height: 1.5,
                                  color: Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Tap the mic and start speaking...',
                                  hintStyle: textTheme.bodyLarge?.copyWith(
                                    fontSize: 16,
                                    height: 1.5,
                                    color: Colors.grey.shade500,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.only(right: 12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_liveWords.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: _alignmentFor(
                              _textDirectionFor(_liveWords),
                            ),
                            child: Text(
                              'Listening: ${_liveWords.trim()}',
                              textAlign: _textAlignFor(
                                _textDirectionFor(_liveWords),
                              ),
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.purple.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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
                                  .withValues(alpha: 0.4),
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
