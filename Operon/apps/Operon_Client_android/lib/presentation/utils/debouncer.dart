import 'dart:async';
import 'package:flutter/material.dart';

/// Utility class to debounce function calls
/// Useful for search inputs, API calls, and other rapid-fire events
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 300)});

  final Duration duration;
  Timer? _timer;

  /// Runs the callback after the debounce duration
  /// If called again before the duration expires, the timer resets
  void run(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(duration, callback);
  }

  /// Immediately cancels any pending callback
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Disposes the debouncer, canceling any pending callbacks
  void dispose() {
    cancel();
  }
}

