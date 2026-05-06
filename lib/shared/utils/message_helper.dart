import 'package:flutter/material.dart';

class MessageHelper {
  static void success(BuildContext context, String message) {
    _show(context, message, backgroundColor: Colors.green);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, backgroundColor: Colors.redAccent);
  }

  static void _show(
    BuildContext context,
    String message, {
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
