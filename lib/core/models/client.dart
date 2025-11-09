import 'package:cloud_firestore/cloud_firestore.dart';

class ClientAddress {
  final String? street;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? country;

  const ClientAddress({
    this.street,
    this.city,
    this.state,
    this.zipCode,
    this.country,
  });

  factory ClientAddress.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const ClientAddress();
    return ClientAddress(
      street: data['street'] as String?,
      city: data['city'] as String?,
      state: data['state'] as String?,
      zipCode: data['zipCode'] as String?,
      country: data['country'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (street != null) 'street': street,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (zipCode != null) 'zipCode': zipCode,
      if (country != null) 'country': country,
    };
  }
}

class Client {
  final String id;
  final String clientId;
  final String organizationId;
  final String name;
  final String phoneNumber;
  final String? email;
  final ClientAddress? address;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final String status;
  final String? notes;
  final List<String> tags;
  final List<String> phoneList;

  const Client({
    required this.id,
    required this.clientId,
    required this.organizationId,
    required this.name,
    required this.phoneNumber,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.email,
    this.address,
    this.createdBy,
    this.updatedBy,
    this.notes,
    this.tags = const [],
    this.phoneList = const [],
  });

  factory Client.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final createdAt = _parseTimestamp(data['createdAt']);
    final updatedAt = _parseTimestamp(data['updatedAt']);

    return Client(
      id: snapshot.id,
      clientId: (data['clientId'] as String?)?.trim().isNotEmpty == true
          ? data['clientId'] as String
          : snapshot.id,
      organizationId: data['organizationId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      phoneNumber: (data['phoneNumber'] as String? ?? '').trim(),
      email: (data['email'] as String?)?.trim().isNotEmpty == true
          ? data['email'] as String
          : null,
      address: data['address'] is Map<String, dynamic>
          ? ClientAddress.fromMap(data['address'] as Map<String, dynamic>)
          : null,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: data['createdBy'] as String?,
      updatedBy: data['updatedBy'] as String?,
      status: (data['status'] as String?)?.toLowerCase() ?? ClientStatus.active,
      notes: data['notes'] as String?,
      tags: _readStringList(data['tags']),
      phoneList: _readStringList(data['phoneList']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'organizationId': organizationId,
      'name': name,
      'phoneNumber': phoneNumber,
      if (email != null) 'email': email,
      if (address != null) 'address': address!.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
      'status': status,
      if (notes != null) 'notes': notes,
      if (tags.isNotEmpty) 'tags': tags,
      if (phoneList.isNotEmpty) 'phoneList': phoneList,
    };
  }

  Client copyWith({
    String? clientId,
    String? organizationId,
    String? name,
    String? phoneNumber,
    String? email,
    ClientAddress? address,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    String? status,
    String? notes,
    List<String>? tags,
    List<String>? phoneList,
  }) {
    return Client(
      id: id,
      clientId: clientId ?? this.clientId,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      phoneList: phoneList ?? this.phoneList,
    );
  }

  bool get isActive => status == ClientStatus.active;

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static List<String> _readStringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item?.toString())
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }
}

class ClientStatus {
  static const String active = 'active';
  static const String inactive = 'inactive';
  static const String archived = 'archived';

  static const List<String> values = [active, inactive, archived];
}
