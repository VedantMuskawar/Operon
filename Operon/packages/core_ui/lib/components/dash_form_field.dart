import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:core_ui/theme/auth_colors.dart';

class DashFormField extends StatelessWidget {
  const DashFormField({
    super.key,
    this.controller,
    this.label,
    this.keyboardType,
    this.obscureText = false,
    this.prefix,
    this.validator,
    this.onSaved,
    this.autovalidateMode,
    this.style,
    this.maxLines = 1,
    this.readOnly = false,
    this.onChanged,
    this.inputFormatters,
    this.hintText,
    this.prefixText,
    this.suffixText,
  });

  final TextEditingController? controller;
  final String? label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefix;
  final String? hintText;
  final String? prefixText;
  final String? suffixText;
  final String? Function(String?)? validator;
  final void Function(String?)? onSaved;
  final AutovalidateMode? autovalidateMode;
  final TextStyle? style;
  final int? maxLines;
  final bool readOnly;
  final void Function(String)? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  static InputDecoration _defaultDecoration({
    required String? labelText,
    Widget? prefixIcon,
    String? hintText,
    String? prefixText,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixText: prefixText,
      suffixText: suffixText,
      labelStyle: TextStyle(color: AuthColors.textSub),
      hintStyle: TextStyle(color: AuthColors.textSub),
      prefixStyle: TextStyle(color: AuthColors.textSub),
      suffixStyle: TextStyle(color: AuthColors.textSub),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: AuthColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AuthColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AuthColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AuthColors.error, width: 2),
      ),
      errorStyle: TextStyle(color: AuthColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      onSaved: onSaved,
      autovalidateMode: autovalidateMode,
      onChanged: onChanged,
      readOnly: readOnly,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      style: style ?? TextStyle(color: AuthColors.textMain),
      decoration: _defaultDecoration(
        labelText: label,
        prefixIcon: prefix,
        hintText: hintText,
        prefixText: prefixText,
        suffixText: suffixText,
      ),
    );
  }
}
