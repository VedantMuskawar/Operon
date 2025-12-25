import 'package:flutter/material.dart';

class DashFormField extends StatelessWidget {
  const DashFormField({
    super.key,
    this.controller,
    this.label,
    this.keyboardType,
    this.obscureText = false,
    this.prefix,
  });

  final TextEditingController? controller;
  final String? label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefix,
      ),
    );
  }
}
