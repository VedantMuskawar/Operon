import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';

/// Alphabet strip widget for fast navigation in contact lists
class AlphabetStrip extends StatefulWidget {
  const AlphabetStrip({
    super.key,
    required this.onLetterTap,
    this.currentLetter,
    this.availableLetters = const [],
  });

  final ValueChanged<String> onLetterTap;
  final String? currentLetter;
  final List<String> availableLetters;

  @override
  State<AlphabetStrip> createState() => _AlphabetStripState();
}

class _AlphabetStripState extends State<AlphabetStrip> {
  static const List<String> _allLetters = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '#',
  ];

  String? _hoveredLetter;

  @override
  Widget build(BuildContext context) {
    // Show only available letters, or all if none specified
    final lettersToShow = widget.availableLetters.isEmpty
        ? _allLetters
        : _allLetters.where((letter) => widget.availableLetters.contains(letter)).toList();

    if (lettersToShow.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 4,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingSM, horizontal: AppSpacing.paddingXS),
          decoration: BoxDecoration(
            color: AuthColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            border: Border.all(
              color: AuthColors.textMainWithOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: lettersToShow.map((letter) {
              final isCurrent = widget.currentLetter == letter;
              final isHovered = _hoveredLetter == letter;
              final isAvailable = widget.availableLetters.isEmpty ||
                  widget.availableLetters.contains(letter);

              return GestureDetector(
                onTapDown: (_) {
                  setState(() => _hoveredLetter = letter);
                },
                onTapUp: (_) {
                  setState(() => _hoveredLetter = null);
                  if (isAvailable) {
                    widget.onLetterTap(letter);
                  }
                },
                onTapCancel: () {
                  setState(() => _hoveredLetter = null);
                },
                child: Container(
                  width: 24,
                  height: 18,
                  alignment: Alignment.center,
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent
                          ? AuthColors.legacyAccent
                          : isAvailable
                              ? (isHovered
                                ? AuthColors.legacyAccent.withValues(alpha: 0.7)
                                  : AuthColors.textSub)
                              : AuthColors.textDisabled,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Helper to group contacts by first letter
Map<String, List<T>> groupContactsByLetter<T>({
  required List<T> contacts,
  required String Function(T) getName,
}) {
  final grouped = <String, List<T>>{};
  
  for (final contact in contacts) {
    final name = getName(contact);
    if (name.isEmpty) continue;
    
    final firstChar = name[0].toUpperCase();
    final letter = RegExp(r'[A-Z]').hasMatch(firstChar) ? firstChar : '#';
    
    grouped.putIfAbsent(letter, () => []).add(contact);
  }
  
  return grouped;
}

/// Helper to get available letters from grouped contacts
List<String> getAvailableLetters(Map<String, List<dynamic>> groupedContacts) {
  return groupedContacts.keys.toList()..sort((a, b) {
    if (a == '#') return 1;
    if (b == '#') return -1;
    return a.compareTo(b);
  });
}
