import 'package:flutter/material.dart';

class QuickNavBar extends StatelessWidget {
  const QuickNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.visibleSections,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<int>? visibleSections; // If null, show all sections

  static const _items = [
    Icons.home_outlined,
    Icons.pending_actions_outlined,
    Icons.schedule_outlined,
    Icons.map_outlined,
    Icons.dashboard_outlined,
  ];


  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final allowed = <int>{0};
    if (visibleSections != null) {
      allowed.addAll(visibleSections!
          .where((index) => index >= 0 && index < _items.length));
    } else {
      allowed.addAll(List.generate(_items.length, (index) => index));
    }
    final displayed = allowed.toList()..sort();

    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: Container(
          width: width - 32,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF11111B).withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: displayed.map((index) {
              final isActive = index == currentIndex;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => onTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF6F4BFF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF6F4BFF)
                                      .withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        _items[index],
                        color: isActive ? Colors.white : Colors.white54,
                        size: 24,
                      ),
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

