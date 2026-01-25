/// Shared utilities for the Caller ID overlay.
/// Phone normalization matches [ClientService] logic for Firestore lookup.
String normalizePhone(String input) {
  return input.replaceAll(RegExp(r'[^0-9+]'), '');
}
