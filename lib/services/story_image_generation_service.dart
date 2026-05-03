import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

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
/// - Calls OpenAI Images, Replicate, Vertex Imagen, etc. with your **server-side** API key.
/// - Returns JSON the client can parse (see [_parseUrlsFromJson]).
///
/// If `IMAGE_GEN_API_URL` is empty, [generateImageUrls] returns deterministic
/// placeholder URLs (current dev behavior).
///
/// Example `flutter run` / build:
/// `flutter run --dart-define=IMAGE_GEN_API_URL=https://.../generateStoryImages --dart-define=IMAGE_GEN_SEND_AUTH=true`
class StoryImageGenerationService {
  StoryImageGenerationService({
    http.Client? httpClient,
    FirebaseAuth? auth,
  })  : _http = httpClient ?? http.Client(),
        _auth = auth ?? FirebaseAuth.instance;

  static const String _apiUrl = String.fromEnvironment(
    'IMAGE_GEN_API_URL',
    defaultValue: '',
  );

  static const bool _sendAuth = bool.fromEnvironment(
    'IMAGE_GEN_SEND_AUTH',
    defaultValue: false,
  );

  final http.Client _http;
  final FirebaseAuth _auth;

  /// Returns one URL per image (length may be less than [count] if the API returns fewer).
  Future<List<String>> generateImageUrls(
    String prompt, {
    int count = 4,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return [];

    if (_apiUrl.isEmpty) {
      return _placeholderUrls(trimmed, count);
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

    final response = await _http.post(
      uri,
      headers: headers,
      body: jsonEncode({'prompt': trimmed, 'n': count}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ImageGenerationException(
        'Image API failed (${response.statusCode}).',
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    final urls = _parseUrlsFromJson(decoded);
    if (urls.isEmpty) {
      throw ImageGenerationException(
        'Image API returned no image URLs. Check response shape.',
      );
    }
    return urls;
  }

  /// Supports:
  /// `{ "urls": ["https://..."] }`
  /// `{ "imageUrls": ["https://..."] }`
  /// OpenAI-style `{ "data": [ { "url": "..." } ] }`
  List<String> _parseUrlsFromJson(dynamic json) {
    if (json is! Map) return [];

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

  bool _isHttpUrl(String u) {
    final lower = u.toLowerCase();
    return lower.startsWith('https://') || lower.startsWith('http://');
  }

  List<String> _placeholderUrls(String prompt, int count) {
    final h = prompt.hashCode;
    return List<String>.generate(
      count,
      (i) => 'https://picsum.photos/seed/${h + i + 1}/512',
    );
  }
}
