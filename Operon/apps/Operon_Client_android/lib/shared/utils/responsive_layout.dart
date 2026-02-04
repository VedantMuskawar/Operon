import 'package:flutter/material.dart';

/// Breakpoint widths used for responsive layout.
/// Can be overridden via [ResponsiveHelper.setBreakpoints] if needed.
class ResponsiveBreakpoints {
  const ResponsiveBreakpoints._();

  /// Width below which the layout is considered mobile.
  static const double mobile = 600;

  /// Width below which the layout is considered tablet (and above mobile).
  static const double tablet = 900;
}

/// Static helper for responsive layout checks using [MediaQuery].
class ResponsiveHelper {
  ResponsiveHelper._();

  /// Returns true when screen width is below [ResponsiveBreakpoints.mobile].
  static bool isMobile(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < ResponsiveBreakpoints.mobile;
  }

  /// Returns true when screen width is >= [ResponsiveBreakpoints.mobile]
  /// and below [ResponsiveBreakpoints.tablet].
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= ResponsiveBreakpoints.mobile &&
        width < ResponsiveBreakpoints.tablet;
  }

  /// Returns true when screen width is >= [ResponsiveBreakpoints.tablet].
  static bool isDesktop(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= ResponsiveBreakpoints.tablet;
  }
}

/// A widget that builds different layouts for mobile, tablet, and desktop.
/// Uses [ResponsiveHelper] breakpoints internally.
class ResponsiveWrapper extends StatelessWidget {
  const ResponsiveWrapper({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  /// Builder used for mobile layout (width < 600).
  final WidgetBuilder mobile;

  /// Builder used for tablet layout (600 <= width < 900).
  /// Falls back to [mobile] if null.
  final WidgetBuilder? tablet;

  /// Builder used for desktop layout (width >= 900).
  /// Falls back to [tablet] or [mobile] if null.
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context) && desktop != null) {
      return desktop!(context);
    }
    if (ResponsiveHelper.isTablet(context) && tablet != null) {
      return tablet!(context);
    }
    return mobile(context);
  }
}
