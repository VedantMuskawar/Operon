import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle.dart';

class VehicleRepository {
  final FirebaseFirestore _firestore;

  VehicleRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get vehicles stream for a specific organization (subcollection)
  Stream<List<Vehicle>> getVehiclesStream(String organizationId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('VEHICLES')
        .snapshots()
        .map((snapshot) {
      final vehicles = snapshot.docs
          .map((doc) => Vehicle.fromFirestore(doc))
          .toList();
      // Sort vehicles by vehicleNo for consistent ordering
      vehicles.sort((a, b) => a.vehicleNo.compareTo(b.vehicleNo));
      return vehicles;
    });
  }

  // Get vehicles once (non-stream)
  Future<List<Vehicle>> getVehicles(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('VEHICLES')
          .get();

      final vehicles = snapshot.docs
          .map((doc) => Vehicle.fromFirestore(doc))
          .toList();
      // Sort vehicles by vehicleNo for consistent ordering
      vehicles.sort((a, b) => a.vehicleNo.compareTo(b.vehicleNo));
      return vehicles;
    } catch (e) {
      throw Exception('Failed to fetch vehicles: $e');
    }
  }

  // Add a new vehicle
  Future<String> addVehicle(String organizationId, Vehicle vehicle, String userId) async {
    try {
      final vehicleWithUser = Vehicle(
        id: vehicle.id,
        vehicleID: vehicle.vehicleID,
        vehicleNo: vehicle.vehicleNo,
        type: vehicle.type,
        meterType: vehicle.meterType,
        vehicleQuantity: vehicle.vehicleQuantity,
        status: vehicle.status,
        weeklyCapacity: vehicle.weeklyCapacity,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
        updatedBy: userId,
        assignedDriverId: vehicle.assignedDriverId,
        assignedDriverName: vehicle.assignedDriverName,
        assignedDriverContact: vehicle.assignedDriverContact,
        assignedDriverAt: vehicle.assignedDriverAt,
        assignedDriverBy: vehicle.assignedDriverBy,
      );

      final docRef = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('VEHICLES')
          .add(vehicleWithUser.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add vehicle: $e');
    }
  }

  // Update an existing vehicle
  Future<void> updateVehicle(
    String organizationId,
    String vehicleId,
    Vehicle vehicle,
    String userId,
  ) async {
    try {
      final vehicleWithUser = vehicle.copyWith(
        updatedAt: DateTime.now(),
        updatedBy: userId,
        assignedDriverAt: vehicle.assignedDriverAt,
        assignedDriverBy: vehicle.assignedDriverBy,
      );

      await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('VEHICLES')
          .doc(vehicleId)
          .update(vehicleWithUser.toFirestore());
    } catch (e) {
      throw Exception('Failed to update vehicle: $e');
    }
  }

  Future<Vehicle?> getVehicleAssignedToDriver({
    required String organizationId,
    required String driverId,
  }) async {
    final snapshot = await _firestore
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('VEHICLES')
        .where('assignedDriverId', isEqualTo: driverId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return Vehicle.fromFirestore(snapshot.docs.first);
  }

  Future<void> assignDriver({
    required String organizationId,
    required String vehicleId,
    String? driverId,
    String? driverName,
    String? driverContact,
    required String userId,
    bool force = false,
  }) async {
    try {
      final docRef = _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('VEHICLES')
          .doc(vehicleId);

      if (driverId != null && !force) {
        final existing = await getVehicleAssignedToDriver(
          organizationId: organizationId,
          driverId: driverId,
        );

        if (existing != null && existing.id != vehicleId) {
          throw DriverAssignmentConflictException(existing.vehicleNo);
        }
      }

      final now = DateTime.now();

      final updates = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(now),
        'updatedBy': userId,
      };

      if (driverId == null) {
        updates['assignedDriverId'] = FieldValue.delete();
        updates['assignedDriverName'] = FieldValue.delete();
        updates['assignedDriverContact'] = FieldValue.delete();
        updates['assignedDriverAt'] = FieldValue.delete();
        updates['assignedDriverBy'] = FieldValue.delete();
      } else {
        updates['assignedDriverId'] = driverId;
        updates['assignedDriverName'] = driverName;
        if (driverContact != null && driverContact.isNotEmpty) {
          updates['assignedDriverContact'] = driverContact;
        } else {
          updates['assignedDriverContact'] = FieldValue.delete();
        }
        updates['assignedDriverAt'] = Timestamp.fromDate(now);
        updates['assignedDriverBy'] = userId;
      }

      await docRef.update(updates);
    } on DriverAssignmentConflictException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to assign driver: $e');
    }
  }

  // Delete a vehicle
  Future<void> deleteVehicle(String organizationId, String vehicleId) async {
    try {
      await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('VEHICLES')
          .doc(vehicleId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete vehicle: $e');
    }
  }

  // Search vehicles by query
  Stream<List<Vehicle>> searchVehicles(
    String organizationId,
    String query,
  ) {
    final lowerQuery = query.toLowerCase();

    return _firestore
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('VEHICLES')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Vehicle.fromFirestore(doc))
          .where((vehicle) {
        return vehicle.vehicleID.toLowerCase().contains(lowerQuery) ||
            vehicle.vehicleNo.toLowerCase().contains(lowerQuery) ||
            vehicle.type.toLowerCase().contains(lowerQuery) ||
            vehicle.meterType.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  // Get a single vehicle by ID
  Future<Vehicle?> getVehicleById(String organizationId, String vehicleId) async {
    try {
      final doc = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('VEHICLES')
          .doc(vehicleId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return Vehicle.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch vehicle: $e');
    }
  }

  // Check if vehicle ID already exists for an organization
  Future<bool> vehicleIdExists(String organizationId, String vehicleID) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('VEHICLES')
          .where('vehicleID', isEqualTo: vehicleID)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check vehicle ID: $e');
    }
  }
}

class DriverAssignmentConflictException implements Exception {
  DriverAssignmentConflictException(this.vehicleNo);

  final String vehicleNo;

  @override
  String toString() => 'Driver already assigned to vehicle $vehicleNo';
}
