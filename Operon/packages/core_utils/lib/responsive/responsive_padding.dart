import 'package:flutter/widgets.dart';

EdgeInsets responsiveScreenPadding(BoxConstraints constraints) {
  if (constraints.maxWidth >= 1200) {
    return const EdgeInsets.symmetric(horizontal: 120, vertical: 48);
  }
  if (constraints.maxWidth >= 800) {
    return const EdgeInsets.symmetric(horizontal: 64, vertical: 36);
  }
  return const EdgeInsets.symmetric(horizontal: 24, vertical: 24);
}
