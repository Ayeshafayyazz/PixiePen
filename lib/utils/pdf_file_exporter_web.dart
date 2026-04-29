// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

class PdfFileExporter {
  static Future<void> download({
    required Uint8List bytes,
    required String fileName,
  }) async {
    _downloadInBrowser(bytes: bytes, fileName: fileName);
  }

  static Future<void> share({
    required Uint8List bytes,
    required String fileName,
  }) async {
    _downloadInBrowser(bytes: bytes, fileName: fileName);
  }

  static void _downloadInBrowser({
    required Uint8List bytes,
    required String fileName,
  }) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
