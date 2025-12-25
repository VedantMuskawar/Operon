class DashboardMetric {
  const DashboardMetric({
    required this.title,
    required this.value,
    this.delta,
    this.icon,
  });

  final String title;
  final String value;
  final double? delta;
  final String? icon;

  @override
  String toString() => 'DashboardMetric($title: $value)';
}
