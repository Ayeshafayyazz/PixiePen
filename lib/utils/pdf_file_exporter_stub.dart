import 'dart:typed_data';

import 'package:printing/printing.dart';

class PdfFileExporter {
  static Future<void> download({
    required Uint8List bytes,
    required String fileName,
  }) {
    return Printing.layoutPdf(
      name: fileName,
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> share({
    required Uint8List bytes,
    required String fileName,
  }) {
    return Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
