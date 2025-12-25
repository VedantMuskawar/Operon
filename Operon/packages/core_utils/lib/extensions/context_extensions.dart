import 'package:flutter/material.dart';

extension ContextX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Size get screenSize => MediaQuery.sizeOf(this);
}
