import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/domain/entities/client.dart';
import 'package:dash_web/presentation/views/client_detail_page.dart';
import 'package:dash_web/presentation/widgets/detail_modal_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Modal dialog for displaying client details
class ClientDetailModal extends StatefulWidget {
  const ClientDetailModal({
    super.key,
    required this.client,
    this.onClientChanged,
    this.onEdit,
  });

  final Client client;
  final ValueChanged<Client>? onClientChanged;
  final VoidCallback? onEdit;

  @override
  State<ClientDetailModal> createState() => _ClientDetailModalState();
}

class _ClientDetailModalState extends State<ClientDetailModal> {
  late String _primaryPhone;
  late List<_PrimaryContactOption> _primaryOptions;
  int _selectedTabIndex = 0; // 0 = Orders, 1 = Ledger

  @override
  void initState() {
    super.initState();
    _primaryPhone = widget.client.primaryPhone ??
        (widget.client.phones.isNotEmpty
            ? (widget.client.phones.first['e164'] as String?) ?? '-'
            : '-');
    _primaryOptions = _buildPrimaryOptions(widget.client);
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
      try {
        final repository = context.read<ClientsRepository>();
        await repository.updatePrimaryPhone(
          clientId: widget.client.id,
          newPhone: selected.phone,
        );
        if (!mounted) return;
        setState(() {
          _primaryPhone = selected.phone;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primary number updated.')),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update number: $error')),
        );
      }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client deleted.')),
        );
        Navigator.of(context).pop();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete client: $error')),
        );
      }
    }
  }

  void _editClient() {
    if (widget.onEdit != null) {
      Navigator.of(context).pop();
      widget.onEdit!();
    }
  }

  Color _getClientColor() {
    if (widget.client.isCorporate) {
      return const Color(0xFF6F4BFF);
    }
    final hash = widget.client.name.hashCode;
    final colors = [
      const Color(0xFF5AD8A4),
      const Color(0xFFFF9800),
      const Color(0xFF2196F3),
      const Color(0xFFE91E63),
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final clientColor = _getClientColor();

    return DetailModalBase(
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _ModalHeader(
            client: widget.client,
            primaryPhone: _primaryPhone,
            clientColor: clientColor,
            onClose: () => Navigator.of(context).pop(),
            onEdit: _editClient,
            onDelete: _confirmDelete,
            onSelectPrimaryContact: _selectPrimaryContact,
            getInitials: _getInitials,
          ),

          // Tabs
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131324),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: 'Orders',
                    isSelected: _selectedTabIndex == 0,
                    onTap: () => setState(() => _selectedTabIndex = 0),
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    label: 'Ledger',
                    isSelected: _selectedTabIndex == 1,
                    onTap: () => setState(() => _selectedTabIndex = 1),
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
                PendingOrdersSection(clientId: widget.client.id),
                AnalyticsSection(
                  clientId: widget.client.id,
                  clientName: widget.client.name,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModalHeader extends StatelessWidget {
  const _ModalHeader({
    required this.client,
    required this.primaryPhone,
    required this.clientColor,
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
    required this.onSelectPrimaryContact,
    required this.getInitials,
  });

  final Client client;
  final String primaryPhone;
  final Color clientColor;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSelectPrimaryContact;
  final String Function(String) getInitials;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            clientColor.withOpacity(0.3),
            const Color(0xFF1B1B2C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      clientColor,
                      clientColor.withOpacity(0.7),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    getInitials(client.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (client.isCorporate)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: clientColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: clientColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              'Corporate',
                              style: TextStyle(
                                color: clientColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: onClose,
                tooltip: 'Close',
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white70),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
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
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  primaryPhone,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.edit,
                  size: 14,
                  color: Colors.white54,
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
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: Colors.white70,
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
                  ? const Color(0xFF6F4BFF)
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

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
      backgroundColor: const Color(0xFF1B1B2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Primary Contact',
              style: TextStyle(
                color: Colors.white,
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
                    tileColor: const Color(0xFF131324),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? const Color(0xFF6F4BFF)
                          : const Color(0xFF2A2A3D),
                      child: Text(
                        option.label.isNotEmpty ? option.label[0] : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      option.label,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      option.phone,
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.white70)
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
      backgroundColor: const Color(0xFF1B1B2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delete client',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This will permanently remove $clientName and all related analytics. This action cannot be undone.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFED5A5A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete client'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

