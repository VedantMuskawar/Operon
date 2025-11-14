import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../models/dashboard_metadata.dart';

class DashboardMetadataRepository {
  DashboardMetadataRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _clientsSummaryRef() {
    return _firestore
        .collection(AppConstants.dashboardMetadataCollection)
        .doc(AppConstants.dashboardClientsDocument);
  }

  CollectionReference<Map<String, dynamic>> _clientsFinancialYearsRef() {
    return _clientsSummaryRef()
        .collection(AppConstants.dashboardFinancialYearsSubcollection);
  }

  Future<DashboardClientsSummary> fetchClientsSummary() async {
    final doc = await _clientsSummaryRef().get();
    if (!doc.exists || doc.data() == null) {
      return DashboardClientsSummary.empty();
    }
    return DashboardClientsSummary.fromSnapshot(doc.data()!);
  }

  Future<List<DashboardClientsYearlyMetadata>> fetchClientFinancialYears({
    bool descending = true,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = _clientsFinancialYearsRef()
        .orderBy('financialYearId', descending: descending);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map(
          (doc) =>
              DashboardClientsYearlyMetadata.fromSnapshot(doc.id, doc.data()),
        )
        .toList(growable: false);
  }

  Future<DashboardClientsYearlyMetadata> fetchClientFinancialYear(
    String financialYearId,
  ) async {
    final doc =
        await _clientsFinancialYearsRef().doc(financialYearId).get();
    if (!doc.exists || doc.data() == null) {
      return DashboardClientsYearlyMetadata.empty(financialYearId);
    }
    return DashboardClientsYearlyMetadata.fromSnapshot(doc.id, doc.data()!);
  }
}

