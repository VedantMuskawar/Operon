import 'package:shared_preferences/shared_preferences.dart';

class PhonePersistenceService {
  static const String _keyPhoneNumber = 'last_phone_number';

  /// Save phone number to local storage
  static Future<void> savePhoneNumber(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPhoneNumber, phoneNumber);
  }

  /// Load saved phone number from local storage
  static Future<String?> loadPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhoneNumber);
  }

  /// Clear saved phone number
  static Future<void> clearPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPhoneNumber);
  }
}
