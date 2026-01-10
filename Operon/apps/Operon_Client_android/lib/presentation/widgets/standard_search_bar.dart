import 'package:flutter/material.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
import 'standard_text_field.dart';

/// Standardized search bar component used across the app
class StandardSearchBar extends StatefulWidget {
  const StandardSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final ValueChanged<String>? onSubmitted;

  @override
  State<StandardSearchBar> createState() => _StandardSearchBarState();
}

class _StandardSearchBarState extends State<StandardSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _clearSearch() {
    widget.controller.clear();
    widget.onClear?.call();
    if (widget.onChanged != null) {
      widget.onChanged!('');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StandardTextField(
      controller: widget.controller,
      hint: widget.hintText,
      prefixIcon: const Icon(
        Icons.search,
        color: AppColors.textTertiary,
        size: AppSpacing.iconMD,
      ),
      suffixIcon: widget.controller.text.isNotEmpty
          ? IconButton(
              icon: const Icon(
                Icons.close,
                color: AppColors.textTertiary,
                size: AppSpacing.iconMD,
              ),
              onPressed: _clearSearch,
            )
          : null,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}

