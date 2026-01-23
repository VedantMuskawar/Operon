class FirestorePaths {
  FirestorePaths._();

  static String activeDriver(String uid) => 'active_drivers/$uid';

  static String tripHistory(String tripId) => 'trips/$tripId/history';
}

