import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dashboard_tile.dart';

class DashboardSectionCard extends StatefulWidget {
  final String title;
  final String emoji;
  final List<DashboardTileItem> items;
  final SectionType sectionType;
  final int animationDelay;
  final bool isAdmin;

  const DashboardSectionCard({
    super.key,
    required this.title,
    required this.emoji,
    required this.items,
    required this.sectionType,
    this.animationDelay = 0,
    this.isAdmin = true,
  });

  @override
  State<DashboardSectionCard> createState() => _DashboardSectionCardState();
}

class _DashboardSectionCardState extends State<DashboardSectionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    
    // Start animation with delay
    Future.delayed(
      Duration(milliseconds: widget.animationDelay),
      () {
        if (mounted) {
          _animationController.forward();
        }
      },
    );
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: AppTheme.animationSlowest,
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.animationCurve,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.animationCurve,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(32), // p-6 lg:p-8 (32px)
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                border: Border.all(
                  color: _getSectionBorderColor(),
                  width: 1,
                ),
                gradient: _getSectionGradient(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header - PaveBoard exact: mb-10 pb-6
                  _buildSectionHeader(),
                  const SizedBox(height: 40), // mb-10 (40px)
                  // Section Content Grid
                  _buildSectionGrid(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader() {
    // PaveBoard style: Centered header with inline emoji and text
    final titleParts = widget.title.split(' ');
    final emojiPart = titleParts.isNotEmpty ? titleParts[0] : '';
    final textPart = titleParts.length > 1 ? titleParts.sublist(1).join(' ') : '';
    
    return Container(
      padding: const EdgeInsets.only(bottom: 24), // pb-6 (24px)
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.2), // border-white/20
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji with drop shadow - PaveBoard exact: text-2xl filter drop-shadow-lg
            Text(
              emojiPart,
              style: const TextStyle(
                fontSize: 24, // text-2xl
                height: 1.0,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12), // gap-3 (12px)
            // Text part - PaveBoard exact: text-2xl text-gray-200 font-bold
            Flexible(
              child: Text(
                textPart,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFFE5E7EB), // text-gray-200
                  fontWeight: FontWeight.bold,
                  fontSize: 24, // text-2xl
                  height: 1.0,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionGrid() {
    // PaveBoard exact: grid grid-cols-2 gap-6 sm:gap-8
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // Always 2 columns like PaveBoard
        crossAxisSpacing: 32, // sm:gap-8 (32px)
        mainAxisSpacing: 32, // sm:gap-8 (32px)
        childAspectRatio: 1.2,
      ),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        // PaveBoard logic: Admins always see everything, managers see only what's allowed
        final pageVisible = widget.isAdmin || true; // For now, show all items
        
        if (!pageVisible) return const SizedBox.shrink();
        
        return DashboardTile(
          emoji: item.emoji,
          title: item.title,
          onTap: item.onTap,
          isEnabled: item.isEnabled,
          tooltip: item.tooltip,
        );
      },
    );
  }

  Color _getSectionColor() {
    switch (widget.sectionType) {
      case SectionType.orders:
        return AppTheme.ordersSectionColor;
      case SectionType.production:
        return AppTheme.productionSectionColor;
      case SectionType.financial:
        return AppTheme.financialSectionColor;
      case SectionType.procurement:
        return AppTheme.procurementSectionColor;
    }
  }

  Color _getSectionBorderColor() {
    return _getSectionColor().withValues(alpha: 0.2);
  }

  LinearGradient _getSectionGradient() {
    switch (widget.sectionType) {
      case SectionType.orders:
        return AppTheme.ordersSectionGradient;
      case SectionType.production:
        return AppTheme.productionSectionGradient;
      case SectionType.financial:
        return AppTheme.financialSectionGradient;
      case SectionType.procurement:
        return AppTheme.procurementSectionGradient;
    }
  }
}

class DashboardTileItem {
  final String emoji;
  final String title;
  final VoidCallback? onTap;
  final bool isEnabled;
  final String? tooltip;

  const DashboardTileItem({
    required this.emoji,
    required this.title,
    this.onTap,
    this.isEnabled = true,
    this.tooltip,
  });
}

enum SectionType {
  orders,
  production,
  financial,
  procurement,
}
