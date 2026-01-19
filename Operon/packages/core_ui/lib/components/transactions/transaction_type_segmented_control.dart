import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:core_ui/core_ui.dart';

/// Platform-adaptive segmented control for selecting transaction type
/// Android: Uses Material ChoiceChips style
/// Web/iOS: Uses CupertinoSegmentedControl style
class TransactionTypeSegmentedControl extends StatelessWidget {
  const TransactionTypeSegmentedControl({
    super.key,
    required this.selectedIndex,
    required this.onSelectionChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    if (isIOS) {
      return _buildCupertinoControl(context);
    }
    return _buildMaterialControl(context);
  }

  Widget _buildCupertinoControl(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AuthColors.textMainWithOpacity(0.1),
        ),
      ),
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: selectedIndex,
        onValueChanged: (value) {
          if (value != null) {
            onSelectionChanged(value);
          }
        },
        backgroundColor: Colors.transparent,
        thumbColor: AuthColors.legacyAccent,
        children: const {
          0: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Payments',
              style: TextStyle(color: AuthColors.textMain),
            ),
          ),
          1: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Purchases',
              style: TextStyle(color: AuthColors.textMain),
            ),
          ),
          2: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Expenses',
              style: TextStyle(color: AuthColors.textMain),
            ),
          ),
        },
      ),
    );
  }

  Widget _buildMaterialControl(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AuthColors.textMainWithOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MaterialSegmentButton(
              label: 'Payments',
              isSelected: selectedIndex == 0,
              onTap: () => onSelectionChanged(0),
            ),
          ),
          Expanded(
            child: _MaterialSegmentButton(
              label: 'Purchases',
              isSelected: selectedIndex == 1,
              onTap: () => onSelectionChanged(1),
            ),
          ),
          Expanded(
            child: _MaterialSegmentButton(
              label: 'Expenses',
              isSelected: selectedIndex == 2,
              onTap: () => onSelectionChanged(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialSegmentButton extends StatelessWidget {
  const _MaterialSegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AuthColors.primary.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? AuthColors.primary
                  : AuthColors.textSub,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
