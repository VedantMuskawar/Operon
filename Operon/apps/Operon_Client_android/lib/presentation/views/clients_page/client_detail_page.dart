import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:dash_mobile/data/repositories/pending_orders_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/data/services/dm_print_service.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/dm_print_dialog.dart';
import 'package:dash_mobile/presentation/widgets/order_tile.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
// ignore_for_file: deprecated_member_use, unused_element, no_leading_underscores_for_local_identifiers, avoid_types_as_parameter_names

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
      backgroundColor: AuthColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.paddingXL,
                  vertical: AppSpacing.paddingMD),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close, color: AuthColors.textSub),
                  ),
                  const SizedBox(width: AppSpacing.paddingSM),
                  Expanded(
                    child: Text(
                      'Client Details',
                      style: AppTypography.withColor(
                          AppTypography.h2, AuthColors.textMain),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.avatarSM),
                ],
              ),
            ),
            // Client Header Info
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL),
              child: _ClientHeader(
                client: client,
                phone: _primaryPhone,
                onEdit: _selectPrimaryContact,
                onDelete: _confirmDelete,
              ),
            ),
            const SizedBox(height: AppSpacing.paddingLG),
            // Tab Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL),
              child: Container(
                decoration: BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  border: Border.all(
                    color: AuthColors.textMainWithOpacity(0.1),
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
                    Expanded(
                      child: _TabButton(
                        label: 'DMs',
                        isSelected: _selectedTabIndex == 2,
                        onTap: () => setState(() => _selectedTabIndex = 2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.paddingLG),
            // Content based on selected tab
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _PendingOrdersSection(clientId: widget.client.id),
                  _AnalyticsSection(clientId: widget.client.id),
                  _ClientDMsSection(clientId: widget.client.id),
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
      backgroundColor: AuthColors.transparent,
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
      backgroundColor: AuthColors.transparent,
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
      return AuthColors.secondary; // Closest to 0xFF6F4BFF
    }
    final hash = client.name.hashCode;
    final colors = [
      AuthColors.successVariant, // 0xFF5AD8A4
      AuthColors.warning, // 0xFFFF9800
      AuthColors.info, // 0xFF2196F3
      AuthColors.error, // 0xFFFF5252 (closest to 0xFFE91E63)
      AuthColors.secondary, // 0xFF9C27B0
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
      padding: const EdgeInsets.all(AppSpacing.paddingXL),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXXL),
        gradient: LinearGradient(
          colors: [
            clientColor.withValues(alpha: 0.3),
            AuthColors.backgroundAlt,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: clientColor.withValues(alpha: 0.2),
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
                      clientColor.withValues(alpha: 0.4),
                      clientColor.withValues(alpha: 0.2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: clientColor.withValues(alpha: 0.3),
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
              const SizedBox(width: AppSpacing.paddingLG),
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
                            style: AppTypography.withColor(
                              AppTypography.withWeight(
                                  AppTypography.h1, FontWeight.w700),
                              AuthColors.textMain,
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
                              color: AuthColors.secondary.withValues(alpha: 0.2),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSM),
                              border: Border.all(
                                color: AuthColors.secondary.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 12,
                                  color: AuthColors.secondary,
                                ),
                                const SizedBox(width: AppSpacing.paddingXS),
                                Text(
                                  orderCount.toString(),
                                  style: const TextStyle(
                                    color: AuthColors.secondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.paddingSM),
                    // Phone with edit
                    GestureDetector(
                      onTap: onEdit,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: AuthColors.textMainWithOpacity(0.7),
                          ),
                          const SizedBox(width: AppSpacing.gapSM),
                          Flexible(
                            child: Text(
                              phone,
                              style: AppTypography.withColor(
                                AppTypography.withWeight(
                                    AppTypography.body, FontWeight.w600),
                                AuthColors.textMainWithOpacity(0.8),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.paddingXS),
                          Icon(
                            Icons.edit,
                            size: 14,
                            color: AuthColors.textMainWithOpacity(0.5),
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
                icon:
                    const Icon(Icons.delete_outline, color: AuthColors.textSub),
                tooltip: 'Delete',
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, color: AuthColors.textSub),
                tooltip: 'Edit',
              ),
            ],
          ),
          // Tags and Corporate Badge
          if (client.tags.isNotEmpty || client.isCorporate) ...[
            const SizedBox(height: AppSpacing.paddingMD),
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
                      color: AuthColors.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                      border: Border.all(
                        color: AuthColors.secondary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.business,
                          size: 14,
                          color: AuthColors.secondary,
                        ),
                        SizedBox(width: AppSpacing.paddingXS),
                        Text(
                          'Corporate',
                          style: TextStyle(
                            color: AuthColors.secondary,
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
                      color: AuthColors.textMainWithOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                      border: Border.all(
                        color: AuthColors.textMainWithOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: AuthColors.textMainWithOpacity(0.8),
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
        color: AuthColors.backgroundAlt,
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
              margin: const EdgeInsets.only(bottom: AppSpacing.paddingLG),
              decoration: BoxDecoration(
                color: AuthColors.textMainWithOpacity(0.24),
                borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Primary Contact',
                style: AppTypography.withColor(
                    AppTypography.h3, AuthColors.textMain),
              ),
            ),
            const SizedBox(height: AppSpacing.paddingMD),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.paddingSM),
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = option.phone == currentPhone;
                return ListTile(
                  tileColor: AuthColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                  ),
                  leading: CircleAvatar(
                    backgroundColor:
                        isSelected ? AuthColors.secondary : AuthColors.surface,
                    child: Text(
                      option.label.isNotEmpty ? option.label[0] : '?',
                      style: const TextStyle(color: AuthColors.textMain),
                    ),
                  ),
                  title: Text(
                    option.label,
                    style: const TextStyle(color: AuthColors.textMain),
                  ),
                  subtitle: Text(
                    option.subtitle != null && option.subtitle!.isNotEmpty
                        ? '${option.phone} • ${option.subtitle}'
                        : option.phone,
                    style: AppTypography.withColor(
                        AppTypography.caption, AuthColors.textSub),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AuthColors.textSub)
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
        color: AuthColors.backgroundAlt,
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
              margin: const EdgeInsets.only(bottom: AppSpacing.paddingLG),
              decoration: BoxDecoration(
                color: AuthColors.textMainWithOpacity(0.24),
                borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
              ),
            ),
            const Text(
              'Delete client',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.gapSM),
            Text(
              'This will permanently remove $clientName and all related analytics. This action cannot be undone.',
              style: const TextStyle(
                color: AuthColors.textSub,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.paddingXXL),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AuthColors.error,
                  foregroundColor: AuthColors.textMain,
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.paddingLG),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete client'),
              ),
            ),
            const SizedBox(height: AppSpacing.paddingMD),
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
    _ordersSubscription = repository
        .watchPendingOrdersForClient(orgId, widget.clientId)
        .listen(
      (clientOrders) {
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
                color: AuthColors.secondary,
              ),
            )
          : _orders.isEmpty
              ? const Center(
                  child: Text(
                    'No pending orders for this client.',
                    style: TextStyle(color: AuthColors.textSub),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      ..._orders.map((order) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.paddingMD),
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

    _ledgerSubscription =
        repository.watchClientLedger(orgId, widget.clientId).listen(
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

    _transactionsSubscription =
        repository.watchRecentTransactions(orgId, widget.clientId, 50).listen(
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
                color: AuthColors.primary,
              ),
            )
          : _ledger == null
              ? const Center(
                  child: Text(
                    'No ledger data available for this client.',
                    style: TextStyle(color: AuthColors.textSub),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: _LedgerTable(
                    openingBalance:
                        (_ledger!['openingBalance'] as num?)?.toDouble() ?? 0.0,
                    transactions: _transactions,
                    formatCurrency: _formatCurrency,
                    formatDate: _formatDate,
                  ),
                ),
    );
  }
}

class _ClientDMsSection extends StatelessWidget {
  const _ClientDMsSection({required this.clientId});

  final String clientId;

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    try {
      DateTime dateTime;
      if (date is Timestamp) {
        dateTime = date.toDate();
      } else if (date is DateTime) {
        dateTime = date;
      } else if (date is Map && date.containsKey('_seconds')) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(
          (date['_seconds'] as int) * 1000,
        );
      } else {
        return '—';
      }
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (_) {
      return '—';
    }
  }

  Future<void> _openPrintDialog(
    BuildContext context,
    String organizationId,
    Map<String, dynamic> dm,
  ) async {
    final printService = context.read<DmPrintService>();
    final dmNumber = dm['dmNumber'] as int? ?? 0;
    final dmData = await printService.fetchDmByNumberOrId(
      organizationId: organizationId,
      dmNumber: dmNumber,
      dmId: dm['dmId'] as String?,
      tripData: null,
    );
    if (dmData == null || !context.mounted) return;
    await DmPrintDialog.show(
      context: context,
      dmPrintService: printService,
      organizationId: organizationId,
      dmData: dmData,
      dmNumber: dmNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrganizationContextCubit>().state.organization;
    if (org == null) {
      return const Center(
        child: Text(
          'Select an organization to view DMs.',
          style: TextStyle(color: AuthColors.textSub),
        ),
      );
    }
    final dmRepo = context.read<DeliveryMemoRepository>();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: dmRepo.watchDeliveryMemosByClientId(
        organizationId: org.id,
        clientId: clientId,
        status: 'active',
        limit: 100,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AuthColors.primary));
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const Center(
            child: Text(
              'No delivery memos for this client.',
              style: TextStyle(color: AuthColors.textSub),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final dm = list[index];
            final dmNumber = dm['dmNumber'] as int?;
            final clientName = dm['clientName'] as String? ?? '—';
            final vehicleNumber = dm['vehicleNumber'] as String? ?? '—';
            final scheduledDate = dm['scheduledDate'];
            final tripPricing = dm['tripPricing'] as Map<String, dynamic>?;
            final total = tripPricing != null
                ? (tripPricing['total'] as num?)?.toDouble() ?? 0.0
                : 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
              color: AuthColors.backgroundAlt,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                side: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.paddingLG,
                    vertical: AppSpacing.paddingSM),
                title: Row(
                  children: [
                    Text(
                      dmNumber != null ? 'DM-$dmNumber' : 'DM',
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.print_outlined),
                      onPressed: () => _openPrintDialog(context, org.id, dm),
                      tooltip: 'Print DM',
                      style: IconButton.styleFrom(
                          foregroundColor: AuthColors.textSub),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.paddingXS),
                    Text(
                      clientName,
                      style: AppTypography.withColor(AppTypography.body,
                          AuthColors.textMainWithOpacity(0.8)),
                    ),
                    Text(
                      '${_formatDate(scheduledDate)} · $vehicleNumber',
                      style: AppTypography.withColor(
                          AppTypography.labelSmall, AuthColors.textSub),
                    ),
                    if (total > 0)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: AppSpacing.paddingXS),
                        child: Text(
                          '₹${total.toStringAsFixed(2)}',
                          style: AppTypography.withColor(
                            AppTypography.withWeight(
                                AppTypography.bodySmall, FontWeight.w600),
                            AuthColors.successVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
      AuthColors.success,
      AuthColors.info,
      AuthColors.warning,
      AuthColors.secondary,
      AuthColors.error,
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(
                      color: AuthColors.textMainWithOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Income Breakdown',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingLG),
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
                            color: AuthColors.textMain,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                ),
      ),
                const SizedBox(width: AppSpacing.paddingLG),
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
                        padding: const EdgeInsets.only(bottom: AppSpacing.paddingSM),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                borderRadius: BorderRadius.circular(AppSpacing.paddingXS),
                ),
      ),
                            const SizedBox(width: AppSpacing.paddingSM),
                            Expanded(
                              child: Text(
                                type.replaceAll('_', ' ').toUpperCase(),
            style: const TextStyle(
                                  color: AuthColors.textSub,
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
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(
                      color: AuthColors.textMainWithOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Status',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingLG),
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
                              color: AuthColors.textSub,
                              fontSize: 11,
                            ),
                          );
                        } else if (value.toInt() == 1) {
                          return const Text(
                            'Pending',
                            style: TextStyle(
                              color: AuthColors.textSub,
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
                        color: AuthColors.success,
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
                        color: AuthColors.warning,
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
          const SizedBox(height: AppSpacing.paddingMD),
          Row(
            children: [
              Expanded(
                child: _PaymentStatusItem(
                  label: 'Completed',
                  value: formatCurrency(completedAmount),
                  color: AuthColors.success,
                ),
      ),
              const SizedBox(width: AppSpacing.paddingMD),
              Expanded(
                child: _PaymentStatusItem(
                  label: 'Pending',
                  value: formatCurrency(pendingAmount),
                  color: AuthColors.warning,
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
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
            decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingXS),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.gapSM),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AuthColors.textSub, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AuthColors.textMain,
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
    final color = isPositive ? AuthColors.warning : AuthColors.success;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(
          color: AuthColors.textMainWithOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            ),
            child: Icon(
              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingXS),
                Row(
                  children: [
                    Text(
                      formatDate(transactionDate),
                      style: const TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 11,
                      ),
                    ),
                    if (dmNumber != null) ...[
                      const SizedBox(width: AppSpacing.paddingSM),
                      const SizedBox(width: AppSpacing.paddingSM),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.gapSM,
                            vertical: AppSpacing.paddingXS / 2),
                        decoration: BoxDecoration(
                          color: AuthColors.info.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusXS),
                        ),
                        child: Text(
                          'DM-$dmNumber',
                          style: const TextStyle(
                            color: AuthColors.info,
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
    required this.openingBalance,
    required this.transactions,
    required this.formatCurrency,
    required this.formatDate,
  });

  final double openingBalance;
  final List<Map<String, dynamic>> transactions;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;

  @override
  Widget build(BuildContext context) {
    final visible = List<Map<String, dynamic>>.from(transactions);
    if (visible.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ledger',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          const Text(
            'No transactions found.',
            style: TextStyle(color: AuthColors.textSub),
          ),
          const SizedBox(height: AppSpacing.paddingXL),
          _LedgerSummaryFooter(
            openingBalance: openingBalance,
            totalDebit: 0,
            totalCredit: 0,
            formatCurrency: formatCurrency,
          ),
        ],
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
    double running = openingBalance;

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
            final currentDate = earliestDate is Timestamp
                ? earliestDate.toDate()
                : (earliestDate as DateTime);
            final nextDate =
                nDate is Timestamp ? nDate.toDate() : (nDate as DateTime);
            if (nextDate.isBefore(currentDate)) {
              earliestDate = nDate;
            }
          } catch (_) {}

          // Calculate credit/debit
          if (nt == 'credit') {
            totalCredit += nAmt;
          } else {
            totalDebit += nAmt;
            if (nt == 'payment') {
              final acctType = (next['paymentAccountType'] as String?) ?? '';
              parts.add(_PaymentPart(amount: nAmt, accountType: acctType));
            }
          }

          j++;
        }

        final delta = totalCredit - totalDebit;
        running += delta;

        final firstDesc = (visible[i]['description'] as String?)?.trim();
        rows.add(_LedgerRowModel(
          date: earliestDate,
          dmNumber: dmNumber,
          credit: totalCredit,
          debit: totalDebit,
          balanceAfter: running,
          type: 'Order',
          remarks:
              (firstDesc != null && firstDesc.isNotEmpty) ? firstDesc : '-',
          paymentParts: parts,
        ));

        i = j;
      } else {
        // No DM number - show as individual transaction with category
        final isCredit = type == 'credit';
        final delta = isCredit ? amount : -amount;
        running += delta;

        final desc = (tx['description'] as String?)?.trim();
        rows.add(_LedgerRowModel(
          date: date,
          dmNumber: null,
          credit: isCredit ? amount : 0,
          debit: isCredit ? 0 : amount,
          balanceAfter: running,
          type: _formatCategoryName(category),
          remarks: (desc != null && desc.isNotEmpty) ? desc : '-',
          category: category,
        ));
        i++;
      }
    }

    final totalDebit = rows.fold<double>(0, (s, r) => s + r.debit);
    final totalCredit = rows.fold<double>(0, (s, r) => s + r.credit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ledger',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.paddingMD),
        Container(
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            border: Border.all(
                color: AuthColors.textMainWithOpacity(0.1), width: 1),
          ),
          child: Column(
            children: [
              _LedgerTableHeader(),
              Divider(height: 1, color: AuthColors.textMain.withValues(alpha: 0.12)),
              ...rows.map((r) => _LedgerTableRow(
                    row: r,
                    formatCurrency: formatCurrency,
                    formatDate: formatDate,
                  )),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.paddingXL),
        _LedgerSummaryFooter(
          openingBalance: openingBalance,
          totalDebit: totalDebit,
          totalCredit: totalCredit,
          formatCurrency: formatCurrency,
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
    required this.type,
    required this.remarks,
    this.paymentParts = const [],
    this.category,
  });

  final dynamic date;
  final dynamic dmNumber;
  final double credit;
  final double debit;
  final double balanceAfter;
  final String type;
  final String remarks;
  final List<_PaymentPart> paymentParts;
  final String? category;
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
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingMD, vertical: AppSpacing.paddingMD),
      child: Row(
        children: [
          Expanded(
              flex: 1,
              child: Text('Date',
                  style: AppTypography.withColor(
                      AppTypography.captionSmall, AuthColors.textSub),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('Reference',
                  style: AppTypography.withColor(
                      AppTypography.captionSmall, AuthColors.textSub),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('Debit',
                  style: AppTypography.withColor(
                      AppTypography.captionSmall, AuthColors.textSub),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('Credit',
                  style: AppTypography.withColor(
                      AppTypography.captionSmall, AuthColors.textSub),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('Balance',
                  style: AppTypography.withColor(
                      AppTypography.captionSmall, AuthColors.textSub),
                  textAlign: TextAlign.center)),
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
        return AuthColors.info;
      case 'bank':
        return AuthColors.secondary;
      case 'cash':
        return AuthColors.success;
      default:
        return AuthColors.textSub;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingMD, vertical: AppSpacing.paddingSM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              formatDate(row.date),
              style: AppTypography.withColor(
                  AppTypography.captionSmall, AuthColors.textMain),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: row.dmNumber != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.gapSM,
                          vertical: AppSpacing.paddingXS / 2),
                      decoration: BoxDecoration(
                        color: AuthColors.info.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusXS),
                      ),
                      child: Text(
                        'DM-${row.dmNumber}',
                        style: const TextStyle(
                          color: AuthColors.info,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : row.category != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.gapSM,
                              vertical: AppSpacing.paddingXS / 2),
                          decoration: BoxDecoration(
                            color: AuthColors.secondary.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusXS),
                          ),
                          child: Text(
                            _formatCategoryName(row.category!),
                            style: const TextStyle(
                              color: AuthColors.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : const Text(
                          '-',
                          style: TextStyle(
                              color: AuthColors.textSub, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
            ),
          ),
          Expanded(
            flex: 1,
            child: row.debit > 0
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        formatCurrency(row.debit),
                        style: AppTypography.withColor(
                            AppTypography.captionSmall, AuthColors.textMain),
                        textAlign: TextAlign.center,
                      ),
                      if (row.paymentParts.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: row.paymentParts
                              .map((p) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.gapSM,
                                        vertical: AppSpacing.paddingXS / 2),
                                    decoration: BoxDecoration(
                                      color: _accountColor(p.accountType)
                                        .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusXS),
                                    ),
                                    child: Text(
                                      formatCurrency(p.amount),
                                      style: TextStyle(
                                        color: _accountColor(p.accountType),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ))
                              .toList(),
                        ),
                    ],
                  )
                : Text('-',
                    style: AppTypography.withColor(
                        AppTypography.captionSmall, AuthColors.textSub),
                    textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 1,
            child: Text(
              row.credit > 0 ? formatCurrency(row.credit) : '-',
              style: AppTypography.withColor(
                  AppTypography.captionSmall, AuthColors.textMain),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              formatCurrency(row.balanceAfter),
              style: TextStyle(
                color: row.balanceAfter >= 0
                    ? AuthColors.warning
                    : AuthColors.success,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerSummaryFooter extends StatelessWidget {
  const _LedgerSummaryFooter({
    required this.openingBalance,
    required this.totalDebit,
    required this.totalCredit,
    required this.formatCurrency,
  });

  final double openingBalance;
  final double totalDebit;
  final double totalCredit;
  final String Function(double) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final currentBalance = openingBalance + totalCredit - totalDebit;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingMD, vertical: AppSpacing.paddingMD),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border:
            Border.all(color: AuthColors.textMainWithOpacity(0.1), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Opening Balance',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.paddingXS),
              Text(formatCurrency(openingBalance),
                  style: AppTypography.withColor(
                      AppTypography.withWeight(
                          AppTypography.bodySmall, FontWeight.w600),
                      AuthColors.info),
                  textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Debit',
                  style: AppTypography.withColor(
                      AppTypography.captionSmall, AuthColors.textSub),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.paddingXS),
              Text(formatCurrency(totalDebit),
                  style: AppTypography.withColor(
                      AppTypography.withWeight(
                          AppTypography.bodySmall, FontWeight.w600),
                      AuthColors.info),
                  textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Total Credit',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.paddingXS),
              Text(formatCurrency(totalCredit),
                  style: AppTypography.withColor(
                      AppTypography.withWeight(
                          AppTypography.bodySmall, FontWeight.w600),
                      AuthColors.info),
                  textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Current Balance',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.paddingXS),
              Text(formatCurrency(currentBalance),
                  style: AppTypography.withColor(
                      AppTypography.withWeight(
                          AppTypography.bodySmall, FontWeight.w600),
                      AuthColors.success),
                  textAlign: TextAlign.center),
            ],
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
      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingMD),
        decoration: BoxDecoration(
          color: isSelected ? AuthColors.secondary : AuthColors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? AuthColors.textMain
                : AuthColors.textMainWithOpacity(0.7),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
