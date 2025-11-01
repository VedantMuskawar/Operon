import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class OrganizationCard extends StatelessWidget {
  final String orgName;
  final String? orgLogoUrl;
  final int role;
  final bool isPrimary;
  final VoidCallback onTap;

  const OrganizationCard({
    super.key,
    required this.orgName,
    this.orgLogoUrl,
    required this.role,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPrimary 
            ? BorderSide(color: AppTheme.primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Organization Logo
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.surfaceColor,
                  border: Border.all(
                    color: AppTheme.borderColor,
                    width: 1,
                  ),
                ),
                child: orgLogoUrl != null && orgLogoUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          orgLogoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultIcon();
                          },
                        ),
                      )
                    : _buildDefaultIcon(),
              ),
              const SizedBox(height: 16),
              // Organization Name
              Text(
                orgName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Role Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRoleColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getRoleColor().withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getRoleName(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getRoleColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isPrimary) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Primary',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultIcon() {
    return Icon(
      Icons.business,
      size: 30,
      color: AppTheme.textSecondaryColor,
    );
  }

  Color _getRoleColor() {
    switch (role) {
      case 0: // Super Admin
        return Colors.purple;
      case 1: // Admin
        return Colors.red;
      case 2: // Manager
        return Colors.blue;
      case 3: // Driver
        return Colors.green;
      default:
        return AppTheme.textSecondaryColor;
    }
  }

  String _getRoleName() {
    switch (role) {
      case 0:
        return 'Super Admin';
      case 1:
        return 'Admin';
      case 2:
        return 'Manager';
      case 3:
        return 'Driver';
      default:
        return 'User';
    }
  }
}
