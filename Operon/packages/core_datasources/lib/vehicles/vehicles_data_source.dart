import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';

class VehiclesDataSource {
  VehiclesDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _vehiclesRef(String orgId) {
    return _firestore.collection('ORGANIZATIONS').doc(orgId).collection('VEHICLES');
  }

  Future<List<Vehicle>> fetchVehicles(String orgId) async {
    final snapshot = await _vehiclesRef(orgId).orderBy('vehicleNumber').get();
    return snapshot.docs.map((doc) => Vehicle.fromJson(doc.data(), doc.id)).toList();
  }

  Future<void> createVehicle(String orgId, Vehicle vehicle) {
    final payload = {
      ...vehicle.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return _vehiclesRef(orgId).doc(vehicle.id).set(payload);
  }

  Future<void> updateVehicle(String orgId, Vehicle vehicle) {
    final payload = {
      ...vehicle.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return _vehiclesRef(orgId).doc(vehicle.id).update(payload);
  }

  Future<void> deleteVehicle(String orgId, String vehicleId) {
    return _vehiclesRef(orgId).doc(vehicleId).delete();
  }
}

