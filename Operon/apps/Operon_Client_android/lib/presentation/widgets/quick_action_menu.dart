import 'package:flutter/material.dart';

class QuickActionItem {
  const QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class QuickActionMenu extends StatefulWidget {
  const QuickActionMenu({
    super.key,
    required this.actions,
    this.right = 40,
    this.bottom = 120,
  });

  final List<QuickActionItem> actions;
  final double right;
  final double bottom;

  @override
  State<QuickActionMenu> createState() => _QuickActionMenuState();
}

class _QuickActionMenuState extends State<QuickActionMenu>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _backdropAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125, // 45 degrees in turns (45/360 = 0.125)
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _backdropAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _handleActionTap(QuickActionItem action) {
    _toggleMenu();
    // Small delay to allow menu to close before executing action
    Future.delayed(const Duration(milliseconds: 150), () {
      action.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop
        if (_isExpanded)
          Positioned.fill(
            child: FadeTransition(
              opacity: _backdropAnimation,
              child: GestureDetector(
                onTap: _toggleMenu,
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
            ),
          ),
        // Action buttons (stacked above main button)
        ...widget.actions.asMap().entries.map((entry) {
          final index = entry.key;
          final action = entry.value;
          // Reverse order: first action appears closest to main button
          final reversedIndex = widget.actions.length - 1 - index;
          final offset = (reversedIndex + 1) * 72.0; // 56px button + 16px spacing

          return Positioned(
            right: widget.right,
            bottom: widget.bottom + offset,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _scaleAnimation,
                child: _ActionButton(
                  icon: action.icon,
                  label: action.label,
                  onTap: () => _handleActionTap(action),
                ),
              ),
            ),
          );
        }),
        // Main button
        Positioned(
          right: widget.right,
          bottom: widget.bottom,
          child: GestureDetector(
            onTap: _toggleMenu,
            child: RotationTransition(
              turns: _rotationAnimation,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleMenu,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6F4BFF),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6F4BFF).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isExpanded ? Icons.close : Icons.add,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B2C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF6F4BFF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF6F4BFF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

