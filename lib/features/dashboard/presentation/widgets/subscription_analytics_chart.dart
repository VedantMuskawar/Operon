import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/organization.dart';

class SubscriptionAnalyticsChart extends StatefulWidget {
  final List<Organization> organizations;

  const SubscriptionAnalyticsChart({
    super.key,
    required this.organizations,
  });

  @override
  State<SubscriptionAnalyticsChart> createState() => _SubscriptionAnalyticsChartState();
}

class _SubscriptionAnalyticsChartState extends State<SubscriptionAnalyticsChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final subscriptionData = _getSubscriptionData();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  // Stack vertically on smaller screens
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.analytics,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Subscription Analytics',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Distribution by subscription tiers',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildLegend(subscriptionData),
                    ],
                  );
                } else {
                  // Original horizontal layout
                  return Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.analytics,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subscription Analytics',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Distribution by subscription tiers',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _buildLegend(subscriptionData),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 32),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 200,
                maxHeight: 400,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight = constraints.maxHeight;
                  final chartHeight = (availableHeight > 250 ? 300.0 : availableHeight * 0.8).toDouble();
                  
                  // Responsive chart layout
                  if (constraints.maxWidth < 600) {
                    // Stack vertically on smaller screens
                    return Column(
                      children: [
                        SizedBox(
                          height: chartHeight * 0.6,
                          child: PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection == null) {
                                      touchedIndex = -1;
                                      return;
                                    }
                                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                  });
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: _getSections(subscriptionData),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                'Total Organizations',
                                widget.organizations.length.toString(),
                                AppTheme.primaryColor,
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                'Active Subscriptions',
                                subscriptionData['active']?.toString() ?? '0',
                                AppTheme.successColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildStatItem(
                          'Monthly Revenue',
                          '₹${_calculateMonthlyRevenue().toStringAsFixed(0)}',
                          AppTheme.warningColor,
                        ),
                      ],
                    );
                  } else {
                    // Original horizontal layout for larger screens
                    return SizedBox(
                      height: chartHeight,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                    setState(() {
                                      if (!event.isInterestedForInteractions ||
                                          pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection == null) {
                                        touchedIndex = -1;
                                        return;
                                      }
                                      touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                    });
                                  },
                                ),
                                borderData: FlBorderData(show: false),
                                sectionsSpace: 2,
                                centerSpaceRadius: 60,
                                sections: _getSections(subscriptionData),
                              ),
                            ),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 1,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStatItem(
                                  'Total Organizations',
                                  widget.organizations.length.toString(),
                                  AppTheme.primaryColor,
                                ),
                                const SizedBox(height: 16),
                                _buildStatItem(
                                  'Active Subscriptions',
                                  subscriptionData['active']?.toString() ?? '0',
                                  AppTheme.successColor,
                                ),
                                const SizedBox(height: 16),
                                _buildStatItem(
                                  'Monthly Revenue',
                                  '₹${_calculateMonthlyRevenue().toStringAsFixed(0)}',
                                  AppTheme.warningColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, int> _getSubscriptionData() {
    final data = <String, int>{
      'basic': 0,
      'premium': 0,
      'enterprise': 0,
      'active': 0,
    };

    for (final org in widget.organizations) {
      if (org.subscription?.status == 'active') {
        data['active'] = (data['active'] ?? 0) + 1;
        
        switch (org.subscription?.tier) {
          case 'basic':
            data['basic'] = (data['basic'] ?? 0) + 1;
            break;
          case 'premium':
            data['premium'] = (data['premium'] ?? 0) + 1;
            break;
          case 'enterprise':
            data['enterprise'] = (data['enterprise'] ?? 0) + 1;
            break;
        }
      }
    }

    return data;
  }

  List<PieChartSectionData> _getSections(Map<String, int> data) {
    final sections = <PieChartSectionData>[];
    
    final basicCount = data['basic'] ?? 0;
    final premiumCount = data['premium'] ?? 0;
    final enterpriseCount = data['enterprise'] ?? 0;
    final total = basicCount + premiumCount + enterpriseCount;

    if (total == 0) {
      return [
        PieChartSectionData(
          color: AppTheme.borderColor,
          value: 1,
          title: 'No Data',
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ];
    }

    if (basicCount > 0) {
      sections.add(
        PieChartSectionData(
          color: AppTheme.primaryColor,
          value: basicCount.toDouble(),
          title: touchedIndex == 0 ? '$basicCount' : 'Basic',
          radius: touchedIndex == 0 ? 85 : 80,
          titleStyle: TextStyle(
            fontSize: touchedIndex == 0 ? 16 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (premiumCount > 0) {
      sections.add(
        PieChartSectionData(
          color: AppTheme.warningColor,
          value: premiumCount.toDouble(),
          title: touchedIndex == 1 ? '$premiumCount' : 'Premium',
          radius: touchedIndex == 1 ? 85 : 80,
          titleStyle: TextStyle(
            fontSize: touchedIndex == 1 ? 16 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (enterpriseCount > 0) {
      sections.add(
        PieChartSectionData(
          color: AppTheme.successColor,
          value: enterpriseCount.toDouble(),
          title: touchedIndex == 2 ? '$enterpriseCount' : 'Enterprise',
          radius: touchedIndex == 2 ? 85 : 80,
          titleStyle: TextStyle(
            fontSize: touchedIndex == 2 ? 16 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return sections;
  }

  Widget _buildLegend(Map<String, int> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegendItem('Basic', AppTheme.primaryColor, data['basic'] ?? 0),
        const SizedBox(height: 8),
        _buildLegendItem('Premium', AppTheme.warningColor, data['premium'] ?? 0),
        const SizedBox(height: 8),
        _buildLegendItem('Enterprise', AppTheme.successColor, data['enterprise'] ?? 0),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label ($count)',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  double _calculateMonthlyRevenue() {
    double total = 0.0;
    for (final org in widget.organizations) {
      if (org.subscription?.status == 'active') {
        switch (org.subscription?.tier) {
          case 'basic':
            total += 29.0;
            break;
          case 'premium':
            total += 99.0;
            break;
          case 'enterprise':
            total += 299.0;
            break;
        }
      }
    }
    return total;
  }
}
