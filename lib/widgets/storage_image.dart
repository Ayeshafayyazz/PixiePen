import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Displays images from Firebase Storage without browser CORS issues on web.
///
/// Firebase Storage download URLs frequently fail with `statusCode: 0`
/// (CORS-blocked) inside Flutter web's `Image.network`. On **web** this
/// widget detects Firebase URLs and downloads the bytes through the Firebase
/// Storage SDK (CORS-aware authenticated path).
///
/// On **all other platforms** (Android, iOS, Windows, macOS, Linux) the
/// tokenized download URL — `…?alt=media&token=…` — works fine via plain
/// `Image.network`, so we skip the SDK detour. Using the SDK on native is
/// strictly worse: it double-downloads bytes, holds them in memory, and
/// silently fails when the bucket has a `.firebasestorage.app` host that
/// older SDK builds don't parse — which was the bug behind covers showing
/// as a solid placeholder color in the eBook reader.
class StorageImage extends StatefulWidget {
  const StorageImage({
    super.key,
    this.url,
    this.bytes,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
  });

  final String? url;
  final Uint8List? bytes;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;

  static bool isFirebaseStorageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('firebasestorage.googleapis.com') ||
        lower.contains('storage.googleapis.com');
  }

  @override
  State<StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<StorageImage> {
  Uint8List? _loaded;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loaded = widget.bytes;
    if (_loaded == null && widget.url != null) {
      _resolveImage();
    }
  }

  @override
  void didUpdateWidget(covariant StorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bytes != oldWidget.bytes && widget.bytes != null) {
      setState(() {
        _loaded = widget.bytes;
        _failed = false;
      });
      return;
    }
    if (widget.url != oldWidget.url) {
      setState(() {
        _loaded = widget.bytes;
        _failed = false;
      });
      if (_loaded == null && widget.url != null) {
        _resolveImage();
      }
    }
  }

  /// On web we run the Firebase Storage SDK path first to bypass CORS.
  /// If it fails (e.g. new-style bucket parsing issue in `refFromURL`), we
  /// don't give up — `build()` will still let `Image.network` try as a final
  /// fallback. With `storage.cors.json` deployed, that fallback succeeds and
  /// no detour is needed at all.
  bool _sdkAttempted = false;

  Future<void> _resolveImage() async {
    final url = widget.url?.trim();
    if (url == null || url.isEmpty) return;

    // On native (Android, iOS, Windows, macOS, Linux) the tokenized download
    // URL is publicly fetchable and Image.network handles it in build().
    if (!kIsWeb) return;

    if (StorageImage.isFirebaseStorageUrl(url)) {
      _sdkAttempted = true;
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        final data = await ref.getData();
        if (!mounted) return;
        if (data != null && data.isNotEmpty) {
          setState(() {
            _loaded = data;
            _failed = false;
          });
        } else {
          // SDK returned nothing — let Image.network try.
          setState(() {});
        }
      } catch (_) {
        if (!mounted) return;
        // SDK failed (e.g. couldn't parse the bucket URL). Force a rebuild
        // so the build() else-branch gets to try Image.network as a final
        // attempt. The errorBuilder will gracefully fall back to the
        // placeholder if that path also fails.
        setState(() {});
      }
      return;
    }

    // Non-Firebase URLs on web use the network image path in build().
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = widget.height;
    final loaded = _loaded;

    Widget child;
    if (loaded != null && loaded.isNotEmpty) {
      child = Image.memory(
        loaded,
        fit: widget.fit,
        width: w,
        height: h,
        gaplessPlayback: true,
      );
    } else {
      final url = widget.url?.trim();
      final isFirebaseUrl =
          url != null && StorageImage.isFirebaseStorageUrl(url);
      // On native: always try Image.network — the tokenized download URL is
      // public.
      // On web for Firebase URLs: only try Image.network after the SDK path
      // has had its chance (avoids surfacing a noisy CORS error in the
      // common-case where the SDK succeeds and we don't need it).
      final canTryNetwork = url != null &&
          url.isNotEmpty &&
          !_failed &&
          (!kIsWeb || !isFirebaseUrl || _sdkAttempted);
      if (canTryNetwork) {
        child = Image.network(
          url,
          fit: widget.fit,
          width: w,
          height: h,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _sizedPlaceholder(),
        );
      } else {
        child = _sizedPlaceholder();
      }
    }

    if (w == null && h == null) return child;
    return SizedBox(width: w, height: h, child: child);
  }

  Widget _sizedPlaceholder() {
    final w = widget.width;
    final h = widget.height;
    final base = widget.placeholder ??
        const ColoredBox(
          color: Color(0xFFE0E0E0),
          child: Center(child: Icon(Icons.broken_image_outlined)),
        );
    if (w == null && h == null) return base;
    return SizedBox(width: w, height: h, child: base);
  }
}
