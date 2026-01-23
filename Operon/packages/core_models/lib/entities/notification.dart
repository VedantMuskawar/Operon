import 'package:cloud_firestore/cloud_firestore.dart';
import '../enums/notification_type.dart';

class Notification {
  const Notification({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.geofenceId,
    this.vehicleNumber,
    this.driverName,
    this.isRead = false,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String organizationId;
  final String userId; // Recipient user ID
  final NotificationType type;
  final String title;
  final String message;
  final String? geofenceId;
  final String? vehicleNumber;
  final String? driverName;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;

  factory Notification.fromMap(Map<String, dynamic> map, String id) {
    return Notification(
      id: id,
      organizationId: map['organization_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      type: NotificationType.values.firstWhere(
        (e) {
          final typeStr = map['type']?.toString() ?? '';
          return e.name == typeStr || 
                 (typeStr == 'geofence_enter' && e == NotificationType.geofenceEnter) ||
                 (typeStr == 'geofence_exit' && e == NotificationType.geofenceExit);
        },
        orElse: () => NotificationType.geofenceEnter,
      ),
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      geofenceId: map['geofence_id'] as String?,
      vehicleNumber: map['vehicle_number'] as String?,
      driverName: map['driver_name'] as String?,
      isRead: map['is_read'] as bool? ?? false,
      readAt: (map['read_at'] as Timestamp?)?.toDate(),
      createdAt: (map['created_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organization_id': organizationId,
      'user_id': userId,
      'type': type.name,
      'title': title,
      'message': message,
      if (geofenceId != null) 'geofence_id': geofenceId,
      if (vehicleNumber != null) 'vehicle_number': vehicleNumber,
      if (driverName != null) 'driver_name': driverName,
      'is_read': isRead,
      if (readAt != null) 'read_at': Timestamp.fromDate(readAt!),
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
    };
  }

  Notification copyWith({
    String? id,
    String? organizationId,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    String? geofenceId,
    String? vehicleNumber,
    String? driverName,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return Notification(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      geofenceId: geofenceId ?? this.geofenceId,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      driverName: driverName ?? this.driverName,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
