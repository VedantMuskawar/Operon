import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/gradient_card.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/repositories/config_repository.dart';
import '../../bloc/settings_bloc.dart';
import '../../bloc/settings_state.dart';
import '../../bloc/settings_event.dart';
import '../widgets/app_preferences_section.dart';
import '../widgets/system_config_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    // Load settings when page initializes
    context.read<SettingsBloc>().add(const LoadSettings());
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        title: const Text('Settings'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondaryColor,
          tabs: const [
            Tab(
              icon: Icon(Icons.person_outline),
              text: 'App Preferences',
            ),
            Tab(
              icon: Icon(Icons.settings_outlined),
              text: 'System Config',
            ),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, state) {
            if (state is SettingsLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading settings...',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (state is SettingsError) {
              return Center(
                child: CustomErrorWidget(
                  message: state.message,
                  onRetry: () {
                    context.read<SettingsBloc>().add(const LoadSettings());
                  },
                ),
              );
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _buildAppPreferencesTab(state),
                _buildSystemConfigTab(state),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppPreferencesTab(SettingsState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientCard(
            gradient: AppTheme.primaryGradient,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Preferences',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customize your personal settings and preferences',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const AppPreferencesSection(),
        ],
      ),
    );
  }

  Widget _buildSystemConfigTab(SettingsState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientCard(
            gradient: AppTheme.accentGradient,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.settings_outlined, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Configuration',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configure system-wide settings and defaults',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SystemConfigSection(),
        ],
      ),
    );
  }
}
