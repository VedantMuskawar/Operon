import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle.dart';

class AndroidVehicleRepository {
  final FirebaseFirestore _firestore;

  AndroidVehicleRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<Vehicle>> getVehiclesStream(String organizationId) {
    print('Getting vehicles stream for orgId: $organizationId');
    try {
      return _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('VEHICLES')
          .snapshots()
          .map((snapshot) {
        print('Vehicles snapshot received: ${snapshot.docs.length} documents');
        try {
          final vehicles = <Vehicle>[];
          for (var doc in snapshot.docs) {
            try {
              final vehicle = Vehicle.fromFirestore(doc);
              vehicles.add(vehicle);
              print('Parsed vehicle: ${vehicle.vehicleNo}');
            } catch (e) {
              print('Error parsing vehicle document ${doc.id}: $e');
              print('Document data: ${doc.data()}');
              // Continue processing other documents
            }
          }
          vehicles.sort((a, b) => a.vehicleNo.compareTo(b.vehicleNo));
          print('Returning ${vehicles.length} vehicles');
          return vehicles;
        } catch (e) {
          print('Error processing vehicles stream: $e');
          return <Vehicle>[];
        }
      }).handleError((error) {
        print('Error in vehicles stream: $error');
        return <Vehicle>[];
      });
    } catch (e) {
      print('Error creating vehicles stream: $e');
      return Stream.value(<Vehicle>[]);
    }
  }

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
      vehicles.sort((a, b) => a.vehicleNo.compareTo(b.vehicleNo));
      return vehicles;
    } catch (e) {
      throw Exception('Failed to fetch vehicles: $e');
    }
  }

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
}

