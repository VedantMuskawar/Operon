class DeliveryCity {
  const DeliveryCity({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory DeliveryCity.fromMap(Map<String, dynamic> map, String id) {
    return DeliveryCity(
      id: id,
      name: (map['name'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
    };
  }
}

