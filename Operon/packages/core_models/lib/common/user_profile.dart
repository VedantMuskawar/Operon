enum UserRole { user, admin, superAdmin }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.phoneNumber,
    required this.role,
    this.displayName,
    this.photoUrl,
  });

  final String id;
  final String phoneNumber;
  final UserRole role;
  final String? displayName;
  final String? photoUrl;

  UserProfile copyWith({
    String? displayName,
    String? photoUrl,
    UserRole? role,
  }) {
    return UserProfile(
      id: id,
      phoneNumber: phoneNumber,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  @override
  String toString() => 'UserProfile(id: $id, role: $role)';
}
