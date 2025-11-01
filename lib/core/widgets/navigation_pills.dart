import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NavigationPills extends StatefulWidget {
  final List<NavigationPillItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onItemSelected;
  final bool isMobile;

  const NavigationPills({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.onItemSelected,
    this.isMobile = false,
  });

  @override
  State<NavigationPills> createState() => _NavigationPillsState();
}

class _NavigationPillsState extends State<NavigationPills>
    with TickerProviderStateMixin {
  late AnimationController _sliderController;
  late Animation<double> _sliderAnimation;
  final GlobalKey _containerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _sliderController = AnimationController(
      duration: AppTheme.animationSlow,
      vsync: this,
    );
    _sliderAnimation = CurvedAnimation(
      parent: _sliderController,
      curve: AppTheme.animationCurve,
    );
    
    // Start with initial position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSliderPosition();
    });
  }

  @override
  void didUpdateWidget(NavigationPills oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _updateSliderPosition();
    }
  }

  void _updateSliderPosition() {
    if (widget.selectedIndex >= 0 && widget.selectedIndex < widget.items.length) {
      _sliderController.animateTo(widget.selectedIndex / (widget.items.length - 1));
    }
  }

  @override
  void dispose() {
    _sliderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PaveBoard exact styling with 3D depth
    return Container(
      key: _containerKey,
      padding: const EdgeInsets.all(AppTheme.spacingSm), // 0.5rem
      decoration: BoxDecoration(
        color: AppTheme.cardColor, // --color-bg-tertiary (#374151)
        borderRadius: BorderRadius.circular(AppTheme.radiusLg), // var(--radius-lg)
        border: Border.all(
          color: AppTheme.borderColor, // var(--color-border-primary) (#374151)
          width: 1,
        ),
        // PaveBoard 3D depth styling
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: widget.isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _buildPillItems(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Container(
      constraints: const BoxConstraints(minWidth: 400), // Desktop minimum width
      child: Stack(
        children: [
          // Sliding background indicator
          _buildSliderIndicator(),
          // Pills
          Row(
            children: _buildPillItems(),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderIndicator() {
    if (widget.isMobile) return const SizedBox.shrink();
    
    return AnimatedBuilder(
      animation: _sliderAnimation,
      builder: (context, child) {
        final containerRenderBox = _containerKey.currentContext?.findRenderObject() as RenderBox?;
        if (containerRenderBox == null) return const SizedBox.shrink();

        final containerWidth = containerRenderBox.size.width;
        if (containerWidth <= 0) return const SizedBox.shrink(); // Safety check
        
        final itemWidth = (containerWidth - (AppTheme.spacingSm * 2)) / widget.items.length;
        final sliderWidth = itemWidth - (AppTheme.spacingSm * 2);
        final sliderPosition = _sliderAnimation.value * (itemWidth * (widget.items.length - 1));

        // Ensure positive dimensions
        if (sliderWidth <= 0) return const SizedBox.shrink();

        return Positioned(
          left: AppTheme.spacingSm + sliderPosition,
          top: AppTheme.spacingSm,
          child: Container(
            width: sliderWidth,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildPillItems() {
    return List.generate(widget.items.length, (index) {
      final item = widget.items[index];
      final isSelected = index == widget.selectedIndex;
      
      return Flexible(
        child: _buildPillButton(
          item: item,
          index: index,
          isSelected: isSelected,
        ),
      );
    });
  }

  Widget _buildPillButton({
    required NavigationPillItem item,
    required int index,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => widget.onItemSelected?.call(index),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 40,
          minWidth: 80, // Desktop optimized minimum width
        ),
        padding: EdgeInsets.symmetric(
          horizontal: widget.isMobile ? AppTheme.spacingMd : AppTheme.spacingLg,
          vertical: AppTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          color: isSelected && widget.isMobile 
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Center(
          child: Text(
            item.label,
            style: TextStyle(
              color: isSelected 
                  ? AppTheme.textPrimaryColor
                  : AppTheme.textSecondaryColor,
              fontSize: widget.isMobile ? 14 : 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class NavigationPillItem {
  final String id;
  final String label;
  final IconData? icon;

  const NavigationPillItem({
    required this.id,
    required this.label,
    this.icon,
  });
}
