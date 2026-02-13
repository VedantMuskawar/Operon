import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Shared organization selection header widget
class OrganizationSelectionHeader extends StatelessWidget {
  const OrganizationSelectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose workspace',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AuthColors.textMain,
            fontFamily: 'SF Pro Display',
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 4),
        Text(
          "Pick an organization and we'll tailor everything to it.",
          style: TextStyle(
            color: AuthColors.textSub,
            fontSize: 15,
            fontFamily: 'SF Pro Display',
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Shared financial year selector widget
class FinancialYearSelector extends StatelessWidget {
  const FinancialYearSelector({
    super.key,
    required this.financialYear,
    required this.financialYears,
    required this.isLocked,
    required this.onChanged,
  });

  final String? financialYear;
  final List<String> financialYears;
  final bool isLocked;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Financial Year',
          style: TextStyle(
            color: AuthColors.textSub,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'SF Pro Display',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: financialYear,
          dropdownColor: AuthColors.surface,
          iconEnabledColor:
              isLocked ? AuthColors.textSubWithOpacity(0.3) : AuthColors.textMain,
          style: const TextStyle(
            color: AuthColors.textMain,
            fontSize: 17,
            fontFamily: 'SF Pro Display',
          ),
          items: financialYears
              .map(
                (year) => DropdownMenuItem<String>(
                  value: year,
                  child: Text(year),
                ),
              )
              .toList(),
          onChanged: isLocked ? null : onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AuthColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AuthColors.textMainWithOpacity(0.1),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AuthColors.textMainWithOpacity(0.1),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AuthColors.primary,
                width: 1.5,
              ),
            ),
            helperText: isLocked
                ? 'Locked to current year for your role.'
                : null,
            helperStyle: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 12,
              fontFamily: 'SF Pro Display',
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared organization tile widget
/// Generic implementation that works with any organization object
class OrganizationTile extends StatelessWidget {
  const OrganizationTile({
    super.key,
    required this.organizationName,
    required this.organizationRole,
    required this.isSelected,
    required this.onTap,
  });

  final String organizationName;
  final String organizationRole;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AuthColors.surface,
                    AuthColors.surface.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : AuthColors.unselectedTile,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AuthColors.primary
                : AuthColors.textMainWithOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AuthColors.primaryWithOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AuthColors.primary
                    : AuthColors.textMainWithOpacity(0.1),
              ),
              child: Icon(
                Icons.apartment,
                color: isSelected ? AuthColors.textMain : AuthColors.secondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organizationName,
                    style: const TextStyle(
                      color: AuthColors.textMain,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      fontFamily: 'SF Pro Display',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Role: $organizationRole',
                    style: const TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 13,
                      fontFamily: 'SF Pro Display',
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AuthColors.primary
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: AuthColors.textMain,
                      size: 20,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader for organization tiles
class OrganizationTileSkeleton extends StatelessWidget {
  const OrganizationTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AuthColors.unselectedTile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AuthColors.textMainWithOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AuthColors.textMainWithOpacity(0.1),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AuthColors.textMainWithOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 13,
                  decoration: BoxDecoration(
                    color: AuthColors.textMainWithOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared continue button for organization selection
class OrganizationSelectionContinueButton extends StatelessWidget {
  const OrganizationSelectionContinueButton({
    super.key,
    required this.isEnabled,
    required this.onPressed,
    this.isLoading = false,
  });

  final bool isEnabled;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: (isEnabled && !isLoading) ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AuthColors.primary,
          foregroundColor: AuthColors.textMain,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          disabledBackgroundColor: AuthColors.primaryWithOpacity(0.5),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AuthColors.textMain),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue to Dashboard',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'SF Pro Display',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Shared loading state for organization selection
class OrganizationSelectionLoadingState extends StatelessWidget {
  const OrganizationSelectionLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AuthColors.primary,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AuthColors.textMain),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading organizations...',
              style: TextStyle(
                color: AuthColors.textMainWithOpacity(0.7),
                fontSize: 16,
                fontFamily: 'SF Pro Display',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader for organization selection list
/// Shows skeleton tiles while organizations are loading
class OrganizationSelectionSkeleton extends StatelessWidget {
  const OrganizationSelectionSkeleton({
    super.key,
    this.count = 3,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OrganizationTileSkeleton(
            key: ValueKey('org_skeleton_$index'),
          ),
        ),
      ),
    );
  }
}

/// Shared empty state for organization selection
class EmptyOrganizationsState extends StatelessWidget {
  const EmptyOrganizationsState({
    super.key,
    this.onRefresh,
    this.onBackToLogin,
  });

  final VoidCallback? onRefresh;
  final VoidCallback? onBackToLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AuthColors.primaryWithOpacity(0.1),
          ),
          child: Icon(
            Icons.apartment_outlined,
            size: 60,
            color: AuthColors.primaryWithOpacity(0.5),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'No organizations found',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            fontFamily: 'SF Pro Display',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'You don\'t have access to any organizations yet.\nContact your administrator to get started.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AuthColors.textSub,
            fontSize: 15,
            fontFamily: 'SF Pro Display',
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: onRefresh,
            style: FilledButton.styleFrom(
              backgroundColor: AuthColors.primary,
              foregroundColor: AuthColors.textMain,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh_rounded, size: 18),
                SizedBox(width: 8),
                Text(
                  'Refresh',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF Pro Display',
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onBackToLogin != null) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: onBackToLogin,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: AuthColors.textSub,
                ),
                SizedBox(width: 8),
                Text(
                  'Back to login',
                  style: TextStyle(
                    fontSize: 14,
                    color: AuthColors.textSub,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF Pro Display',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
