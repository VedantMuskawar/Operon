import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';

/// Text field with built-in validation and error display
class ValidatedTextField extends StatelessWidget {
  const ValidatedTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          enabled: enabled,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: const Color(0xFF1B1B2C),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: const BorderSide(
                color: Color(0xFF6F4BFF),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: const BorderSide(
                color: Colors.redAccent,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: const BorderSide(
                color: Colors.redAccent,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

