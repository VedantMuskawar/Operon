import 'package:flutter/material.dart';

class DashSidebarItem {
  DashSidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
}

class DashSidebar extends StatelessWidget {
  const DashSidebar({
    super.key,
    required this.items,
    this.logo,
  });

  final List<DashSidebarItem> items;
  final Widget? logo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF111126),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (logo != null) logo!,
          const SizedBox(height: 32),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: item.onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: item.isActive
                        ? const Color(0xFF6C63FF).withOpacity(0.16)
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon, color: Colors.white),
                      const SizedBox(width: 16),
                      Text(item.label, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
