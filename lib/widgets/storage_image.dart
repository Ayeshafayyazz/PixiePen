import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// Displays images from Firebase Storage without browser CORS issues on web.
///
/// Firebase Storage download URLs frequently fail with `statusCode: 0`
/// (CORS-blocked) inside Flutter web's `Image.network`. This widget detects
/// those URLs and downloads the bytes through the Firebase Storage SDK
/// instead, which uses the SDK's authenticated CORS-aware path. For all
/// other URLs it falls back to a standard `Image.network`.
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

  Future<void> _resolveImage() async {
    final url = widget.url?.trim();
    if (url == null || url.isEmpty) return;

    if (StorageImage.isFirebaseStorageUrl(url)) {
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
          setState(() => _failed = true);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _failed = true);
      }
      return;
    }

    // Non-Firebase URLs use the network image path in build().
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
      if (url != null &&
          url.isNotEmpty &&
          !StorageImage.isFirebaseStorageUrl(url) &&
          !_failed) {
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
