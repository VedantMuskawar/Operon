import 'package:flutter/material.dart';
import '../widgets/call_overlay_widget.dart';
import '../services/call_order_lookup_service.dart';

class OverlayManager {
  static OverlayManager? _instance;
  static OverlayManager get instance => _instance ??= OverlayManager._();
  
  OverlayManager._();
  
  OverlayEntry? _overlayEntry;
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _isShowing = false;

  /// Set the navigator key for overlay display
  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  /// Set the current context for overlay display
  void setContext(BuildContext context) {
    // Navigator key is used for overlay display
    // This method is kept for compatibility
  }

  /// Show overlay with order information
  void showOverlay(CallOrderInfo orderInfo) {
    try {
      print('OverlayManager: showOverlay called - phoneNumber: ${orderInfo.phoneNumber}, orders: ${orderInfo.orders.length}');
      
      if (_isShowing) {
        print('OverlayManager: Overlay already showing, hiding it first');
        hideOverlay();
      }

      // Try to get NavigatorState from navigator key
      if (_navigatorKey == null) {
        print('OverlayManager: ERROR - Navigator key is null!');
        return;
      }
      
      final navigatorState = _navigatorKey!.currentState;
      if (navigatorState == null) {
        print('OverlayManager: ERROR - NavigatorState is null! Navigator key exists but state is not available.');
        return;
      }

      // Get overlay directly from NavigatorState
      final overlayState = navigatorState.overlay;
      if (overlayState == null) {
        print('OverlayManager: ERROR - Overlay is null! NavigatorState exists but overlay is not available.');
        return;
      }

      print('OverlayManager: Got overlay state, creating overlay entry...');

      // Get context from navigator for MediaQuery
      final context = _navigatorKey!.currentContext;
      if (context == null) {
        print('OverlayManager: WARNING - Context is null, using default padding');
      }

      _overlayEntry = OverlayEntry(
        builder: (overlayContext) {
          print('OverlayManager: Building overlay widget...');
          // Center the overlay on screen
          final screenSize = MediaQuery.of(overlayContext).size;
          
          return Stack(
            children: [
              // Semi-transparent background that can be tapped to dismiss (optional)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    // Optionally hide overlay on background tap
                    // hideOverlay();
                  },
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),
              // Centered overlay card
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  constraints: BoxConstraints(
                    maxWidth: screenSize.width * 0.9,
                    maxHeight: screenSize.height * 0.8,
                  ),
                  child: SingleChildScrollView(
                    child: CallOverlayWidget(orderInfo: orderInfo),
                  ),
                ),
              ),
            ],
          );
        },
        opaque: false,
      );

      print('OverlayManager: Inserting overlay entry...');
      overlayState.insert(_overlayEntry!);
      _isShowing = true;
      print('OverlayManager: Overlay shown successfully!');
    } catch (e, stackTrace) {
      print('OverlayManager: ERROR showing overlay: $e');
      print('OverlayManager: Stack trace: $stackTrace');
    }
  }

  /// Hide overlay
  void hideOverlay() {
    try {
      if (_overlayEntry != null && _isShowing) {
        _overlayEntry!.remove();
        _overlayEntry = null;
        _isShowing = false;
      }
    } catch (e) {
      print('Error hiding overlay: $e');
      _overlayEntry = null;
      _isShowing = false;
    }
  }

  /// Check if overlay is currently showing
  bool get isShowing => _isShowing;
}
