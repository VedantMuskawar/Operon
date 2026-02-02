import 'package:core_ui/core_ui.dart' show AuthColors, DashButton, DashButtonVariant, DashSnackbar;
import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/domain/entities/client.dart';
import 'package:dash_web/presentation/views/client_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Side panel widget for displaying client details
/// Slides in from the right with smooth animations
class ClientDetailPanel extends StatefulWidget {
  const ClientDetailPanel({
    super.key,
    required this.client,
    required this.onClose,
    this.onClientChanged,
  });

  final Client client;
  final VoidCallback onClose;
  final ValueChanged<Client>? onClientChanged;

  @override
  State<ClientDetailPanel> createState() => _ClientDetailPanelState();
}

class _ClientDetailPanelState extends State<ClientDetailPanel>
    with SingleTickerProviderStateMixin {
  late String _primaryPhone;
  late List<_PrimaryContactOption> _primaryOptions;
  int _selectedTabIndex = 0;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _primaryPhone = widget.client.primaryPhone ??
        (widget.client.phones.isNotEmpty
            ? (widget.client.phones.first['e164'] as String?) ?? '-'
            : '-');
    _primaryOptions = _buildPrimaryOptions(widget.client);

    // Animation setup
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _closePanel() {
    _animationController.reverse().then((_) {
      widget.onClose();
    });
  }

  List<_PrimaryContactOption> _buildPrimaryOptions(Client client) {
    final options = <_PrimaryContactOption>[];
    final seen = <String>{};

    for (final entry in client.phones) {
      final phone = (entry['e164'] as String?) ?? '';
      if (phone.isEmpty || !seen.add(phone)) continue;
      options.add(
        _PrimaryContactOption(
          label: phone,
          phone: phone,
        ),
      );
    }

    return options;
  }

  Future<void> _selectPrimaryContact() async {
    if (_primaryOptions.isEmpty) return;

    final selected = await showDialog<_PrimaryContactOption>(
      context: context,
      builder: (context) => _PrimaryContactDialog(
        options: _primaryOptions,
        currentPhone: _primaryPhone,
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _primaryPhone = selected.phone;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteClientDialog(
        clientName: widget.client.name,
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repository = context.read<ClientsRepository>();
        await repository.deleteClient(widget.client.id);
        if (!mounted) return;
        DashSnackbar.show(context, message: 'Client deleted.', isError: false);
        _closePanel();
      } catch (error) {
        if (!mounted) return;
        DashSnackbar.show(context, message: 'Unable to delete client: $error', isError: true);
      }
    }
  }

  Future<void> _editClient() async {
    // Navigate to edit or show edit dialog
    // For now, we'll use the existing edit functionality from clients_view
    // This can be enhanced later
    _closePanel();
    // The parent can handle opening edit dialog
  }

  Color _getClientColor() {
    if (widget.client.isCorporate) {
      return AuthColors.primary;
    }
    final hash = widget.client.name.hashCode;
    final colors = [
      AuthColors.successVariant,
      AuthColors.warning,
      AuthColors.info,
      AuthColors.error,
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 768;
    final panelWidth = isMobile ? screenWidth : (screenWidth > 1200 ? 800.0 : 700.0);
    final clientColor = _getClientColor();

    return SizedBox(
      width: screenWidth,
      height: screenHeight,
      child: Stack(
        children: [
        // Overlay background
        Positioned.fill(
          child: GestureDetector(
            onTap: _closePanel,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                color: AuthColors.background.withOpacity(0.5),
              ),
            ),
          ),
        ),

        // Panel
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              width: panelWidth,
              decoration: BoxDecoration(
                color: AuthColors.background,
                boxShadow: [
                  BoxShadow(
                    color: AuthColors.background.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  _PanelHeader(
                    client: widget.client,
                    primaryPhone: _primaryPhone,
                    clientColor: clientColor,
                    onClose: _closePanel,
                    onEdit: _editClient,
                    onDelete: _confirmDelete,
                    onSelectPrimaryContact: _selectPrimaryContact,
                  ),

                  // Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: AuthColors.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: AuthColors.textMainWithOpacity(0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabButton(
                            label: 'Overview',
                            isSelected: _selectedTabIndex == 0,
                            onTap: () => setState(() => _selectedTabIndex = 0),
                          ),
                        ),
                        Expanded(
                          child: _TabButton(
                            label: 'Orders',
                            isSelected: _selectedTabIndex == 1,
                            onTap: () => setState(() => _selectedTabIndex = 1),
                          ),
                        ),
                        Expanded(
                          child: _TabButton(
                            label: 'Ledger',
                            isSelected: _selectedTabIndex == 2,
                            onTap: () => setState(() => _selectedTabIndex = 2),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: [
                        OverviewSection(clientId: widget.client.id),
                        PendingOrdersSection(clientId: widget.client.id),
                        AnalyticsSection(clientId: widget.client.id, clientName: widget.client.name),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.client,
    required this.primaryPhone,
    required this.clientColor,
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
    required this.onSelectPrimaryContact,
  });

  final Client client;
  final String primaryPhone;
  final Color clientColor;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSelectPrimaryContact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            clientColor.withOpacity(0.3),
            AuthColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: AuthColors.textMainWithOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.close, color: AuthColors.textSub),
                onPressed: onClose,
                tooltip: 'Close',
              ),
              Expanded(
                child: Text(
                  client.name,
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit, color: AuthColors.textSub),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: AuthColors.textSub),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onSelectPrimaryContact,
            child: Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 16,
                  color: AuthColors.textSub,
                ),
                const SizedBox(width: 8),
                Text(
                  primaryPhone,
                  style: TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.edit,
                  size: 14,
                  color: AuthColors.textDisabled,
                ),
              ],
            ),
          ),
          if (client.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: client.tags.take(5).map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AuthColors.textMainWithOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? AuthColors.primary
                  : AuthColors.background,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AuthColors.textMain : AuthColors.textSub,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// Reuse the existing section widgets from client_detail_page.dart
// These will be imported or moved to a shared location
class _PrimaryContactOption {
  const _PrimaryContactOption({
    required this.label,
    required this.phone,
  });

  final String label;
  final String phone;
}

class _PrimaryContactDialog extends StatelessWidget {
  const _PrimaryContactDialog({
    required this.options,
    required this.currentPhone,
  });

  final List<_PrimaryContactOption> options;
  final String currentPhone;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AuthColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Primary Contact',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option.phone == currentPhone;
                  return ListTile(
                    tileColor: AuthColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? AuthColors.primary
                          : AuthColors.background,
                      child: Text(
                        option.label.isNotEmpty ? option.label[0] : '?',
                        style: TextStyle(color: AuthColors.textMain),
                      ),
                    ),
                    title: Text(
                      option.label,
                      style: TextStyle(color: AuthColors.textMain),
                    ),
                    subtitle: Text(
                      option.phone,
                      style: TextStyle(color: AuthColors.textDisabled),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: AuthColors.textSub)
                        : null,
                    onTap: () => Navigator.pop(context, option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteClientDialog extends StatelessWidget {
  const _DeleteClientDialog({required this.clientName});

  final String clientName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AuthColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete client',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This will permanently remove $clientName and all related analytics. This action cannot be undone.',
              style: TextStyle(
                color: AuthColors.textSub,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: DashButton(
                label: 'Delete client',
                onPressed: () => Navigator.pop(context, true),
                isDestructive: true,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: DashButton(
                label: 'Cancel',
                onPressed: () => Navigator.pop(context, false),
                variant: DashButtonVariant.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

