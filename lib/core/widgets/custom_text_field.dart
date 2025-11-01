import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum CustomTextFieldVariant {
  defaultField,
  search,
  number,
  email,
  password,
}

enum CustomTextFieldSize {
  small,
  medium,
  large,
}

class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final CustomTextFieldVariant variant;
  final CustomTextFieldSize size;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function()? onTap;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  const CustomTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.errorText,
    this.variant = CustomTextFieldVariant.defaultField,
    this.size = CustomTextFieldSize.medium,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.validator,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  Color _getFocusColor() {
    switch (widget.variant) {
      case CustomTextFieldVariant.search:
        return AppTheme.infoColor;
      case CustomTextFieldVariant.number:
        return AppTheme.successColor;
      case CustomTextFieldVariant.email:
        return AppTheme.secondaryColor;
      case CustomTextFieldVariant.password:
        return AppTheme.errorColor;
      case CustomTextFieldVariant.defaultField:
        return AppTheme.primaryColor;
    }
  }

  EdgeInsets _getPadding() {
    switch (widget.size) {
      case CustomTextFieldSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case CustomTextFieldSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case CustomTextFieldSize.large:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    }
  }

  double _getFontSize() {
    switch (widget.size) {
      case CustomTextFieldSize.small:
        return 14;
      case CustomTextFieldSize.medium:
        return 16;
      case CustomTextFieldSize.large:
        return 18;
    }
  }

  @override
  Widget build(BuildContext context) {
    final focusColor = _getFocusColor();
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          Text(
            widget.labelText!,
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: widget.controller,
          initialValue: widget.initialValue,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          obscureText: _obscureText,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          readOnly: widget.readOnly,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: _getFontSize(),
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: AppTheme.textTertiaryColor,
              fontSize: _getFontSize(),
            ),
            prefixIcon: widget.prefixIcon != null
                ? IconTheme(
                    data: IconThemeData(
                      color: AppTheme.textTertiaryColor,
                      size: 20,
                    ),
                    child: widget.prefixIcon!,
                  )
                : null,
            suffixIcon: _buildSuffixIcon(focusColor),
            filled: true,
            fillColor: AppTheme.surfaceColor.withValues(alpha: 0.5),
            contentPadding: _getPadding(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? AppTheme.errorColor : AppTheme.borderColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? AppTheme.errorColor : AppTheme.borderColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: focusColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.errorColor,
                width: 2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.errorColor,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.borderColor.withValues(alpha: 0.5),
              ),
            ),
            errorStyle: const TextStyle(
              color: AppTheme.errorColor,
              fontSize: 12,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.errorColor,
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: const TextStyle(
                    color: AppTheme.errorColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget? _buildSuffixIcon(Color focusColor) {
    if (widget.variant == CustomTextFieldVariant.password) {
      return IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_off : Icons.visibility,
          color: AppTheme.textTertiaryColor,
          size: 20,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }

    if (widget.suffixIcon != null) {
      return GestureDetector(
        onTap: widget.onSuffixIconTap,
        child: IconTheme(
          data: IconThemeData(
            color: widget.onSuffixIconTap != null
                ? AppTheme.textSecondaryColor
                : AppTheme.textTertiaryColor,
            size: 20,
          ),
          child: widget.suffixIcon!,
        ),
      );
    }

    return null;
  }
}
