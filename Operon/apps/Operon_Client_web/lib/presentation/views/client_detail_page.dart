import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/data/repositories/pending_orders_repository.dart';
import 'package:dash_web/domain/entities/client.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/pending_order_tile.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ClientDetailPage extends StatefulWidget {
  const ClientDetailPage({
    super.key,
    required this.client,
  });

  final Client client;

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  late String _primaryPhone;
  late List<_PrimaryContactOption> _primaryOptions;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _primaryPhone = widget.client.primaryPhone ??
        (widget.client.phones.isNotEmpty
            ? (widget.client.phones.first['e164'] as String?) ?? '-'
            : '-');
    _primaryOptions = _buildPrimaryOptions(widget.client);
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    return SectionWorkspaceLayout(
      panelTitle: 'Client Details',
      currentIndex: 0,
      onNavTap: (value) => context.go('/home?section=$value'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Client Header Info
          _ClientHeader(
            name: client.name,
            phone: _primaryPhone,
            onEdit: _selectPrimaryContact,
            onDelete: _confirmDelete,
                ),
                const SizedBox(height: 16),
                // Tab Bar
          Container(
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
                const SizedBox(height: 16),
                // Content based on selected tab
                IndexedStack(
                  index: _selectedTabIndex,
                  children: [
                OverviewSection(clientId: widget.client.id),
                PendingOrdersSection(clientId: widget.client.id),
                AnalyticsSection(clientId: widget.client.id),
                  ],
                ),
              ],
            ),
    );
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

    final selected = await showDialog<_PrimaryContactOption>(
      context: context,
      builder: (context) => _PrimaryContactDialog(
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
      final repository = context.read<ClientsRepository>();
      await repository.updatePrimaryPhone(
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteClientDialog(
        clientName: widget.client.name,
      ),
    );

    if (confirm != true) return;

    try {
      final repository = context.read<ClientsRepository>();
      await repository.deleteClient(widget.client.id);
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
    required this.name,
    required this.phone,
    required this.onEdit,
    required this.onDelete,
  });

  final String name;
  final String phone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF352E65), Color(0xFF1B1B2C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                  name,
                        style: const TextStyle(
                          color: Colors.white,
                    fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 6),
                            Text(
            'Primary: $phone',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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

class OverviewSection extends StatefulWidget {
  const OverviewSection({super.key, required this.clientId});

  final String clientId;

  @override
  State<OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends State<OverviewSection> {
  StreamSubscription<Map<String, dynamic>?>? _ledgerSubscription;
  Map<String, dynamic>? _ledger;
  bool _isLoading = true;
  String? _currentOrgId;

  @override
  void initState() {
    super.initState();
    _subscribeToLedger();
  }

  Future<void> _subscribeToLedger() async {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization == null) {
      await _ledgerSubscription?.cancel();
      _ledgerSubscription = null;
      _currentOrgId = null;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _ledger = null;
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
    _ledgerSubscription = repository.watchClientLedger(orgId, widget.clientId).listen(
      (ledger) {
        if (mounted) {
          setState(() {
            _ledger = ledger;
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
    _ledgerSubscription?.cancel();
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
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year.toString().substring(2)}';
      }
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
          _subscribeToLedger();
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
                      'No financial data available for this client.',
          style: TextStyle(color: Colors.white54),
        ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Balance Card
                        _BalanceCard(
                          currentBalance: (_ledger!['currentBalance'] as num?)?.toDouble() ?? 0.0,
                          openingBalance: (_ledger!['openingBalance'] as num?)?.toDouble() ?? 0.0,
                        ),
                        const SizedBox(height: 16),
                        // Financial Summary Cards
                        Row(
          children: [
                            Expanded(
                              child: _SummaryCard(
                                label: 'Total Income',
                                value: _formatCurrency(
                                  (_ledger!['totalIncome'] as num?)?.toDouble() ?? 0.0,
                                ),
                                color: const Color(0xFF4CAF50),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryCard(
                                label: 'Total Receivables',
                                value: _formatCurrency(
                                  (_ledger!['totalReceivables'] as num?)?.toDouble() ?? 0.0,
                                ),
                                color: const Color(0xFFEF5350),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _SummaryCard(
                          label: 'Net Balance',
                          value: _formatCurrency(
                            (_ledger!['netBalance'] as num?)?.toDouble() ??
                                (_ledger!['currentBalance'] as num?)?.toDouble() ?? 0.0,
                          ),
                          color: const Color(0xFF6F4BFF),
                        ),
                        const SizedBox(height: 16),
                        // Transaction Summary
                        _TransactionSummaryCard(
                          total: _ledger!['transactionCount'] as int? ?? 0,
                        ),
                        const SizedBox(height: 16),
                        // Recent Activity
                        if (_ledger!['lastTransactionDate'] != null)
                          _RecentActivityCard(
                            lastTransactionDate: _ledger!['lastTransactionDate'],
                            lastTransactionAmount: (_ledger!['lastTransactionAmount'] as num?)?.toDouble() ?? 0.0,
                            formatDate: _formatDate,
                            formatCurrency: _formatCurrency,
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.currentBalance,
    required this.openingBalance,
  });

  final double currentBalance;
  final double openingBalance;

  @override
  Widget build(BuildContext context) {
    final change = currentBalance - openingBalance;
    final isPositive = change >= 0;

    String formatCurrency(double amount) {
      return '₹${amount.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          )}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
          colors: isPositive
              ? [const Color(0xFF4CAF50).withOpacity(0.2), const Color(0xFF4CAF50).withOpacity(0.05)]
              : [const Color(0xFFEF5350).withOpacity(0.2), const Color(0xFFEF5350).withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(16),
              border: Border.all(
          color: (isPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350)).withOpacity(0.3),
          width: 1,
        ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    const Text(
            'Current Balance',
                      style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatCurrency(currentBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                        size: 16,
                color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
              ),
              const SizedBox(width: 4),
              Text(
                '${isPositive ? '+' : ''}${formatCurrency(change.abs())} from opening',
                        style: TextStyle(
                  color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
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
              fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionSummaryCard extends StatelessWidget {
  const _TransactionSummaryCard({
    required this.total,
  });

  final int total;

  @override
  Widget build(BuildContext context) {
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
            'Transactions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
                Row(
                  children: [
              Expanded(
                child: _TransactionStatItem(
                  label: 'Total Transactions',
                  value: total.toString(),
                  color: Colors.white70,
                ),
              ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _TransactionStatItem extends StatelessWidget {
  const _TransactionStatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(
              label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
              value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            ),
          ),
        ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.lastTransactionDate,
    required this.lastTransactionAmount,
    required this.formatDate,
    required this.formatCurrency,
  });

  final dynamic lastTransactionDate;
  final double lastTransactionAmount;
  final String Function(dynamic) formatDate;
  final String Function(double) formatCurrency;

  @override
  Widget build(BuildContext context) {
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
            'Recent Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            ),
            const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.history,
                size: 16,
                color: Colors.white60,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Text(
                      'Last transaction: ${formatDate(lastTransactionDate)}',
                      style: const TextStyle(
                        color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
                      formatCurrency(lastTransactionAmount),
              style: const TextStyle(
                color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PendingOrdersSection extends StatefulWidget {
  const PendingOrdersSection({super.key, required this.clientId});

  final String clientId;

  @override
  State<PendingOrdersSection> createState() => _PendingOrdersSectionState();
}

class _PendingOrdersSectionState extends State<PendingOrdersSection> {
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
                            child: PendingOrderTile(
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


class AnalyticsSection extends StatefulWidget {
  const AnalyticsSection({super.key, required this.clientId});

  final String clientId;

  @override
  State<AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<AnalyticsSection> {
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
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: const Center(
                      child: Text(
                        'No ledger data available for this client.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
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
