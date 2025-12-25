class OrganizationSummary {
  const OrganizationSummary({
    required this.id,
    required this.name,
    required this.industry,
    required this.orgCode,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String industry;
  final String orgCode;
  final DateTime? createdAt;
}


