class AdminForm {
  const AdminForm({
    required this.name,
    required this.phone,
    this.countryCode = '+91',
  });

  final String name;
  final String phone;
  final String countryCode;

  AdminForm normalized() {
    final sanitized = phone.replaceAll(RegExp(r'\s'), '');
    if (sanitized.startsWith(countryCode)) {
      return AdminForm(
        name: name,
        phone: sanitized,
        countryCode: countryCode,
      );
    }
    final digitsOnly = sanitized.replaceAll(RegExp(r'\D'), '');
    return AdminForm(
      name: name,
      phone: '$countryCode$digitsOnly',
      countryCode: countryCode,
    );
  }
}

