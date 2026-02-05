import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';

/// Slide-to-confirm action button for driver interactions.
/// 
/// Provides a premium slide gesture for confirming actions like
/// delivery completion. Built with Flutter's built-in widgets for reliability.
class SlideActionButton extends StatefulWidget {
  const SlideActionButton({
    super.key,
    required this.onConfirmed,
    this.text = 'Slide to Deliver',
    this.confirmedText = 'Delivered!',
    this.backgroundColor,
    this.foregroundColor,
    this.thumbColor,
    this.enabled = true,
  });

  /// Callback triggered when slide is completed.
  final VoidCallback onConfirmed;

  /// Text displayed on the track. Defaults to "Slide to Deliver".
  final String text;

  /// Text displayed after confirmation. Defaults to "Delivered!".
  final String confirmedText;

  /// Background color of the track. Defaults to hudBlack.
  final Color? backgroundColor;

  /// Foreground color for text and active state. Defaults to neonGreen.
  final Color? foregroundColor;

  /// Color of the thumb. Defaults to white.
  final Color? thumbColor;

  /// Whether the button is enabled. When false, the button is locked and cannot be interacted with.
  final bool enabled;

  @override
  State<SlideActionButton> createState() => _SlideActionButtonState();
}

class _SlideActionButtonState extends State<SlideActionButton>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _isConfirmed = false;
  bool _isLoading = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isConfirmed || _isLoading || !widget.enabled) return;

    setState(() {
      _dragPosition += details.delta.dx;
      // Clamp to track width
      final maxWidth = MediaQuery.of(context).size.width - 32;
      _dragPosition = _dragPosition.clamp(0.0, maxWidth - 56);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isConfirmed || _isLoading || !widget.enabled) return;

    final maxWidth = MediaQuery.of(context).size.width - 32;
    final threshold = (maxWidth - 56) * 0.8; // 80% threshold

    if (_dragPosition >= threshold) {
      // Trigger confirmation
      _confirmAction();
    } else {
      // Reset to start
      _resetPosition();
    }
  }

  Future<void> _confirmAction() async {
    setState(() {
      _isLoading = true;
    });

    // Show loading state
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isConfirmed = true;
      _isLoading = false;
    });

    // Show success briefly
    await Future.delayed(const Duration(milliseconds: 800));

    // Call callback
    widget.onConfirmed();

    // Reset after a delay
    await Future.delayed(const Duration(milliseconds: 500));
    _resetPosition();
  }

  void _resetPosition() {
    _animationController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _dragPosition = 0.0;
          _isConfirmed = false;
          _isLoading = false;
        });
        _animationController.reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor =
        widget.backgroundColor ?? LogisticsColors.hudBlack;
    final effectiveForegroundColor =
        widget.foregroundColor ?? LogisticsColors.neonGreen;
    final effectiveThumbColor = widget.thumbColor ?? AuthColors.textMain;
    final maxWidth = MediaQuery.of(context).size.width - 32;
    final threshold = (maxWidth - 56) * 0.8;
    final progress = _dragPosition / (maxWidth - 56);
    final isEnabled = widget.enabled;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Container(
        width: maxWidth,
        height: 56,
        decoration: BoxDecoration(
          color: effectiveBackgroundColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AuthColors.textMainWithOpacity(isEnabled ? 0.1 : 0.05),
            width: 0.5,
          ),
        ),
      child: Stack(
        children: [
          // Progress fill
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: isEnabled && _dragPosition >= threshold
                  ? effectiveForegroundColor
                  : isEnabled
                      ? effectiveForegroundColor.withOpacity(progress * 0.5)
                      : effectiveForegroundColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(28),
            ),
            width: isEnabled ? _dragPosition + 56 : 0,
          ),
          // Text
          Center(
            child: Text(
              !isEnabled
                  ? '${widget.text} (Locked)'
                  : _isConfirmed
                      ? widget.confirmedText
                      : _isLoading
                          ? 'Processing...'
                          : widget.text,
              style: TextStyle(
                color: isEnabled && _dragPosition >= threshold
                    ? AuthColors.textMain
                    : AuthColors.textMainWithOpacity(isEnabled ? 0.9 : 0.5),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Thumb
          AnimatedPositioned(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            left: isEnabled ? _dragPosition : 0,
            top: 4,
            child: GestureDetector(
              onPanUpdate: isEnabled ? _onPanUpdate : null,
              onPanEnd: isEnabled ? _onPanEnd : null,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isEnabled ? effectiveThumbColor : effectiveThumbColor.withOpacity(0.5),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AuthColors.background.withOpacity(isEnabled ? 0.3 : 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: !isEnabled
                    ? Icon(
                        Icons.lock,
                        color: LogisticsColors.hudBlack.withOpacity(0.5),
                        size: 20,
                      )
                    : _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AuthColors.background,
                              ),
                            ),
                          )
                        : _isConfirmed
                            ? Icon(
                                Icons.check_circle,
                                color: effectiveForegroundColor,
                                size: 24,
                              )
                            : Icon(
                                Icons.arrow_forward,
                                color: LogisticsColors.hudBlack,
                                size: 24,
                              ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
