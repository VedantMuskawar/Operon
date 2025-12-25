class Client {
  const Client({
    required this.id,
    required this.name,
    required this.primaryPhone,
    required this.phones,
    required this.phoneIndex,
    required this.tags,
    required this.status,
    required this.organizationId,
    this.createdAt,
    this.stats,
  });

  final String id;
  final String name;
  final String? primaryPhone;
  final List<Map<String, dynamic>> phones;
  final List<String> phoneIndex;
  final List<String> tags;
  final String status;
  final String? organizationId;
  final DateTime? createdAt;
  final Map<String, dynamic>? stats;

  Map<String, dynamic> toJson() {
    return {
      'clientId': id,
      'name': name,
      'name_lc': name.toLowerCase(),
      'primaryPhone': primaryPhone,
      'phones': phones,
      'phoneIndex': phoneIndex,
      'tags': tags,
      'status': status,
      'organizationId': organizationId,
      'stats': stats ?? {'orders': 0, 'lifetimeAmount': 0},
    };
  }

  factory Client.fromJson(Map<String, dynamic> json, String docId) {
    final phoneEntries =
        List<Map<String, dynamic>>.from(json['phones'] ?? const <Map>[]);
    final phoneIndex = json['phoneIndex'] != null
        ? List<String>.from(json['phoneIndex'] as List)
        : phoneEntries
            .map((entry) => (entry['e164'] as String?) ?? '')
            .where((value) => value.isNotEmpty)
            .toList();

    return Client(
      id: json['clientId'] as String? ?? docId,
      name: (json['name'] as String?) ?? 'Unnamed Client',
      primaryPhone: json['primaryPhone'] as String?,
      phones: phoneEntries,
      phoneIndex: phoneIndex,
      tags: List<String>.from(json['tags'] ?? const []),
      status: (json['status'] as String?) ?? 'active',
      organizationId: json['organizationId'] as String?,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as dynamic).toDate()
          : null,
      stats: json['stats'] != null
          ? Map<String, dynamic>.from(json['stats'] as Map)
          : null,
    );
  }

  bool get isCorporate =>
      tags.any((tag) => tag.toLowerCase() == 'corporate');
}
