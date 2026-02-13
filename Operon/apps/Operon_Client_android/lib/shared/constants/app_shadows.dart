import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Standardized shadow definitions for consistent elevation
/// All shadows should be referenced from here
class AppShadows {
  AppShadows._();

  // Card Shadows
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 8.0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> cardElevated = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.4),
      blurRadius: 12.0,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 4.0,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> cardHover = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.5),
      blurRadius: 16.0,
      offset: const Offset(0, 8),
    ),
  ];

  // Button Shadows
  static List<BoxShadow> button = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.4),
      blurRadius: 12.0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> buttonPressed = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.2),
      blurRadius: 4.0,
      offset: const Offset(0, 2),
    ),
  ];

  // Input Shadows
  static List<BoxShadow> inputFocused = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.2),
      blurRadius: 8.0,
      offset: const Offset(0, 0),
    ),
  ];

  // Dialog Shadows
  static List<BoxShadow> dialog = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.5),
      blurRadius: 20.0,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 8.0,
      offset: const Offset(0, 4),
    ),
  ];

  // Floating Action Button Shadows
  static List<BoxShadow> fab = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.4),
      blurRadius: 12.0,
      offset: const Offset(0, 4),
    ),
  ];

  // Drawer Shadows
  static List<BoxShadow> drawer = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 60.0,
      offset: const Offset(0, 30),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 20.0,
      offset: const Offset(0, 8),
    ),
  ];

  // Subtle shadow for borders
  static List<BoxShadow> border = [
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.05),
      blurRadius: 2.0,
      offset: const Offset(0, 1),
    ),
  ];

  // No shadow (for flat elements)
  static const List<BoxShadow> none = [];
}

