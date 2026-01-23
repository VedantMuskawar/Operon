import 'dart:io';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:operon_driver_android/core/services/storage_service.dart';
import 'package:operon_driver_android/core/utils/trip_status_utils.dart';
import 'package:operon_driver_android/presentation/widgets/slide_action_button.dart';

/// Morphing UI component that changes based on trip status.
/// 
/// Provides a single progressive sheet that adapts to the current trip state:
/// - scheduled: Initial Reading input + Start action
/// - dispatched: Photo upload + Deliver action (with rescue banner if source == 'client')
/// - delivered: Final Reading input + Return action
/// - returned: History toggle + completion details
class TripExecutionSheet extends StatefulWidget {
  const TripExecutionSheet({
    super.key,
    required this.trip,
    required this.onDispatch,
    required this.onDelivery,
    required this.onReturn,
    this.organizationId,
  });

  final Map<String, dynamic> trip;
  final Future<void> Function(double initialReading) onDispatch;
  final Future<void> Function(String photoUrl) onDelivery;
  final Future<void> Function(double finalReading) onReturn;
  final String? organizationId;

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> trip,
    required Future<void> Function(double initialReading) onDispatch,
    required Future<void> Function(String photoUrl) onDelivery,
    required Future<void> Function(double finalReading) onReturn,
    String? organizationId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar for modal
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AuthColors.textSub.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Trip execution content
                TripExecutionSheet(
                  trip: trip,
                  onDispatch: onDispatch,
                  onDelivery: onDelivery,
                  onReturn: onReturn,
                  organizationId: organizationId,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<TripExecutionSheet> createState() => _TripExecutionSheetState();
}

class _TripExecutionSheetState extends State<TripExecutionSheet> {
  final TextEditingController _readingController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  
  // Expose reading controller for external access if needed
  TextEditingController get readingController => _readingController;
  
  XFile? _selectedImage;
  bool _isUploading = false;
  bool _isProcessing = false;

  // Computed properties (memoized - only recalculate when trip prop changes)
  String get _tripStatus => getTripStatus(widget.trip);
  String? get _source => widget.trip['source'] as String?;
  bool get _isManualDispatch => _source == 'client' && _tripStatus == 'dispatched';

  /// Get status color based on trip status (matching schedule tiles)
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'scheduled':
        return AuthColors.error; // Red for scheduled
      case 'dispatched':
        return AuthColors.warning; // Yellow/orange for dispatched
      case 'delivered':
        return AuthColors.info; // Blue for delivered
      case 'returned':
        return AuthColors.success; // Green for returned
      default:
        return AuthColors.error;
    }
  }

  @override
  void initState() {
    super.initState();
    // Listen to reading controller changes to update slide button state
    _readingController.addListener(() {
      if (mounted) {
        setState(() {
          // Trigger rebuild to update slide button enabled state
        });
      }
    });
  }

  @override
  void dispose() {
    _readingController.dispose();
    super.dispose();
  }

  Future<void> _handleStartTrip() async {
    if (!_formKey.currentState!.validate()) return;

    final reading = double.parse(_readingController.text.trim());
    setState(() => _isProcessing = true);

    try {
      await widget.onDispatch(reading);
      // Don't close - widget is used inline, not as a modal
      // The trip status change will update the UI automatically
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start trip: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handlePickPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
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

  Future<void> _handleMarkDelivered() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery photo first')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      if (widget.organizationId == null) {
        throw Exception('Organization ID not provided');
      }

      final orderId = widget.trip['orderId']?.toString() ?? '';
      final tripId = widget.trip['id']?.toString() ?? '';

      final storageService = StorageService();
      final photoUrl = await storageService.uploadDeliveryPhoto(
        imageFile: File(_selectedImage!.path),
        organizationId: widget.organizationId!,
        orderId: orderId,
        tripId: tripId,
      );

      await widget.onDelivery(photoUrl);
      // Don't close - widget is used inline, not as a modal
      // The trip status change will update the UI automatically
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as delivered: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _handleMarkReturned() async {
    if (!_formKey.currentState!.validate()) return;

    final reading = double.parse(_readingController.text.trim());
    setState(() => _isProcessing = true);

    try {
      await widget.onReturn(reading);
      // Don't close - widget is used inline, not as a modal
      // The trip status change will update the UI automatically
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as returned: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status-based content (no handle bar for inline usage)
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_tripStatus) {
      case 'scheduled':
        return _buildScheduledState();
      case 'dispatched':
        return _buildDispatchedState();
      case 'delivered':
        return _buildDeliveredState();
      case 'returned':
        return _buildReturnedState();
      default:
        return _buildDefaultState();
    }
  }

  Widget _buildScheduledState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Start Trip',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter initial odometer reading',
          style: TextStyle(
            color: AuthColors.textSub,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _readingController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AuthColors.textMain),
            decoration: InputDecoration(
              labelText: 'Initial Reading',
              labelStyle: const TextStyle(color: AuthColors.textSub),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.2)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AuthColors.legacyAccent),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              filled: true,
              fillColor: AuthColors.background,
            ),
            validator: (value) {
              final v = double.tryParse((value ?? '').trim());
              if (v == null || v < 0) return 'Enter a valid number';
              return null;
            },
          ),
        ),
        const SizedBox(height: 24),
        SlideActionButton(
          onConfirmed: _isProcessing ? () {} : _handleStartTrip,
          text: _isProcessing ? 'Starting...' : 'Slide to Start Trip',
          confirmedText: 'Trip Started!',
          enabled: _readingController.text.trim().isNotEmpty &&
              double.tryParse(_readingController.text.trim()) != null &&
              double.tryParse(_readingController.text.trim())! >= 0,
          foregroundColor: _getStatusColor('scheduled'),
          backgroundColor: AuthColors.surface,
        ),
      ],
    );
  }

  Widget _buildDispatchedState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mark Delivered',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Rescue banner if dispatched by client
        if (_isManualDispatch) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AuthColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AuthColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AuthColors.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trip Dispatched by HQ (No Tracking)',
                    style: TextStyle(
                      color: AuthColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Text(
          'Upload delivery photo',
          style: TextStyle(
            color: AuthColors.textSub,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        // Photo selection
        if (_selectedImage == null)
          FilledButton.icon(
            onPressed: _handlePickPhoto,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Photo'),
            style: FilledButton.styleFrom(
              backgroundColor: AuthColors.legacyAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          )
        else
          Column(
            children: [
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AuthColors.background,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_selectedImage!.path),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _selectedImage = null),
                child: const Text('Change Photo'),
              ),
            ],
          ),
        const SizedBox(height: 24),
        SlideActionButton(
          onConfirmed: _isUploading ? () {} : _handleMarkDelivered,
          text: _isUploading ? 'Uploading...' : 'Slide to Mark Delivered',
          confirmedText: 'Delivered!',
          enabled: _selectedImage != null,
          foregroundColor: _getStatusColor('dispatched'),
          backgroundColor: AuthColors.surface,
        ),
      ],
    );
  }

  Widget _buildDeliveredState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mark Returned',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter final odometer reading',
          style: TextStyle(
            color: AuthColors.textSub,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _readingController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AuthColors.textMain),
            decoration: InputDecoration(
              labelText: 'Final Reading',
              labelStyle: const TextStyle(color: AuthColors.textSub),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.2)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AuthColors.legacyAccent),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              filled: true,
              fillColor: AuthColors.background,
            ),
            validator: (value) {
              final v = double.tryParse((value ?? '').trim());
              if (v == null || v < 0) return 'Enter a valid number';
              final initialReading = (widget.trip['initialReading'] as num?)?.toDouble();
              if (initialReading != null && v < initialReading) {
                return 'Final reading must be >= initial reading';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 24),
        SlideActionButton(
          onConfirmed: _isProcessing ? () {} : _handleMarkReturned,
          text: _isProcessing ? 'Processing...' : 'Slide to Mark Returned',
          confirmedText: 'Returned!',
          enabled: _readingController.text.trim().isNotEmpty &&
              double.tryParse(_readingController.text.trim()) != null &&
              double.tryParse(_readingController.text.trim())! >= 0,
          foregroundColor: _getStatusColor('delivered'),
          backgroundColor: AuthColors.surface,
        ),
      ],
    );
  }

  Widget _buildReturnedState() {
    final initialReading = (widget.trip['initialReading'] as num?)?.toDouble();
    final finalReading = (widget.trip['finalReading'] as num?)?.toDouble();
    final distance = (widget.trip['distanceTravelled'] as num?)?.toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Trip Completed',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AuthColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (initialReading != null)
                _buildDetailRow('Initial Reading', initialReading.toStringAsFixed(0)),
              if (finalReading != null)
                _buildDetailRow('Final Reading', finalReading.toStringAsFixed(0)),
              if (distance != null)
                _buildDetailRow('Distance Travelled', '${distance.toStringAsFixed(2)} km'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDefaultState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Trip Status: ${_tripStatus.toUpperCase()}',
          style: const TextStyle(
            color: AuthColors.textMain,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
