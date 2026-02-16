import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';

/// Model for update information
class UpdateInfo {
  final String version;
  final int buildCode;
  final String downloadUrl;
  final String releaseNotes;
  final String checksum;
  final bool mandatory;
  final int minSdkVersion;
  final int size; // in bytes

  UpdateInfo({
    required this.version,
    required this.buildCode,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.checksum,
    required this.mandatory,
    required this.minSdkVersion,
    required this.size,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String? ?? '1.0.0',
      buildCode: json['buildCode'] as int? ?? 0,
      downloadUrl: json['releaseUrl'] as String? ?? '',
      releaseNotes: json['releaseNotes'] as String? ?? '',
      checksum: json['checksum'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
      minSdkVersion: json['minSdkVersion'] as int? ?? 21,
      size: json['size'] as int? ?? 0,
    );
  }
}

/// Service for checking app updates from distribution server
class AppUpdateService {
  /// URL of the distribution server
  /// For production: change to your domain
  /// Currently: http://localhost:3000
  final String serverUrl;

  AppUpdateService({
    this.serverUrl = 'http://localhost:3000',
  });

  /// Check if an update is available
  /// Returns UpdateInfo if update is available, null otherwise
  Future<UpdateInfo?> checkForUpdate({
    String appName = 'operon-client',
  }) async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      // Query distribution server
      final response = await http
          .get(
            Uri.parse(
              '$serverUrl/api/version/$appName?currentBuild=$currentBuild',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        // Check if update is available
        if (json['updateAvailable'] == true) {
          final current = json['current'];
          return UpdateInfo.fromJson(current);
        }
      }

      return null;
    } catch (e, stackTrace) {
      print('Update check error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get changelog history
  /// Returns list of version history
  Future<List<Map<String, dynamic>>?> getChangelog({
    String appName = 'operon-client',
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$serverUrl/api/changelog/$appName'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['changelog'] is List) {
          return List<Map<String, dynamic>>.from(json['changelog']);
        }
      }

      return null;
    } catch (e) {
      print('Changelog fetch error: $e');
      return null;
    }
  }
}
