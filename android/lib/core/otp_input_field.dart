import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';

class OTPInputField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final int length;

  const OTPInputField({
    super.key,
    required this.controller,
    this.validator,
    this.length = 6,
  });

  @override
  State<OTPInputField> createState() => _OTPInputFieldState();
}

class _OTPInputFieldState extends State<OTPInputField> {
  late List<FocusNode> _focusNodes;
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(
      widget.length,
      (index) => FocusNode(),
    );
    _controllers = List.generate(
      widget.length,
      (index) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    // Update the main controller
    String otp = '';
    for (int i = 0; i < widget.length; i++) {
      otp += _controllers[i].text;
    }
    widget.controller.text = otp;

    // Move to next field if value is entered
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  void _onKeyPressed(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_controllers[index].text.isEmpty && index > 0) {
          _focusNodes[index - 1].requestFocus();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Mobile-optimized spacing
      children: List.generate(
        widget.length,
        (index) => _buildOTPDigit(index),
      ),
    );
  }

  Widget _buildOTPDigit(int index) {
    return Container(
      width: 45, // Mobile-optimized size
      height: 45, // Mobile-optimized size
      decoration: BoxDecoration(
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12), // Mobile-optimized radius
      ),
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) => _onKeyPressed(index, event),
        child: TextFormField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (value) => _onChanged(index, value),
          validator: (value) {
            if (widget.validator != null) {
              String otp = '';
              for (int i = 0; i < widget.length; i++) {
                otp += _controllers[i].text;
              }
              return widget.validator!(otp);
            }
            return null;
          },
        ),
      ),
    );
  }
}



