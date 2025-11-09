import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Base state that provides cached realtime list handling and a busy overlay
/// helper for list-based management pages that consume streaming bloc states.
abstract class RealtimeListCacheState<TWidget extends StatefulWidget, TItem>
    extends State<TWidget> {
  List<TItem> _cachedItems = List<TItem>.empty(growable: false);
  String? _cachedSearchQuery;
  bool _hasLoadedRealtimeData = false;

  List<TItem> get realtimeItems => _cachedItems;
  String? get realtimeSearchQuery => _cachedSearchQuery;
  bool get hasRealtimeData => _hasLoadedRealtimeData;

  void applyRealtimeItems(
    List<TItem> items, {
    String? searchQuery,
  }) {
    if (!_hasLoadedRealtimeData ||
        !listEquals(_cachedItems, items) ||
        _cachedSearchQuery != searchQuery) {
      setState(() {
        _cachedItems = List<TItem>.unmodifiable(items);
        _cachedSearchQuery = searchQuery;
        _hasLoadedRealtimeData = true;
      });
    }
  }

  void applyRealtimeEmpty({String? searchQuery}) {
    if (!_hasLoadedRealtimeData ||
        _cachedItems.isNotEmpty ||
        _cachedSearchQuery != searchQuery) {
      setState(() {
        _cachedItems = List<TItem>.empty(growable: false);
        _cachedSearchQuery = searchQuery;
        _hasLoadedRealtimeData = true;
      });
    }
  }

  void resetRealtimeSnapshot() {
    if (_hasLoadedRealtimeData ||
        _cachedItems.isNotEmpty ||
        _cachedSearchQuery != null) {
      setState(() {
        _cachedItems = List<TItem>.empty(growable: false);
        _cachedSearchQuery = null;
        _hasLoadedRealtimeData = false;
      });
    }
  }

  Widget withRealtimeBusyOverlay({
    required Widget child,
    required bool showOverlay,
    Color overlayColor = const Color(0x33000000),
    BorderRadius? borderRadius,
    Widget? progressIndicator,
  }) {
    if (!showOverlay) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: overlayColor,
              borderRadius: borderRadius,
            ),
            alignment: Alignment.center,
            child: progressIndicator ?? const CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }
}

