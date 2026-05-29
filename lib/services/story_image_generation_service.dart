import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/generated_story_image.dart';
import 'content_moderation_service.dart';
import 'gemini_service.dart';

/// Thrown when the image API returns an error or an unexpected payload.
class ImageGenerationException implements Exception {
  final String message;
  ImageGenerationException(this.message);

  @override
  String toString() => message;
}

/// Text-to-image integration.
///
/// **Production:** Set compile-time flag `IMAGE_GEN_API_URL` to your HTTPS
/// endpoint (e.g. Firebase Cloud Function or Cloud Run) that:
/// - Validates the user (e.g. `Authorization: Bearer <Firebase ID token>` when
///   `IMAGE_GEN_SEND_AUTH=true`).
/// - Calls Stability AI (see `imagegen/`) with **server-side** key from `imagegen/.env`.
/// - Returns JSON the client can parse (see [_parseImagesFromJson]).
///
/// If no URL is set (dart-define or root `.env` `IMAGE_GEN_API_URL`), returns
/// deterministic placeholder URLs.
///
/// Example `flutter run` / build:
/// `flutter run --dart-define=IMAGE_GEN_API_URL=https://.../generateStoryImages --dart-define=IMAGE_GEN_SEND_AUTH=true`
class StoryImageGenerationService {
  StoryImageGenerationService({
    http.Client? httpClient,
    FirebaseAuth? auth,
    GeminiService? geminiService,
  })  : _http = httpClient ?? http.Client(),
        _auth = auth ?? FirebaseAuth.instance,
        _geminiService = geminiService ?? GeminiService();

  static const String _apiUrlFromDefine = String.fromEnvironment(
    'IMAGE_GEN_API_URL',
    defaultValue: '',
  );

  static String get _apiUrl {
    if (_apiUrlFromDefine.isNotEmpty) return _apiUrlFromDefine;
    return dotenv.env['IMAGE_GEN_API_URL']?.trim() ?? '';
  }

  static const bool _sendAuth = bool.fromEnvironment(
    'IMAGE_GEN_SEND_AUTH',
    defaultValue: false,
  );

  final http.Client _http;
  final FirebaseAuth _auth;
  final GeminiService _geminiService;

  /// Returns generated images with storage URLs and optional bytes for web display.
  Future<List<GeneratedStoryImage>> generateImages(
    String prompt, {
    int count = 4,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return [];
    final imagePrompt = await _prepareChildSafePrompt(trimmed);

    if (_apiUrl.isEmpty) {
      return _placeholderImages(imagePrompt, count);
    }

    final uri = Uri.parse(_apiUrl);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_sendAuth) {
      final token = await _auth.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    late final http.Response response;
    try {
      response = await _http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'prompt': imagePrompt, 'n': count}),
          )
          .timeout(const Duration(minutes: 3));
    } on TimeoutException {
      throw ImageGenerationException(
        'Image generation timed out. Try again or use a shorter prompt.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _parseErrorMessage(response.body);
      throw ImageGenerationException(
        message ?? 'Image API failed (${response.statusCode}).',
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    final images = _parseImagesFromJson(decoded);
    if (images.isEmpty) {
      throw ImageGenerationException(
        'Image API returned no images. Check response shape.',
      );
    }
    return images;
  }

  /// URL-only convenience wrapper.
  Future<List<String>> generateImageUrls(
    String prompt, {
    int count = 4,
  }) async {
    final images = await generateImages(prompt, count: count);
    return images.map((image) => image.url).toList();
  }

  Future<String> _prepareChildSafePrompt(String prompt) async {
    final safe = await _geminiService.moderateContent(prompt);
    if (!safe) {
      throw ImageGenerationException(
        ContentModerationService.childFriendlyWarning,
      );
    }

    if (!_geminiService.isConfigured) return prompt;
    final generatedPrompt = await _geminiService.generateStoryImagePrompt(
      prompt,
    );
    return generatedPrompt.trim().isEmpty ? prompt : generatedPrompt;
  }

  /// Supports `{ "urls": [...], "images": [{ "base64", "mimeType" }] }` and legacy shapes.
  List<GeneratedStoryImage> _parseImagesFromJson(dynamic json) {
    if (json is! Map) return [];

    final urls = _parseUrlList(json);
    final embedded = _parseEmbeddedImages(json['images']);
    if (embedded.isNotEmpty) {
      final out = <GeneratedStoryImage>[];
      for (var i = 0; i < embedded.length; i++) {
        final embeddedImage = embedded[i];
        final url = i < urls.length ? urls[i] : '';
        if (url.isEmpty && embeddedImage.bytes == null) continue;
        out.add(
          GeneratedStoryImage(
            url: url,
            bytes: embeddedImage.bytes,
            mimeType: embeddedImage.mimeType,
          ),
        );
      }
      return out;
    }

    return urls.map((url) => GeneratedStoryImage(url: url)).toList();
  }

  List<String> _parseUrlList(Map<dynamic, dynamic> json) {
    final urls = json['urls'];
    if (urls is List) {
      return urls.whereType<String>().where(_isHttpUrl).toList();
    }

    final imageUrls = json['imageUrls'];
    if (imageUrls is List) {
      return imageUrls.whereType<String>().where(_isHttpUrl).toList();
    }

    final data = json['data'];
    if (data is List) {
      final out = <String>[];
      for (final item in data) {
        if (item is Map && item['url'] is String) {
          final u = item['url'] as String;
          if (_isHttpUrl(u)) out.add(u);
        }
      }
      return out;
    }

    return [];
  }

  List<GeneratedStoryImage> _parseEmbeddedImages(dynamic imagesJson) {
    if (imagesJson is! List) return [];

    final out = <GeneratedStoryImage>[];
    for (final item in imagesJson) {
      if (item is! Map) continue;
      final base64 = item['base64'];
      if (base64 is! String || base64.trim().isEmpty) continue;
      try {
        final bytes = base64Decode(base64.trim());
        final mimeType =
            item['mimeType'] is String ? item['mimeType'] as String : 'image/png';
        out.add(GeneratedStoryImage(url: '', bytes: bytes, mimeType: mimeType));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  String? _parseErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        final message = (decoded['error'] as String).trim();
        return message.isEmpty ? null : message;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  bool _isHttpUrl(String u) {
    final lower = u.toLowerCase();
    return lower.startsWith('https://') || lower.startsWith('http://');
  }

  List<GeneratedStoryImage> _placeholderImages(String prompt, int count) {
    final h = prompt.hashCode;
    return List<GeneratedStoryImage>.generate(
      count,
      (i) => GeneratedStoryImage(
        url: 'https://picsum.photos/seed/${h + i + 1}/512',
      ),
    );
  }
}
