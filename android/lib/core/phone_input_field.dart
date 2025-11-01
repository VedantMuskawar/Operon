import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';

class PhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final String? Function(String?)? validator;

  const PhoneInputField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10), // Limit to exactly 10 digits
      ],
      validator: validator ?? _defaultValidator,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: const Icon(Icons.phone),
        prefixText: '+91 ',
        helperText: 'Enter 10-digit mobile number (e.g., 9876543210)',
        prefixStyle: const TextStyle(
          color: AppTheme.textPrimaryColor,
          fontWeight: FontWeight.w500,
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => controller.clear(),
              )
            : null,
      ),
    );
  }

  String? _defaultValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (value.length != 10) {
      return 'Please enter exactly 10 digits';
    }
    // Additional validation for Indian mobile numbers
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
      return 'Please enter a valid Indian mobile number';
    }
    return null;
  }
}



