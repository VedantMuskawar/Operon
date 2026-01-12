import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An OTP input field with individual digit boxes
class OtpInputField extends StatefulWidget {
  const OtpInputField({
    super.key,
    required this.length,
    this.onChanged,
    this.onCompleted,
    this.autoFocus = false,
    this.enabled = true,
    this.hasError = false,
  });

  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool autoFocus;
  final bool enabled;
  final bool hasError;

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  String _code = '';

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.length; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }

    // Auto-focus first field if requested
    if (widget.autoFocus && widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste or auto-fill
      _handlePaste(value);
      return;
    }

    if (value.isEmpty) {
      // Handle backspace
      if (index > 0) {
        _controllers[index - 1].text = '';
        _focusNodes[index - 1].requestFocus();
      }
      _updateCode();
      return;
    }

    // Update current field
    _controllers[index].text = value;
    _updateCode();

    // Move to next field
    if (index < widget.length - 1 && value.isNotEmpty) {
      _focusNodes[index + 1].requestFocus();
    } else if (index == widget.length - 1) {
      // Last field filled
      _focusNodes[index].unfocus();
      if (_code.length == widget.length) {
        widget.onCompleted?.call(_code);
      }
    }
  }

  void _handlePaste(String pastedValue) {
    final digits = pastedValue.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    for (int i = 0; i < widget.length && i < digits.length; i++) {
      _controllers[i].text = digits[i];
    }

    // Focus the next empty field or the last field
    final nextIndex = digits.length < widget.length ? digits.length : widget.length - 1;
    _focusNodes[nextIndex].requestFocus();
    _updateCode();

    if (_code.length == widget.length) {
      widget.onCompleted?.call(_code);
    }
  }

  void _updateCode() {
    _code = _controllers.map((c) => c.text).join();
    widget.onChanged?.call(_code);
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_controllers[index].text.isEmpty && index > 0) {
          _controllers[index - 1].text = '';
          _focusNodes[index - 1].requestFocus();
          _updateCode();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && index > 0) {
        _focusNodes[index - 1].requestFocus();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
          index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate available width for boxes
        // If width is unbounded, use a reasonable default or screen width
        double availableWidth = constraints.maxWidth;
        if (!constraints.hasBoundedWidth || availableWidth.isInfinite) {
          // Fallback to screen width or a reasonable default
          final screenWidth = MediaQuery.of(context).size.width;
          availableWidth = screenWidth > 0 ? screenWidth : 400.0;
        }
        
        // Reserve space for margins: (length - 1) margins between boxes
        final marginCount = widget.length - 1;
        // Use smaller margin when space is constrained
        final marginSize = availableWidth < 300 ? 6.0 : 8.0;
        final totalMarginWidth = marginCount * marginSize;
        final availableForBoxes = availableWidth - totalMarginWidth;
        
        // Calculate box size - allow smaller boxes when space is constrained
        // Minimum 32px for very small screens, maximum 48px
        final minBoxSize = availableWidth < 250 ? 32.0 : 36.0;
        final maxBoxSize = 48.0;
        final calculatedBoxWidth = availableForBoxes / widget.length;
        final boxWidth = calculatedBoxWidth.clamp(minBoxSize, maxBoxSize);
        
        // If boxes would overflow, reduce box size further
        final totalNeededWidth = (boxWidth * widget.length) + totalMarginWidth;
        final finalBoxWidth = totalNeededWidth > availableWidth
            ? ((availableWidth - totalMarginWidth) / widget.length).clamp(32.0, maxBoxSize)
            : boxWidth;
        
        final boxHeight = (finalBoxWidth * 1.167).clamp(38.0, 56.0); // Maintain aspect ratio
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            widget.length,
            (index) => _buildDigitBox(
              index,
              boxWidth: finalBoxWidth,
              boxHeight: boxHeight,
              marginSize: marginSize,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDigitBox(int index, {required double boxWidth, required double boxHeight, required double marginSize}) {
    final isFocused = _focusNodes[index].hasFocus;
    final hasValue = _controllers[index].text.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(
        right: index < widget.length - 1 ? marginSize : 0,
      ),
      width: boxWidth,
      height: boxHeight,
      child: Focus(
        onKeyEvent: (node, event) {
          _onKeyEvent(index, event);
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          enabled: widget.enabled,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: TextStyle(
            fontSize: (boxWidth * 0.5).clamp(18.0, 24.0), // Responsive font size, min 18, max 24
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: widget.hasError
                ? Colors.redAccent.withOpacity(0.1)
                : const Color(0xFF171721),
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(boxWidth * 0.333), // Responsive border radius
              borderSide: BorderSide(
                color: widget.hasError
                    ? Colors.redAccent
                    : isFocused
                        ? const Color(0xFF6F4BFF)
                        : const Color(0xFF2A2A3A),
                width: isFocused ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(boxWidth * 0.333),
              borderSide: BorderSide(
                color: widget.hasError
                    ? Colors.redAccent
                    : hasValue
                        ? const Color(0xFF6F4BFF).withOpacity(0.5)
                        : const Color(0xFF2A2A3A),
                width: hasValue ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(boxWidth * 0.333),
              borderSide: BorderSide(
                color: widget.hasError ? Colors.redAccent : const Color(0xFF6F4BFF),
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(boxWidth * 0.333),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          onChanged: (value) => _onChanged(index, value),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
      ),
    );
  }
}
