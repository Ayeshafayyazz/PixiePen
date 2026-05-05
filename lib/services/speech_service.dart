import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

typedef RecognitionCallback = void Function(String recognizedText);

/// A small wrapper around the `speech_to_text` package to encapsulate
/// initialization and listening logic. Keeps the screen code focused on UI.
class SpeechService {
  stt.SpeechToText? _speech;
  bool _initialized = false;

  bool get isAvailable => _speech?.isAvailable ?? false;
  bool get isListening => _speech?.isListening ?? false;

  /// Initialize the underlying speech engine. Returns true when ready.
  Future<bool> initialize() async {
    _speech ??= stt.SpeechToText();
    try {
      _initialized = await _speech!.initialize(
        onStatus: (status) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('SpeechService status: $status');
          }
        },
        onError: (error) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('SpeechService error: $error');
          }
        },
      );
    } catch (e) {
      _initialized = false;
    }
    return _initialized;
  }

  /// Check and request microphone permission. Returns the final permission status.
  Future<PermissionStatus> checkAndRequestMicrophonePermission() async {
    final status = await Permission.microphone.status;

    if (status.isGranted) return status;

    if (status.isDenied) {
      // Request permission once
      final result = await Permission.microphone.request();
      return result;
    }

    // If it's permanently denied, restricted, or limited, return the status as-is.
    return status;
  }

  /// Open the platform app settings so the user can manually grant permissions.
  Future<bool> openAppSettingsPage() async => openAppSettings();

  /// Start listening and invoke [onResult] when recognition updates.
  /// Returns `null` if listening started successfully. Otherwise returns an
  /// error message describing why it could not start (e.g., permissions,
  /// device not supported, etc.).
  Future<String?> startListening(RecognitionCallback onResult) async {
    // Ensure microphone permission is granted.
    final permission = await checkAndRequestMicrophonePermission();
    if (!permission.isGranted) {
      if (permission.isPermanentlyDenied) {
        return 'permission_permanently_denied';
      }
      return 'Microphone permission is required to use speech recognition.';
    }

    // Ensure initialized (this will also request permission when needed).
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        return 'Speech recognition is not available or permission was denied.';
      }
    }

    if (!isAvailable) {
      return 'Speech recognition is not available on this device.';
    }

    try {
      _speech!.listen(
        onResult: (result) => onResult(result.recognizedWords),
        listenFor: const Duration(minutes: 1),
        pauseFor: const Duration(seconds: 3),
        onSoundLevelChange: null,
      );
      return null; // success
    } catch (e) {
      // Provide a helpful message for debugging / user guidance.
      final msg = e.toString();
      if (kDebugMode) {
        // ignore: avoid_print
        print('SpeechService.startListening error: $msg');
      }
      return 'Failed to start speech recognition: $msg';
    }
  }

  /// Stop listening. Safe to call when not listening.
  Future<void> stopListening() async {
    if (_speech != null && _speech!.isListening) {
      await _speech!.stop();
    }
  }
}
