import 'dart:async';

import 'package:dash_mobile/data/repositories/pending_orders_repository.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/order_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
// ignore_for_file: deprecated_member_use, unused_element, no_leading_underscores_for_local_identifiers, avoid_types_as_parameter_names
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientDetailPage extends StatefulWidget {
  const ClientDetailPage({super.key, required this.client});

  final ClientRecord client;

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  final ClientService _clientService = ClientService();
  late String _primaryPhone;
  late List<_PrimaryContactOption> _primaryOptions;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _primaryPhone = widget.client.primaryPhone ??
        (widget.client.phones.isNotEmpty
            ? widget.client.phones.first['number'] as String
            : '-');
    _primaryOptions = _buildPrimaryOptions(widget.client);
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
      child: Column(
        children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Client Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // Client Header Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ClientHeader(
                client: client,
            phone: _primaryPhone,
            onEdit: _selectPrimaryContact,
            onDelete: _confirmDelete,
              ),
          ),
          const SizedBox(height: 16),
            // Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131324),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
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
      ),
            const SizedBox(height: 16),
            // Content based on selected tab
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _PendingOrdersSection(clientId: widget.client.id),
                  _AnalyticsSection(clientId: widget.client.id),
              ],
              ),
          ),
        ],
        ),
      ),
    );
  }

  List<_PrimaryContactOption> _buildPrimaryOptions(ClientRecord client) {
    final options = <_PrimaryContactOption>[];
    final seen = <String>{};

    for (final contact in client.contacts) {
      final phone = contact.phone;
      if (phone.isEmpty || !seen.add(phone)) continue;
      options.add(
        _PrimaryContactOption(
          label: contact.name.isNotEmpty ? contact.name : phone,
          phone: phone,
          subtitle: contact.description,
        ),
      );
    }

    for (final entry in client.phones) {
      final phone = (entry['number'] as String?) ?? '';
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
    final options = _primaryOptions.isNotEmpty
        ? _primaryOptions
        : _buildPrimaryOptions(widget.client);
    if (options.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contacts available to assign.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<_PrimaryContactOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PrimaryContactSheet(
        options: options,
        currentPhone: _primaryPhone,
      ),
    );

    if (selected == null || selected.phone == _primaryPhone) {
      return;
    }

    await _updatePrimaryPhone(selected.phone);
  }

  Future<void> _updatePrimaryPhone(String newPhone) async {
    try {
      await _clientService.updatePrimaryPhone(
        clientId: widget.client.id,
        newPhone: newPhone,
      );
      if (!mounted) return;
      final updatedOptions = [..._primaryOptions];
      final index =
          updatedOptions.indexWhere((option) => option.phone == newPhone);
      if (index == -1) {
        updatedOptions.add(
          _PrimaryContactOption(label: newPhone, phone: newPhone),
        );
      }
      setState(() {
        _primaryPhone = newPhone;
        _primaryOptions = updatedOptions;
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

  Future<void> _confirmDelete() async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _DeleteClientSheet(
        clientName: widget.client.name,
      ),
    );

    if (confirm != true) return;

    try {
      await _clientService.deleteClient(widget.client.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client deleted.')),
      );
      context.go('/clients');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete client: $error')),
      );
    }
  }
}

class _ClientHeader extends StatelessWidget {
  const _ClientHeader({
    required this.client,
    required this.phone,
    required this.onEdit,
    required this.onDelete,
  });

  final ClientRecord client;
  final String phone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color _getClientColor() {
    if (client.isCorporate) {
      return const Color(0xFF6F4BFF);
    }
    final hash = client.name.hashCode;
    final colors = [
      const Color(0xFF5AD8A4),
      const Color(0xFFFF9800),
      const Color(0xFF2196F3),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getInitials() {
    final words = client.name.trim().split(' ');
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words[0].isNotEmpty ? words[0][0].toUpperCase() : '?';
    }
    return '${words[0][0]}${words[words.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final clientColor = _getClientColor();
    final orderCount = (client.stats['orders'] as num?)?.toInt() ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            clientColor.withOpacity(0.3),
            const Color(0xFF1B1B2C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: clientColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      clientColor.withOpacity(0.4),
                      clientColor.withOpacity(0.2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: clientColor.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getInitials(),
                    style: TextStyle(
                      color: clientColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name and Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
            children: [
              Expanded(
                child: Text(
                            client.name,
                  style: const TextStyle(
                    color: Colors.white,
                              fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
                        // Order Count Badge
                        if (orderCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6F4BFF).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF6F4BFF).withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 12,
                                  color: Color(0xFF6F4BFF),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  orderCount.toString(),
                                  style: const TextStyle(
                                    color: Color(0xFF6F4BFF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Phone with edit
                    GestureDetector(
                      onTap: onEdit,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              phone,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit,
                            size: 14,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Action Buttons
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                tooltip: 'Delete',
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, color: Colors.white70),
                tooltip: 'Edit',
              ),
            ],
          ),
          // Tags and Corporate Badge
          if (client.tags.isNotEmpty || client.isCorporate) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Corporate Badge
                if (client.isCorporate)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6F4BFF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF6F4BFF).withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.business,
                          size: 14,
                          color: Color(0xFF6F4BFF),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Corporate',
                          style: TextStyle(
                            color: Color(0xFF6F4BFF),
                            fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
                      ],
                    ),
                  ),
                // Tags
                ...client.tags.take(5).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PrimaryContactOption {
  const _PrimaryContactOption({
    required this.label,
    required this.phone,
    this.subtitle,
  });

  final String label;
  final String phone;
  final String? subtitle;
}

class _PrimaryContactSheet extends StatelessWidget {
  const _PrimaryContactSheet({
    required this.options,
    required this.currentPhone,
  });

  final List<_PrimaryContactOption> options;
  final String currentPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999                    ),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Primary Contact',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
                      style: const TextStyle(color: Colors.white                    ),
                    ),
                  ),
                  title: Text(
                    option.label,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    option.subtitle != null && option.subtitle!.isNotEmpty
                        ? '${option.phone} • ${option.subtitle}'
                        : option.phone,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.white70)
                      : null,
                  onTap: () => Navigator.pop(context, option),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteClientSheet extends StatelessWidget {
  const _DeleteClientSheet({required this.clientName});

  final String clientName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999                    ),
              ),
            ),
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
                    borderRadius: BorderRadius.circular(14                    ),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete client'                    ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingOrdersSection extends StatefulWidget {
  const _PendingOrdersSection({required this.clientId});

  final String clientId;

  @override
  State<_PendingOrdersSection> createState() => _PendingOrdersSectionState();
}

class _PendingOrdersSectionState extends State<_PendingOrdersSection> {
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _currentOrgId;

  @override
  void initState() {
    super.initState();
    _subscribeToOrders();
  }

  Future<void> _subscribeToOrders() async {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization == null) {
      await _ordersSubscription?.cancel();
      _ordersSubscription = null;
      _currentOrgId = null;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _orders = [];
        });
      }
      return;
    }

    final orgId = organization.id;
    if (_currentOrgId == orgId && _ordersSubscription != null) {
      return;
    }

    _currentOrgId = orgId;
    final repository = context.read<PendingOrdersRepository>();

    await _ordersSubscription?.cancel();
    _ordersSubscription = repository.watchPendingOrders(orgId).listen(
      (allOrders) {
        // Filter orders by clientId
        final clientOrders = allOrders.where((order) {
          final orderClientId = order['clientId'] as String?;
          return orderClientId == widget.clientId;
        }).toList();

        if (mounted) {
          setState(() {
            _orders = clientOrders;
            _isLoading = false;
          });
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrganizationContextCubit, OrganizationContextState>(
      listener: (context, state) {
        if (state.organization != null) {
          _currentOrgId = null;
          _subscribeToOrders();
        }
      },
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6F4BFF),
              ),
            )
          : _orders.isEmpty
              ? const Center(
        child: Text(
                    'No pending orders for this client.',
          style: TextStyle(color: Colors.white54),
        ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      ..._orders.map((order) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: OrderTile(
                              order: order,
                              onTripsUpdated: () {
                                // Refresh is handled by stream
                              },
                              onDeleted: () {
                                // Refresh is handled by stream
                              },
                            ),
                          )),
                    ],
        ),
      ),
    );
  }
}


class _AnalyticsSection extends StatefulWidget {
  const _AnalyticsSection({required this.clientId});

  final String clientId;

  @override
  State<_AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<_AnalyticsSection> {
  StreamSubscription<Map<String, dynamic>?>? _ledgerSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _transactionsSubscription;
  Map<String, dynamic>? _ledger;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _currentOrgId;

  @override
  void initState() {
    super.initState();
    _subscribeToData();
  }

  Future<void> _subscribeToData() async {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization == null) {
      await _ledgerSubscription?.cancel();
      await _transactionsSubscription?.cancel();
      _ledgerSubscription = null;
      _transactionsSubscription = null;
      _currentOrgId = null;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _ledger = null;
          _transactions = [];
        });
      }
      return;
    }

    final orgId = organization.id;
    if (_currentOrgId == orgId && _ledgerSubscription != null) {
      return;
    }

    _currentOrgId = orgId;
    final repository = context.read<ClientLedgerRepository>();

    await _ledgerSubscription?.cancel();
    await _transactionsSubscription?.cancel();

    _ledgerSubscription = repository.watchClientLedger(orgId, widget.clientId).listen(
      (ledger) {
        if (mounted) {
          setState(() {
            _ledger = ledger;
            if (_transactions.isNotEmpty) {
              _isLoading = false;
            }
          });
        }
      },
      onError: (_) {
        if (mounted && _transactions.isNotEmpty) {
          setState(() => _isLoading = false);
        }
      },
    );

    _transactionsSubscription = repository.watchRecentTransactions(orgId, widget.clientId, 50).listen(
      (transactions) {
        if (mounted) {
          setState(() {
            _transactions = transactions;
            if (_ledger != null) {
              _isLoading = false;
            }
          });
        }
      },
      onError: (_) {
        if (mounted && _ledger != null) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  @override
  void dispose() {
    _ledgerSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = (timestamp as Timestamp).toDate();
      }
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrganizationContextCubit, OrganizationContextState>(
      listener: (context, state) {
        if (state.organization != null) {
          _currentOrgId = null;
          _subscribeToData();
        }
      },
      child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6F4BFF),
                ),
              )
            : _ledger == null
                ? const Center(
        child: Text(
                    'No ledger data available for this client.',
          style: TextStyle(color: Colors.white54),
        ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      _LedgerBalanceCard(
                        ledger: _ledger!,
                            formatCurrency: _formatCurrency,
                          ),
                        const SizedBox(height: 20),
                      _LedgerTable(
                        transactions: _transactions,
                                          formatCurrency: _formatCurrency,
                                          formatDate: _formatDate,
                                        ),
                                ],
        ),
      ),
    );
  }
}

/* class _IncomeBreakdownChart extends StatelessWidget {
  const _IncomeBreakdownChart({
    required this.incomeByType,
    required this.formatCurrency,
  });

  final Map<String, dynamic> incomeByType;
  final String Function(double) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final entries = incomeByType.entries.toList();
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = entries.fold<double>(
      0.0,
      (sum, entry) => sum + ((entry.value as num?)?.toDouble() ?? 0.0),
    );

    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFFE91E63),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131324),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Income Breakdown',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sections: entries.asMap().entries.map((entry) {
                        final index = entry.key;
                        final typeEntry = entry.value;
                        final amount = (typeEntry.value as num?)?.toDouble() ?? 0.0;
                        final percentage = total > 0 ? (amount / total * 100) : 0.0;

                        return PieChartSectionData(
                          value: amount,
                          title: '${percentage.toStringAsFixed(0)}%',
                          color: colors[index % colors.length],
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                ),
      ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entries.asMap().entries.map((entry) {
                      final index = entry.key;
                      final typeEntry = entry.value;
                      final amount = (typeEntry.value as num?)?.toDouble() ?? 0.0;
                      final type = typeEntry.key;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                borderRadius: BorderRadius.circular(2                    ),
                ),
      ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                type.replaceAll('_', ' ').toUpperCase(),
            style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              formatCurrency(amount),
                              style: TextStyle(
                                color: colors[index % colors.length],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(                    ),
                ),
      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStatusChart extends StatelessWidget {
  const _PaymentStatusChart({
    required this.completedAmount,
    required this.pendingAmount,
    required this.formatCurrency,
  });

  final double completedAmount;
  final double pendingAmount;
  final String Function(double) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final total = completedAmount + pendingAmount;
    if (total == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131324),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Status',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: total * 1.2,
                barTouchData: BarTouchData(
                  enabled: false,
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() == 0) {
                          return const Text(
                            'Completed',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          );
                        } else if (value.toInt() == 1) {
                          return const Text(
                            'Pending',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false                    ),
                ),
      ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: completedAmount,
                        color: const Color(0xFF4CAF50),
                        width: 40,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4                    ),
                ),
      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: pendingAmount,
                        color: Colors.orange,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4                    ),
                ),
      ),
                    ],
                  ),
                ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PaymentStatusItem(
                  label: 'Completed',
                  value: formatCurrency(completedAmount),
                  color: const Color(0xFF4CAF50                    ),
                ),
      ),
              const SizedBox(width: 12),
              Expanded(
                child: _PaymentStatusItem(
                  label: 'Pending',
                  value: formatCurrency(pendingAmount),
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentStatusItem extends StatelessWidget {
  const _PaymentStatusItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
*/

class _TransactionListItem extends StatelessWidget {
  const _TransactionListItem({
    required this.transaction,
    required this.formatCurrency,
    required this.formatDate,
  });

  final Map<String, dynamic> transaction;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;

  @override
  Widget build(BuildContext context) {
    final type = (transaction['type'] as String? ?? 'N/A').toLowerCase();
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    final transactionDate = transaction['transactionDate'];
    final metadata = transaction['metadata'] as Map<String, dynamic>? ?? {};
    final dmNumber = metadata['dmNumber'] ?? transaction['dmNumber'];

    // Calculate signed amount based on type (credit = positive, debit = negative)
    final signedAmount = type == 'credit' ? amount : -amount;
    final isPositive = signedAmount > 0;
    final color = isPositive ? Colors.orangeAccent : const Color(0xFF4CAF50);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131324),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      formatDate(transactionDate),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                    if (dmNumber != null) ...[
                      const SizedBox(width: 8),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'DM-$dmNumber',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 10,
                          fontWeight: FontWeight.w600,
                    ),
            ),
      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : '-'}${formatCurrency(signedAmount.abs())}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerTable extends StatelessWidget {
  const _LedgerTable({
    required this.transactions,
    required this.formatCurrency,
    required this.formatDate,
  });

  final List<Map<String, dynamic>> transactions;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;

  @override
  Widget build(BuildContext context) {
    // Show all transactions (status field removed, transactions are deleted when cancelled)
    final visible = transactions;
    if (visible.isEmpty) {
      return const Text(
        'No transactions found.',
        style: TextStyle(color: Colors.white54),
      );
    }

    // Sort asc by transactionDate
    visible.sort((a, b) {
      final aDate = a['transactionDate'];
      final bDate = b['transactionDate'];
      try {
        final ad = aDate is Timestamp ? aDate.toDate() : (aDate as DateTime);
        final bd = bDate is Timestamp ? bDate.toDate() : (bDate as DateTime);
        return ad.compareTo(bd);
      } catch (_) {
        return 0;
      }
    });

    // Group transactions by DM number (cumulative amounts)
    // If no DM number, show category instead
    final List<_LedgerRowModel> rows = [];
    double running = 0;

    int i = 0;
    while (i < visible.length) {
      final tx = visible[i];
      final type = (tx['type'] as String? ?? '').toLowerCase();
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final metadata = tx['metadata'] as Map<String, dynamic>? ?? {};
      final dmNumber = metadata['dmNumber'] ?? tx['dmNumber'];
      final category = tx['category'] as String?;
      final date = tx['transactionDate'];

      // Group all transactions with the same DM number
      if (dmNumber != null) {
        double totalCredit = 0;
        double totalDebit = 0;
        dynamic earliestDate = date;
        final List<_PaymentPart> parts = [];
        int j = i;
        
        while (j < visible.length) {
          final next = visible[j];
          final nMeta = next['metadata'] as Map<String, dynamic>? ?? {};
          final nDm = nMeta['dmNumber'] ?? next['dmNumber'];
          
          // Stop if DM number doesn't match
          if (nDm != dmNumber) break;
          
          final nt = (next['type'] as String? ?? '').toLowerCase();
          final nAmt = (next['amount'] as num?)?.toDouble() ?? 0.0;
          final nDate = next['transactionDate'];
          
          // Track earliest date
          try {
            final currentDate = earliestDate is Timestamp ? earliestDate.toDate() : (earliestDate as DateTime);
            final nextDate = nDate is Timestamp ? nDate.toDate() : (nDate as DateTime);
            if (nextDate.isBefore(currentDate)) {
              earliestDate = nDate;
            }
          } catch (_) {}
          
          // Calculate credit/debit
          if (nt == 'credit') {
            totalCredit += nAmt;
          } else if (nt == 'payment' || nt == 'debit') {
            totalDebit += nAmt;
            if (nt == 'payment') {
              final acctType = (next['paymentAccountType'] as String?) ?? '';
              parts.add(_PaymentPart(amount: nAmt, accountType: acctType));
            }
          } else if (nt == 'refund' || nt == 'advance') {
            totalDebit += nAmt;
          } else {
            // For other types, treat as credit if positive
            totalCredit += nAmt;
          }
          
          j++;
        }
        
        final delta = totalCredit - totalDebit;
        running += delta;
        
        rows.add(_LedgerRowModel(
          date: earliestDate,
          dmNumber: dmNumber,
          credit: totalCredit,
          debit: totalDebit,
          balanceAfter: running,
          paymentParts: parts,
        ));
        
        i = j;
      } else {
        // No DM number - show as individual transaction with category
        double delta = 0;
        switch (type) {
          case 'credit':
            delta = amount;
            break;
          case 'payment':
          case 'advance':
          case 'refund':
          case 'debit':
            delta = -amount;
            break;
          case 'adjustment':
            delta = amount;
            break;
          default:
            delta = amount;
        }
        running += delta;
        
        rows.add(_LedgerRowModel(
          date: date,
          dmNumber: null,
          credit: delta > 0 ? delta : 0,
          debit: delta < 0 ? -delta : 0,
          balanceAfter: running,
          category: category, // Store category for display
        ));
        i++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ledger',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131324),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          ),
          child: Column(
            children: [
              _LedgerTableHeader(),
              const Divider(height: 1, color: Colors.white12),
              ...rows.map((r) => _LedgerTableRow(
                    row: r,
                    formatCurrency: formatCurrency,
                    formatDate: formatDate,
                  )),
            ],
          ),
        ),
      ],
    );
  }

}

class _LedgerRowModel {
  _LedgerRowModel({
    required this.date,
    required this.dmNumber,
    required this.credit,
    required this.debit,
    required this.balanceAfter,
    this.paymentParts = const [],
    this.category,
  });

  final dynamic date;
  final dynamic dmNumber;
  final double credit;
  final double debit;
  final double balanceAfter;
  final List<_PaymentPart> paymentParts;
  final String? category; // Category when DM number is not available
}

// Helper function to format category name (capitalize and add spaces)
String _formatCategoryName(String? category) {
  if (category == null || category.isEmpty) return '';
  // Convert camelCase to Title Case with spaces
  // e.g., "clientCredit" -> "Client Credit"
  return category
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .split(' ')
      .map((word) => word.isEmpty
          ? ''
          : word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ')
      .trim();
}

class _PaymentPart {
  _PaymentPart({required this.amount, required this.accountType});
  final double amount;
  final String accountType;
}

class _LedgerTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text('Date', style: TextStyle(color: Colors.white70, fontSize: 11))),
          SizedBox(width: 70, child: Text('DM No.', style: TextStyle(color: Colors.white70, fontSize: 11))),
          Expanded(child: Text('Credit', style: TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.right)),
          Expanded(child: Text('Debit', style: TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.right)),
          Expanded(child: Text('Balance', style: TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _LedgerTableRow extends StatelessWidget {
  const _LedgerTableRow({
    required this.row,
    required this.formatCurrency,
    required this.formatDate,
  });

  final _LedgerRowModel row;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;

  Color _accountColor(String type) {
    switch (type.toLowerCase()) {
      case 'upi':
        return Colors.blueAccent;
      case 'bank':
        return Colors.purpleAccent;
      case 'cash':
        return Colors.greenAccent;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              formatDate(row.date),
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          SizedBox(
            width: 70,
            child: row.dmNumber != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'DM-${row.dmNumber}',
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : row.category != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatCategoryName(row.category),
                          style: const TextStyle(
                            color: Colors.purpleAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : const Text(
                        '-',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
          ),
          Expanded(
            child: Text(
              row.credit > 0 ? formatCurrency(row.credit) : '-',
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: row.debit > 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCurrency(row.debit),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        textAlign: TextAlign.right,
                      ),
                      if (row.paymentParts.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          alignment: WrapAlignment.end,
                          children: row.paymentParts
                              .map((p) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _accountColor(p.accountType).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      formatCurrency(p.amount),
                                      style: TextStyle(
                                        color: _accountColor(p.accountType),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                    ],
                  )
                : const Text('-', style: TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.right),
          ),
          Expanded(
            child: Text(
              formatCurrency(row.balanceAfter),
              style: TextStyle(
                color: row.balanceAfter >= 0 ? Colors.orangeAccent : Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerBalanceCard extends StatelessWidget {
  const _LedgerBalanceCard({
    required this.ledger,
    required this.formatCurrency,
  });

  final Map<String, dynamic> ledger;
  final String Function(double) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final currentBalance = (ledger['currentBalance'] as num?)?.toDouble() ?? 0.0;
    final totalIncome = (ledger['totalIncome'] as num?)?.toDouble() ?? 0.0;
    final totalReceivables = (ledger['totalReceivables'] as num?)?.toDouble() ?? 0.0;

    final isReceivable = currentBalance > 0;
    final isPayable = currentBalance < 0;

    Color badgeColor() {
      if (isReceivable) return Colors.orangeAccent;
      if (isPayable) return Colors.greenAccent;
      return Colors.white70;
    }

    String badgeText() {
      if (isReceivable) return 'Client owes us';
      if (isPayable) return 'We owe client';
      return 'Settled';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131324),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ledger',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor().withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor().withOpacity(0.6)),
                ),
                child: Text(
                  badgeText(),
                  style: TextStyle(
                    color: badgeColor(),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LedgerRow(label: 'Current Balance', value: formatCurrency(currentBalance.abs())),
          _LedgerRow(label: 'Total Income', value: formatCurrency(totalIncome)),
          _LedgerRow(label: 'Total Receivables', value: formatCurrency(totalReceivables)),
          if (ledger['dmNumbers'] != null &&
              (ledger['dmNumbers'] as List).isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'DM Numbers',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: (ledger['dmNumbers'] as List)
                  .map((dm) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Text(
                          'DM-$dm',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6F4BFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                ),
      ),
    );
  }
}


