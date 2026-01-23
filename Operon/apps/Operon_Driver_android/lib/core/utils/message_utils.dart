/// Utility functions for showing consistent messages to users.
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Shows an error message in a SnackBar.
void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AuthColors.error,
    ),
  );
}

/// Shows a success message in a SnackBar.
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AuthColors.success,
    ),
  );
}
