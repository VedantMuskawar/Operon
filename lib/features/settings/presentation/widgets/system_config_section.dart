import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../bloc/settings_bloc.dart';
import '../../bloc/settings_state.dart';
import '../../bloc/settings_event.dart';
import 'setting_tile.dart';

class SystemConfigSection extends StatefulWidget {
  const SystemConfigSection({super.key});

  @override
  State<SystemConfigSection> createState() => _SystemConfigSectionState();
}

class _SystemConfigSectionState extends State<SystemConfigSection> {
  final TextEditingController _userLimitController = TextEditingController();
  final TextEditingController _maxOrgsController = TextEditingController();
  final TextEditingController _domainController = TextEditingController();
  final List<String> _allowedDomains = [];

  @override
  void dispose() {
    _userLimitController.dispose();
    _maxOrgsController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        if (state is! SettingsLoaded) {
          return const SizedBox.shrink();
        }

        final config = state.config;

        // Initialize controllers if they're empty
        if (_userLimitController.text.isEmpty) {
          _userLimitController.text = config.defaultUserLimit.toString();
        }
        if (_maxOrgsController.text.isEmpty) {
          _maxOrgsController.text = config.maxOrganizations.toString();
        }
        if (_allowedDomains.isEmpty) {
          _allowedDomains.addAll(config.allowedDomains);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingSection(
              title: 'Subscription Defaults',
              children: [
                SettingTile(
                  title: 'Default Subscription Tier',
                  subtitle: _getSubscriptionTierLabel(config.defaultSubscriptionTier),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showSubscriptionTierDialog(context),
                ),
                const Divider(),
                SettingTile(
                  title: 'Default User Limit',
                  subtitle: '${config.defaultUserLimit} users per organization',
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showUserLimitDialog(context),
                ),
              ],
            ),
            SettingSection(
              title: 'System Limits',
              children: [
                SettingTile(
                  title: 'Maximum Organizations',
                  subtitle: '${config.maxOrganizations} organizations allowed',
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showMaxOrgsDialog(context),
                ),
              ],
            ),
            SettingSection(
              title: 'System Controls',
              children: [
                SettingTile(
                  title: 'Maintenance Mode',
                  subtitle: config.maintenanceMode ? 'Enabled' : 'Disabled',
                  trailing: Switch(
                    value: config.maintenanceMode,
                    onChanged: (value) {
                      context.read<SettingsBloc>().add(ToggleMaintenanceMode(value));
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            SettingSection(
              title: 'Security Settings',
              children: [
                SettingTile(
                  title: 'Allowed Email Domains',
                  subtitle: '${config.allowedDomains.length} domains configured',
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showDomainsDialog(context),
                ),
                const Divider(),
                SettingTile(
                  title: 'Require Strong Passwords',
                  subtitle: config.securitySettings['requireStrongPasswords'] == true ? 'Enabled' : 'Disabled',
                  trailing: Switch(
                    value: config.securitySettings['requireStrongPasswords'] == true,
                    onChanged: (value) {
                      final newSecuritySettings = Map<String, dynamic>.from(config.securitySettings);
                      newSecuritySettings['requireStrongPasswords'] = value;
                      context.read<SettingsBloc>().add(UpdateSecuritySettings(newSecuritySettings));
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                ),
                const Divider(),
                SettingTile(
                  title: 'Session Timeout',
                  subtitle: '${config.securitySettings['sessionTimeoutMinutes'] ?? 60} minutes',
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showSessionTimeoutDialog(context),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _getSubscriptionTierLabel(String tier) {
    switch (tier) {
      case AppConstants.subscriptionTierBasic:
        return 'Basic - Essential features';
      case AppConstants.subscriptionTierPremium:
        return 'Premium - Advanced features';
      case AppConstants.subscriptionTierEnterprise:
        return 'Enterprise - Full features';
      default:
        return 'Basic - Essential features';
    }
  }

  void _showSubscriptionTierDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Default Subscription Tier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTierOption(context, AppConstants.subscriptionTierBasic, 'Basic'),
            _buildTierOption(context, AppConstants.subscriptionTierPremium, 'Premium'),
            _buildTierOption(context, AppConstants.subscriptionTierEnterprise, 'Enterprise'),
          ],
        ),
      ),
    );
  }

  Widget _buildTierOption(BuildContext context, String value, String label) {
    return ListTile(
      title: Text(label),
      onTap: () {
        final currentState = context.read<SettingsBloc>().state as SettingsLoaded;
        final updatedConfig = currentState.config.copyWith(defaultSubscriptionTier: value);
        context.read<SettingsBloc>().add(UpdateSystemConfig(updatedConfig));
        Navigator.of(context).pop();
      },
    );
  }

  void _showUserLimitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Default User Limit'),
        content: TextField(
          controller: _userLimitController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Number of users',
            hintText: 'Enter default user limit',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final limit = int.tryParse(_userLimitController.text);
              if (limit != null && limit > 0) {
                final currentState = context.read<SettingsBloc>().state as SettingsLoaded;
                final updatedConfig = currentState.config.copyWith(defaultUserLimit: limit);
                context.read<SettingsBloc>().add(UpdateSystemConfig(updatedConfig));
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMaxOrgsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Maximum Organizations'),
        content: TextField(
          controller: _maxOrgsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Number of organizations',
            hintText: 'Enter maximum organizations allowed',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final limit = int.tryParse(_maxOrgsController.text);
              if (limit != null && limit > 0) {
                final currentState = context.read<SettingsBloc>().state as SettingsLoaded;
                final updatedConfig = currentState.config.copyWith(maxOrganizations: limit);
                context.read<SettingsBloc>().add(UpdateSystemConfig(updatedConfig));
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDomainsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text('Allowed Email Domains'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _domainController,
                        decoration: const InputDecoration(
                          labelText: 'Domain',
                          hintText: 'e.g., gmail.com',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final domain = _domainController.text.trim();
                        if (domain.isNotEmpty && !_allowedDomains.contains(domain)) {
                          setState(() {
                            _allowedDomains.add(domain);
                            _domainController.clear();
                          });
                        }
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _allowedDomains.length,
                    itemBuilder: (context, index) {
                      final domain = _allowedDomains[index];
                      return ListTile(
                        title: Text(domain),
                        trailing: IconButton(
                          onPressed: () {
                            setState(() {
                              _allowedDomains.removeAt(index);
                            });
                          },
                          icon: const Icon(Icons.remove_circle, color: AppTheme.errorColor),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<SettingsBloc>().add(UpdateAllowedDomains(_allowedDomains));
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionTimeoutDialog(BuildContext context) {
    final currentState = context.read<SettingsBloc>().state as SettingsLoaded;
    final currentTimeout = currentState.config.securitySettings['sessionTimeoutMinutes'] ?? 60;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Session Timeout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimeoutOption(context, 30, '30 minutes'),
            _buildTimeoutOption(context, 60, '1 hour'),
            _buildTimeoutOption(context, 120, '2 hours'),
            _buildTimeoutOption(context, 480, '8 hours'),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeoutOption(BuildContext context, int minutes, String label) {
    return ListTile(
      title: Text(label),
      onTap: () {
        final currentState = context.read<SettingsBloc>().state as SettingsLoaded;
        final newSecuritySettings = Map<String, dynamic>.from(currentState.config.securitySettings);
        newSecuritySettings['sessionTimeoutMinutes'] = minutes;
        context.read<SettingsBloc>().add(UpdateSecuritySettings(newSecuritySettings));
        Navigator.of(context).pop();
      },
    );
  }
}
