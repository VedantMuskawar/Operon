import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
}

class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.mobile,
    required this.desktop,
  });

  final Widget mobile;
  final Widget desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveBreakpoints.tablet) {
          return desktop;
        }
        return mobile;
      },
    );
  }
}
