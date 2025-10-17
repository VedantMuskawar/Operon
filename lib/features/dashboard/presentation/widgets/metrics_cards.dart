import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/gradient_card.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../core/repositories/user_repository.dart';
import '../../../organization/bloc/organization_bloc.dart';

class MetricsCards extends StatefulWidget {
  const MetricsCards({super.key});

  @override
  State<MetricsCards> createState() => _MetricsCardsState();
}

class _MetricsCardsState extends State<MetricsCards>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<Animation<double>> _animations;
  
  int totalOrganizations = 0;
  int activeUsers = 0;
  int activeSubscriptions = 0;
  double monthlyRevenue = 0.0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _animations = List.generate(4, (index) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          index * 0.1,
          1.0,
          curve: Curves.easeOutCubic,
        ),
      ));
    });

    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      final organizationRepository = OrganizationRepository();
      final userRepository = UserRepository();
      
      final organizations = await organizationRepository.getOrganizations();
      final users = await userRepository.getUsers();
      
      setState(() {
        totalOrganizations = organizations.length;
        activeUsers = users.where((user) => user.status == 'active').length;
        activeSubscriptions = organizations.where((org) => 
          org.subscription?.status == 'active'
        ).length;
        monthlyRevenue = _calculateMonthlyRevenue(organizations);
        isLoading = false;
      });
      
      _animationController.forward();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _animationController.forward();
    }
  }

  double _calculateMonthlyRevenue(List<dynamic> organizations) {
    double total = 0.0;
    for (final org in organizations) {
      if (org.subscription?.status == 'active') {
        if (org.subscription?.tier == 'premium') {
          total += 99.0;
        } else if (org.subscription?.tier == 'enterprise') {
          total += 299.0;
        } else {
          total += 29.0; // basic
        }
      }
    }
    return total;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Row(
        children: [
          Expanded(child: _LoadingMetricCard()),
          SizedBox(width: 16),
          Expanded(child: _LoadingMetricCard()),
          SizedBox(width: 16),
          Expanded(child: _LoadingMetricCard()),
          SizedBox(width: 16),
          Expanded(child: _LoadingMetricCard()),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive layout based on available width
        if (constraints.maxWidth < 800) {
          // Stack cards vertically on smaller screens
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Total Organizations',
                      value: totalOrganizations.toString(),
                      icon: Icons.business,
                      gradient: AppTheme.primaryGradient,
                      animation: _animations[0],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Active Users',
                      value: activeUsers.toString(),
                      icon: Icons.people,
                      gradient: AppTheme.successGradient,
                      animation: _animations[1],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Active Subscriptions',
                      value: activeSubscriptions.toString(),
                      icon: Icons.card_membership,
                      gradient: AppTheme.accentGradient,
                      animation: _animations[2],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Revenue (Monthly)',
                      value: '₹${monthlyRevenue.toStringAsFixed(0)}',
                      icon: Icons.attach_money,
                      gradient: AppTheme.heroGradient,
                      animation: _animations[3],
                    ),
                  ),
                ],
              ),
            ],
          );
        } else {
          // Original horizontal layout for larger screens
          return Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Organizations',
                  value: totalOrganizations.toString(),
                  icon: Icons.business,
                  gradient: AppTheme.primaryGradient,
                  animation: _animations[0],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  title: 'Active Users',
                  value: activeUsers.toString(),
                  icon: Icons.people,
                  gradient: AppTheme.successGradient,
                  animation: _animations[1],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  title: 'Active Subscriptions',
                  value: activeSubscriptions.toString(),
                  icon: Icons.card_membership,
                  gradient: AppTheme.accentGradient,
                  animation: _animations[2],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  title: 'Revenue (Monthly)',
                  value: '₹${monthlyRevenue.toStringAsFixed(0)}',
                  icon: Icons.attach_money,
                  gradient: AppTheme.heroGradient,
                  animation: _animations[3],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required LinearGradient gradient,
    required Animation<double> animation,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * animation.value),
          child: Opacity(
            opacity: animation.value,
            child: GradientCardWithGlow(
              gradient: gradient,
              padding: const EdgeInsets.all(20),
              glowColor: gradient.colors.first,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppTheme.heroGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppTheme.glowShadow,
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '+12%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.trending_up,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'From last month',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoadingMetricCard extends StatelessWidget {
  const _LoadingMetricCard();

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      gradient: AppTheme.cardGradient,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const Spacer(),
              Container(
                width: 40,
                height: 20,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: 60,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 120,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
