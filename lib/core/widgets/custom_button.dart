import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum CustomButtonVariant {
  primary,      // Blue - Save/Submit
  secondary,    // Gray - Upload/Secondary
  outline,      // Gray outline
  danger,       // Red - Delete/Cancel
  success,      // Green - Approve/Verify
  warning,      // Orange - Edit
  ghost,        // Transparent
}

enum CustomButtonSize {
  small,
  medium,
  large,
  extraLarge,
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CustomButtonVariant variant;
  final CustomButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final Widget? icon;
  final IconPosition iconPosition;
  final double? width;
  final EdgeInsets? padding;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = CustomButtonVariant.primary,
    this.size = CustomButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.iconPosition = IconPosition.left,
    this.width,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isDisabled && !isLoading;
    
    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: _getButtonStyle(),
        child: _buildButtonContent(),
      ),
    );
  }

  ButtonStyle _getButtonStyle() {
    
    switch (variant) {
      case CustomButtonVariant.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: padding ?? _getPadding(),
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return Colors.white.withValues(alpha: 0.15);
              }
              if (states.contains(WidgetState.hovered)) {
                return Colors.white.withValues(alpha: 0.08);
              }
              return null;
            },
          ),
        );

      case CustomButtonVariant.secondary:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white.withValues(alpha: 0.9),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: padding ?? _getPadding(),
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return Colors.white.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return Colors.white.withValues(alpha: 0.06);
              }
              return null;
            },
          ),
        );

      case CustomButtonVariant.outline:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.textSecondaryColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: padding ?? _getPadding(),
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: AppTheme.textTertiaryColor,
        );

      case CustomButtonVariant.danger:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: padding ?? _getPadding(),
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return const Color(0x1AFF3B30); // Red overlay
              }
              if (states.contains(WidgetState.hovered)) {
                return const Color(0x0DFF3B30); // Light red overlay
              }
              return null;
            },
          ),
        );

      case CustomButtonVariant.success:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: padding ?? _getPadding(),
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return const Color(0x1A32D74B); // Green overlay
              }
              if (states.contains(WidgetState.hovered)) {
                return const Color(0x0D32D74B); // Light green overlay
              }
              return null;
            },
          ),
        );

      case CustomButtonVariant.warning:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: padding ?? _getPadding(),
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return const Color(0x1AFF9500); // Orange overlay
              }
              if (states.contains(WidgetState.hovered)) {
                return const Color(0x0DFF9500); // Light orange overlay
              }
              return null;
            },
          ),
        );

      case CustomButtonVariant.ghost:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.textSecondaryColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: padding ?? _getPadding(),
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: AppTheme.textTertiaryColor,
        );
    }
  }

  Widget _buildButtonContent() {
    final isEnabled = onPressed != null && !isDisabled && !isLoading;
    
    return Container(
      decoration: _getBackgroundDecoration(),
      child: Padding(
        padding: padding ?? _getPadding(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: _buildButtonChildren(isEnabled),
        ),
      ),
    );
  }

  BoxDecoration? _getBackgroundDecoration() {
    final isEnabled = onPressed != null && !isDisabled && !isLoading;
    
    switch (variant) {
      case CustomButtonVariant.primary:
        return BoxDecoration(
          gradient: isEnabled 
              ? const LinearGradient(
                  colors: [
                    Color(0xFF007AFF), // iOS Blue
                    Color(0xFF0056CC), // Darker Blue
                    Color(0xFF003D99), // Even Darker Blue
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.5, 1.0],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isEnabled ? [
            BoxShadow(
              color: const Color(0xFF007AFF).withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xFF007AFF).withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, 16),
              spreadRadius: 0,
            ),
          ] : null,
        );

      case CustomButtonVariant.secondary:
        return BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(
                  colors: [
                    Color(0x4D8E8E93), // rgba(142,142,147,0.3)
                    Color(0x338E8E93), // rgba(142,142,147,0.2)
                    Color(0x1A8E8E93), // rgba(142,142,147,0.1)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.5, 1.0],
                )
              : null,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isEnabled ? [
            BoxShadow(
              color: const Color(0xFF8E8E93).withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ] : null,
        );

      case CustomButtonVariant.danger:
        return BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(
                  colors: [
                    Color(0xFFFF3B30), // iOS Red
                    Color(0xFFD70015), // Darker Red
                    Color(0xFFB30000), // Even Darker Red
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.5, 1.0],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isEnabled ? [
            BoxShadow(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, 16),
              spreadRadius: 0,
            ),
          ] : null,
        );

      case CustomButtonVariant.success:
        return BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(
                  colors: [
                    Color(0xFF32D74B), // iOS Green
                    Color(0xFF28A745), // Darker Green
                    Color(0xFF1E7E34), // Even Darker Green
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.5, 1.0],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isEnabled ? [
            BoxShadow(
              color: const Color(0xFF32D74B).withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xFF32D74B).withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, 16),
              spreadRadius: 0,
            ),
          ] : null,
        );

      case CustomButtonVariant.warning:
        return BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(
                  colors: [
                    Color(0xFFFF9500), // iOS Orange
                    Color(0xFFE67E22), // Darker Orange
                    Color(0xFFD35400), // Even Darker Orange
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.5, 1.0],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isEnabled ? [
            BoxShadow(
              color: const Color(0xFFFF9500).withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xFFFF9500).withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, 16),
              spreadRadius: 0,
            ),
          ] : null,
        );

      case CustomButtonVariant.outline:
      case CustomButtonVariant.ghost:
        return null;
    }
  }

  List<Widget> _buildButtonChildren(bool isEnabled) {
    final children = <Widget>[];

    if (isLoading) {
      children.add(
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
      children.add(const SizedBox(width: 8));
    }

    if (icon != null && iconPosition == IconPosition.left) {
      children.add(icon!);
      children.add(const SizedBox(width: 8));
    }

    children.add(
      Text(
        text,
        style: TextStyle(
          fontSize: _getFontSize(),
          fontWeight: FontWeight.w600,
          color: isEnabled ? _getTextColor() : _getTextColor().withValues(alpha: 0.5),
        ),
      ),
    );

    if (icon != null && iconPosition == IconPosition.right) {
      children.add(const SizedBox(width: 8));
      children.add(icon!);
    }

    return children;
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case CustomButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case CustomButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
      case CustomButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
      case CustomButtonSize.extraLarge:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 14);
    }
  }

  double _getFontSize() {
    switch (size) {
      case CustomButtonSize.small:
        return 12;
      case CustomButtonSize.medium:
        return 14;
      case CustomButtonSize.large:
        return 16;
      case CustomButtonSize.extraLarge:
        return 18;
    }
  }

  Color _getTextColor() {
    switch (variant) {
      case CustomButtonVariant.primary:
      case CustomButtonVariant.secondary:
      case CustomButtonVariant.danger:
      case CustomButtonVariant.success:
        return Colors.white;
      case CustomButtonVariant.outline:
        return AppTheme.textSecondaryColor;
      case CustomButtonVariant.warning:
        return Colors.white;
      case CustomButtonVariant.ghost:
        return AppTheme.textSecondaryColor;
    }
  }
}

enum IconPosition {
  left,
  right,
}
