import 'dart:typed_data';

/// One AI-generated story illustration (storage URL + optional in-memory bytes).
class GeneratedStoryImage {
  const GeneratedStoryImage({
    required this.url,
    this.bytes,
    this.mimeType = 'image/png',
  });

  final String url;
  final Uint8List? bytes;
  final String mimeType;
}
