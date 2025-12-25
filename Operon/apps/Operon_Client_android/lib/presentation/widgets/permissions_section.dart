import 'package:dash_mobile/data/services/call_overlay_manager.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsDialog extends StatefulWidget {
  const PermissionsDialog({super.key});

  @override
  State<PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<PermissionsDialog> {
  final _overlayManager = CallOverlayManager();
  bool _isCheckingPermissions = true;
  bool _phonePermissionGranted = false;
  bool _overlayPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isCheckingPermissions = true);

    final phoneStatus = await Permission.phone.status;
    final overlayStatus = await _overlayManager.hasOverlayPermission();

    setState(() {
      _phonePermissionGranted = phoneStatus.isGranted;
      _overlayPermissionGranted = overlayStatus;
      _isCheckingPermissions = false;
    });
  }

  Future<void> _requestPhonePermission() async {
    final status = await Permission.phone.request();
    setState(() {
      _phonePermissionGranted = status.isGranted;
    });

    if (!status.isGranted && status.isPermanentlyDenied) {
      if (mounted) {
        _showOpenSettingsDialog(
          'Phone Permission',
          'Phone permission is required for call detection. Please enable it in app settings.',
        );
      }
    }
  }

  Future<void> _requestOverlayPermission() async {
    final granted = await _overlayManager.requestOverlayPermission();
    setState(() {
      _overlayPermissionGranted = granted;
    });

    if (!granted) {
      if (mounted) {
        _showOpenSettingsDialog(
          'Overlay Permission',
          'Overlay permission is required to show caller information during calls. Please enable "Display over other apps" in app settings.',
        );
      }
    }
  }

  void _showOpenSettingsDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF11111B),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(color: Color(0xFF6F4BFF)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF11111B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Permissions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage app permissions for call detection and caller ID features.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            if (_isCheckingPermissions)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    color: Color(0xFF6F4BFF),
                  ),
                ),
              )
            else ...[
              // Phone Permission
              _PermissionTile(
                icon: Icons.phone,
                title: 'Phone Permission',
                description: 'Required to detect incoming calls and identify callers',
                isGranted: _phonePermissionGranted,
                onRequest: _requestPhonePermission,
                onOpenSettings: () => openAppSettings(),
              ),
              const SizedBox(height: 12),
              // Overlay Permission
              _PermissionTile(
                icon: Icons.layers,
                title: 'Display Over Other Apps',
                description: 'Required to show caller information overlay during calls',
                isGranted: _overlayPermissionGranted,
                onRequest: _requestOverlayPermission,
                onOpenSettings: () => openAppSettings(),
              ),
            ],
            const SizedBox(height: 24),
            // Debug section
            if (const bool.fromEnvironment('dart.vm.product') == false) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B2C),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bug_report, color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Debug Tools',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                        ),
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Test Overlay'),
                        onPressed: () async {
                          // Import and use CallOverlayManager to test
                          final overlayManager = CallOverlayManager();
                          final result = await overlayManager.testOverlay();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result
                                      ? 'Test overlay shown successfully'
                                      : 'Failed to show test overlay. Check logs.',
                                ),
                                backgroundColor: result
                                    ? const Color(0xFF4CAF50)
                                    : Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6F4BFF),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _checkPermissions,
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onRequest,
    required this.onOpenSettings,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted
              ? const Color(0xFF4CAF50).withOpacity(0.3)
              : Colors.white10,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isGranted
                      ? const Color(0xFF4CAF50).withOpacity(0.2)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isGranted ? const Color(0xFF4CAF50) : Colors.white70,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isGranted
                      ? const Color(0xFF4CAF50).withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isGranted ? 'Granted' : 'Required',
                  style: TextStyle(
                    color: isGranted
                        ? const Color(0xFF4CAF50)
                        : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (!isGranted) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                    ),
                    onPressed: onRequest,
                    child: const Text('Request Permission'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white30),
                  ),
                  onPressed: onOpenSettings,
                  child: const Text('Settings'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

