class OrganizationForm {
  const OrganizationForm({
    required this.name,
    required this.industry,
    this.businessId,
  });

  final String name;
  final String industry;
  final String? businessId;
}


