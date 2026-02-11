import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/services/whatsapp_settings_service.dart';
import 'package:flutter/material.dart';

class WhatsappMessagesSwitchSection extends StatefulWidget {
  const WhatsappMessagesSwitchSection({
    super.key,
    required this.orgId,
    required this.isAdmin,
  });

  final String orgId;
  final bool isAdmin;

  @override
  State<WhatsappMessagesSwitchSection> createState() =>
      _WhatsappMessagesSwitchSectionState();
}

class _WhatsappMessagesSwitchSectionState
    extends State<WhatsappMessagesSwitchSection> {
  final WhatsappSettingsService _service = WhatsappSettingsService();
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isAdmin || widget.orgId.isEmpty) {
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled = await _service.fetchEnabled(widget.orgId);
      if (mounted) {
        setState(() {
          _enabled = enabled;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Could not load WhatsApp settings. Try again.');
      }
    }
  }

  Future<void> _onChanged(bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.setEnabled(widget.orgId, value);
      if (mounted) {
        setState(() => _enabled = value);
      }
    } catch (_) {
      if (mounted) {
        _showError('Could not update Whatsapp Messages. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String message) {
    DashSnackbar.show(context, message: message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAdmin || widget.orgId.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AuthColors.textMainWithOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: AuthColors.textDisabled,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'Whatsapp Messages',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'SF Pro Display',
              ),
            ),
            const Spacer(),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AuthColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: AuthColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Whatsapp Messages',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'SF Pro Display',
              ),
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: _saving ? null : _onChanged,
            activeTrackColor: AuthColors.primary,
            activeThumbColor: AuthColors.textMain,
          ),
        ],
      ),
    );
  }
}
