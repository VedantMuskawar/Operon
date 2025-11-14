import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadScheduleDeliveryProof({
    required String organizationId,
    required String scheduleId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final path =
        'organizations/$organizationId/sch_orders/$scheduleId/delivery/$fileName';
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(contentType: _inferContentType(fileName));
    final uploadTask = ref.putData(bytes, metadata);
    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  String _inferContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}


