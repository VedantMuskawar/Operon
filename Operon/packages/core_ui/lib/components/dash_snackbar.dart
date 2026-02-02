import 'package:flutter/material.dart';

import '../theme/auth_colors.dart';

class DashSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AuthColors.error : AuthColors.surface,
        content: Text(
          message,
          style: const TextStyle(color: AuthColors.textMain),
        ),
      ),
    );
  }
}
