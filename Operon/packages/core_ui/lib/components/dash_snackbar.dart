import 'package:flutter/material.dart';

class DashSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1F1F35),
        content: Text(message),
      ),
    );
  }
}
