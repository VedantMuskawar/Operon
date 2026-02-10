import 'dart:io';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DeliveryPhotoDialog extends StatefulWidget {
  const DeliveryPhotoDialog({super.key});

  @override
  State<DeliveryPhotoDialog> createState() => _DeliveryPhotoDialogState();
}

class _DeliveryPhotoDialogState extends State<DeliveryPhotoDialog> {
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;
  bool _isUploading = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70, // Lower quality to reduce memory
        maxWidth: 1920,
        maxHeight: 1920,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image != null && mounted) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _handleUpload() async {
    if (_selectedImage == null || _isUploading) return;

    setState(() {
      _isUploading = true;
    });

    // Small delay to show loading state
    await Future.delayed(const Duration(milliseconds: 150));

    if (mounted) {
      final file = File(_selectedImage!.path);
      Navigator.of(context).pop(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: const Text(
        'Upload Delivery Photo',
        style: TextStyle(color: AuthColors.textMain),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _selectedImage == null
            ? _buildImageSelectionView()
            : _buildImagePreview(),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading
              ? null
              : () {
                  if (_selectedImage == null) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() {
                      _selectedImage = null;
                    });
                  }
                },
          child: Text(
            _selectedImage == null ? 'Cancel' : 'Change Photo',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        if (_selectedImage == null)
          TextButton(
            onPressed: _isUploading
                ? null
                : () {
                    Navigator.of(context).pop<File?>(null);
                  },
            child: const Text(
              'Skip & Mark Delivered',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ElevatedButton(
          onPressed:
              (_selectedImage == null || _isUploading) ? null : _handleUpload,
          style: ElevatedButton.styleFrom(
            backgroundColor: AuthColors.legacyAccent,
            foregroundColor: AuthColors.textMain,
            disabledBackgroundColor: AuthColors.textDisabled,
          ),
          child: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AuthColors.textMain),
                  ),
                )
              : const Text('Upload & Mark Delivered'),
        ),
      ],
    );
  }

  Widget _buildImageSelectionView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Please select a photo to upload',
          style: TextStyle(color: AuthColors.textMainWithOpacity(0.7)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.paddingXXL),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSourceButton(
              icon: Icons.camera_alt,
              label: 'Camera',
              onTap: () => _pickImage(ImageSource.camera),
            ),
            _buildSourceButton(
              icon: Icons.photo_library,
              label: 'Gallery',
              onTap: () => _pickImage(ImageSource.gallery),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingSM),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: AuthColors.secondary,
            foregroundColor: AuthColors.textMain,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingMD),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(
            maxHeight: 300,
            maxWidth: double.infinity,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: AuthColors.surface,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildImageWidget(),
          ),
        ),
        const SizedBox(height: AppSpacing.paddingLG),
        Text(
          'Photo selected. Tap "Upload & Mark Delivered" to proceed.',
          style: TextStyle(
              color: AuthColors.textMainWithOpacity(0.7), fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildImageWidget() {
    if (_selectedImage == null) {
      return const SizedBox.shrink();
    }

    // Use a FutureBuilder to handle image loading more safely
    return FutureBuilder<File>(
      future: Future.value(File(_selectedImage!.path)),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget();
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Colors.white70),
            ),
          );
        }

        final file = snapshot.data!;

        // Use a more memory-efficient approach
        return Image.file(
          file,
          fit: BoxFit.contain,
          // Significantly reduce cache size to prevent GPU errors
          cacheWidth: 800,
          cacheHeight: 600,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget();
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) {
              return child;
            }
            if (frame == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: AuthColors.textSub),
                ),
              );
            }
            return child;
          },
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey[800],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AuthColors.textSub, size: 48),
          SizedBox(height: AppSpacing.paddingSM),
          Text(
            'Failed to load image',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
