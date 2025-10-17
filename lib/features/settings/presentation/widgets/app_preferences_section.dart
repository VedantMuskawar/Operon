import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../bloc/settings_bloc.dart';
import '../../bloc/settings_state.dart';
import '../../bloc/settings_event.dart';
import 'setting_tile.dart';

class AppPreferencesSection extends StatelessWidget {
  const AppPreferencesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        if (state is! SettingsLoaded) {
          return const SizedBox.shrink();
        }

        final preferences = state.appPreferences;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingSection(
              title: 'Display & Appearance',
              children: [
                SettingTile(
                  title: 'Display Density',
                  subtitle: _getDisplayDensityLabel(preferences['displayDensity'] ?? 'comfortable'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showDisplayDensityDialog(context),
                ),
                const Divider(),
                SettingTile(
                  title: 'Theme',
                  subtitle: preferences['theme'] ?? 'dark',
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showThemeDialog(context),
                ),
              ],
            ),
            SettingSection(
              title: 'Language & Region',
              children: [
                SettingTile(
                  title: 'Language',
                  subtitle: _getLanguageLabel(preferences['language'] ?? 'en'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showLanguageDialog(context),
                ),
                const Divider(),
                SettingTile(
                  title: 'Timezone',
                  subtitle: preferences['timezone'] ?? 'UTC',
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showTimezoneDialog(context),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _getDisplayDensityLabel(String density) {
    switch (density) {
      case 'compact':
        return 'Compact - More content per screen';
      case 'comfortable':
        return 'Comfortable - Balanced spacing';
      case 'spacious':
        return 'Spacious - More breathing room';
      default:
        return 'Comfortable - Balanced spacing';
    }
  }

  String _getLanguageLabel(String language) {
    switch (language) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      default:
        return 'English';
    }
  }

  void _showDisplayDensityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Display Density'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDensityOption(context, 'compact', 'Compact'),
            _buildDensityOption(context, 'comfortable', 'Comfortable'),
            _buildDensityOption(context, 'spacious', 'Spacious'),
          ],
        ),
      ),
    );
  }

  Widget _buildDensityOption(BuildContext context, String value, String label) {
    return ListTile(
      title: Text(label),
      onTap: () {
        context.read<SettingsBloc>().add(UpdateAppPreferences({'displayDensity': value}));
        Navigator.of(context).pop();
      },
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Dark'),
              leading: const Icon(Icons.dark_mode),
              onTap: () {
                context.read<SettingsBloc>().add(const UpdateAppPreferences({'theme': 'dark'}));
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Light'),
              leading: const Icon(Icons.light_mode),
              enabled: false, // Only dark theme is supported
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(context, 'en', 'English'),
            _buildLanguageOption(context, 'es', 'Español'),
            _buildLanguageOption(context, 'fr', 'Français'),
            _buildLanguageOption(context, 'de', 'Deutsch'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, String value, String label) {
    return ListTile(
      title: Text(label),
      onTap: () {
        context.read<SettingsBloc>().add(UpdateAppPreferences({'language': value}));
        Navigator.of(context).pop();
      },
    );
  }

  void _showTimezoneDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Timezone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimezoneOption(context, 'UTC', 'UTC'),
            _buildTimezoneOption(context, 'EST', 'Eastern Time'),
            _buildTimezoneOption(context, 'PST', 'Pacific Time'),
            _buildTimezoneOption(context, 'IST', 'Indian Standard Time'),
          ],
        ),
      ),
    );
  }

  Widget _buildTimezoneOption(BuildContext context, String value, String label) {
    return ListTile(
      title: Text(label),
      onTap: () {
        context.read<SettingsBloc>().add(UpdateAppPreferences({'timezone': value}));
        Navigator.of(context).pop();
      },
    );
  }
}
