import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum CustomDropdownSize {
  small,
  medium,
  large,
}

class CustomDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final CustomDropdownSize size;
  final bool enabled;
  final Widget? prefixIcon;
  final String? Function(T?)? validator;
  final bool isExpanded;

  const CustomDropdown({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.errorText,
    this.size = CustomDropdownSize.medium,
    this.enabled = true,
    this.prefixIcon,
    this.validator,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          validator: validator,
          isExpanded: isExpanded,
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: _getFontSize(),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: AppTheme.textTertiaryColor,
              fontSize: _getFontSize(),
            ),
            prefixIcon: prefixIcon != null
                ? IconTheme(
                    data: IconThemeData(
                      color: AppTheme.textTertiaryColor,
                      size: 20,
                    ),
                    child: prefixIcon!,
                  )
                : null,
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
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
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
          dropdownColor: AppTheme.surfaceColor,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: enabled ? AppTheme.textTertiaryColor : AppTheme.textTertiaryColor.withValues(alpha: 0.5),
          ),
          iconSize: 24,
          menuMaxHeight: 300,
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
                  errorText!,
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

  EdgeInsets _getPadding() {
    switch (size) {
      case CustomDropdownSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case CustomDropdownSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case CustomDropdownSize.large:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    }
  }

  double _getFontSize() {
    switch (size) {
      case CustomDropdownSize.small:
        return 14;
      case CustomDropdownSize.medium:
        return 16;
      case CustomDropdownSize.large:
        return 18;
    }
  }
}
