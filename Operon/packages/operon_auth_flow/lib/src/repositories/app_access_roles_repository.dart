import 'package:operon_auth_flow/src/datasources/app_access_roles_data_source.dart';
import 'package:operon_auth_flow/src/models/app_access_role.dart';

class AppAccessRolesRepository {
  AppAccessRolesRepository({required AppAccessRolesDataSource dataSource})
      : _dataSource = dataSource;

  final AppAccessRolesDataSource _dataSource;

  // Simple in-memory cache with TTL (5 minutes)
  final Map<String, _CachedRoles> _cache = {};
  static const Duration _cacheTTL = Duration(minutes: 5);

  Future<List<AppAccessRole>> fetchAppAccessRoles(String orgId) async {
    final cacheKey = 'roles_$orgId';
    final cached = _cache[cacheKey];

    // Return cached data if still valid
    if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTTL) {
      return cached.roles;
    }

    // Fetch fresh data
    final roles = await _dataSource.fetchAppAccessRoles(orgId);

    // Update cache
    _cache[cacheKey] = _CachedRoles(
      roles: roles,
      timestamp: DateTime.now(),
    );

    return roles;
  }

  Future<AppAccessRole?> fetchAppAccessRole(String orgId, String roleId) async {
    // Try to get from cache first
    final cacheKey = 'roles_$orgId';
    final cached = _cache[cacheKey];

    if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTTL) {
      try {
        return cached.roles.firstWhere((role) => role.id == roleId);
      } catch (_) {
        // Role not in cache, fetch individually
      }
    }

    return _dataSource.fetchAppAccessRole(orgId, roleId);
  }

  Future<void> createAppAccessRole(String orgId, AppAccessRole role) async {
    await _dataSource.createAppAccessRole(orgId, role);
    // Invalidate cache
    _cache.remove('roles_$orgId');
  }

  Future<void> updateAppAccessRole(String orgId, AppAccessRole role) async {
    await _dataSource.updateAppAccessRole(orgId, role);
    // Invalidate cache
    _cache.remove('roles_$orgId');
  }

  Future<void> deleteAppAccessRole(String orgId, String roleId) async {
    await _dataSource.deleteAppAccessRole(orgId, roleId);
    // Invalidate cache
    _cache.remove('roles_$orgId');
  }

  /// Clear all cached data
  void clearCache() {
    _cache.clear();
  }
}

class _CachedRoles {
  _CachedRoles({
    required this.roles,
    required this.timestamp,
  });

  final List<AppAccessRole> roles;
  final DateTime timestamp;
}

