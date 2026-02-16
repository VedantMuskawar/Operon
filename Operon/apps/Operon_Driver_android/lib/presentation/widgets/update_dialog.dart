import 'package:flutter/material.dart';
import 'package:operon_driver_android/data/services/app_update_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dialog widget to show when an app update is available
class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  final VoidCallback? onDismiss;

  const UpdateDialog({
    required this.updateInfo,
    this.onDismiss,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Available'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  const TextSpan(
                    text: 'Version ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(
                    text: updateInfo.version,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const TextSpan(text: ' is available'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'What\'s New:',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                updateInfo.releaseNotes,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            if (updateInfo.mandatory)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: Colors.red[700],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This update is required to continue using the app.',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (!updateInfo.mandatory)
          TextButton(
            onPressed: () {
              onDismiss?.call();
              Navigator.pop(context);
            },
            child: const Text('Later'),
          ),
        ElevatedButton.icon(
          onPressed: () => _downloadAndInstall(
            context,
            updateInfo.downloadUrl,
          ),
          icon: const Icon(Icons.download),
          label: const Text('Download & Install'),
        ),
      ],
    );
  }

  Future<void> _downloadAndInstall(
    BuildContext context,
    String downloadUrl,
  ) async {
    try {
      final uri = Uri.parse(downloadUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open download link'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error launching download: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
