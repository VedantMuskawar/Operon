/// Exception thrown when attempting to create or update a user with a phone number
/// that already exists in the USERS collection.
class DuplicatePhoneNumberException implements Exception {
  const DuplicatePhoneNumberException(this.phoneNumber, [this.existingUserId]);

  final String phoneNumber;
  final String? existingUserId;

  @override
  String toString() {
    if (existingUserId != null) {
      return 'Phone number $phoneNumber is already registered to another user.';
    }
    return 'Phone number $phoneNumber is already registered.';
  }

  String get message => toString();
}
