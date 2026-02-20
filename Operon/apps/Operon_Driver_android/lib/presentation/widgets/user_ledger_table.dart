import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';
import 'package:operon_driver_android/data/repositories/users_repository.dart';

/// Compact ledger table widget showing current user's employee transactions
class UserLedgerTable extends StatelessWidget {
  const UserLedgerTable({super.key});

  _LedgerSelectionConfig _resolveLedgerSelectionConfig(
    Map<String, dynamic> userData,
  ) {
    final legacyEmployeeId = (userData['employee_id'] as String?)?.trim();
    final trackingEmployeeId =
        (userData['trackingEmployeeId'] as String?)?.trim();
    final defaultLedgerEmployeeId =
        (userData['defaultLedgerEmployeeId'] as String?)?.trim();

    final roleMapRaw = userData['ledgerEmployeeRoles'];
    final roleMap = roleMapRaw is Map
        ? roleMapRaw.map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''))
        : <String, String>{};

    final ids = <String>[];
    final rawIds = userData['ledgerEmployeeIds'];
    if (rawIds is List) {
      for (final raw in rawIds) {
        final value = raw?.toString().trim();
        if (value != null && value.isNotEmpty && !ids.contains(value)) {
          ids.add(value);
        }
      }
    }

    void addIfValid(String? value) {
      if (value == null || value.isEmpty) return;
      if (!ids.contains(value)) ids.add(value);
    }

    addIfValid(defaultLedgerEmployeeId);
    addIfValid(trackingEmployeeId);
    addIfValid(legacyEmployeeId);

    final options = <_LedgerEmployeeOption>[];
    for (final id in ids) {
      final role = roleMap[id]?.trim();
      final label = (role != null && role.isNotEmpty)
          ? '${_roleToLabel(role)} Ledger'
          : 'Employee Ledger (${id.substring(0, id.length > 6 ? 6 : id.length)})';
      options.add(_LedgerEmployeeOption(employeeId: id, label: label));
    }

    final fallbackDefault = options.isNotEmpty ? options.first.employeeId : null;
    final selectedDefault = (defaultLedgerEmployeeId != null &&
            options.any((o) => o.employeeId == defaultLedgerEmployeeId))
        ? defaultLedgerEmployeeId
        : fallbackDefault;

    return _LedgerSelectionConfig(
      options: options,
      defaultEmployeeId: selectedDefault,
    );
  }

  String _roleToLabel(String rawRole) {
    final role = rawRole.toLowerCase();
    if (role.contains('driver')) return 'Driver';
    if (role.contains('loader')) return 'Loader';
    return rawRole[0].toUpperCase() + rawRole.substring(1);
  }

  /// Fetch user document using repository fallback logic
  Future<DocumentSnapshot<Map<String, dynamic>>?> _fetchUserDocument(
    BuildContext context,
    String organizationId,
    String userId,
    String? phoneNumber,
  ) async {
    try {
      final repository = context.read<UsersRepository>();
      final orgUser = await repository.fetchCurrentUser(
        orgId: organizationId,
        userId: userId,
        phoneNumber: phoneNumber,
      );

      if (orgUser == null) {
        debugPrint('[UserLedgerTable] fetchCurrentUser returned null');
        return null;
      }

      debugPrint('[UserLedgerTable] fetchCurrentUser found user with ID: ${orgUser.id}');
      // Return the document snapshot for the found user
      final doc = await FirebaseFirestore.instance
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('USERS')
          .doc(orgUser.id)
          .get();

      return doc.exists ? doc : null;
    } catch (e, stackTrace) {
      debugPrint('[UserLedgerTable] Error fetching user document: $e');
      debugPrint('[UserLedgerTable] Stack trace: $stackTrace');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final orgState = context.watch<OrganizationContextCubit>().state;
    
    final userId = authState.userProfile?.id;
    final organizationId = orgState.organization?.id;
    
    debugPrint('[UserLedgerTable] Building widget');
    debugPrint('[UserLedgerTable] userId: $userId');
    debugPrint('[UserLedgerTable] organizationId: $organizationId');
    debugPrint('[UserLedgerTable] userProfile exists: ${authState.userProfile != null}');
    debugPrint('[UserLedgerTable] organization exists: ${orgState.organization != null}');
    
    // Show message if user or organization not available
    if (userId == null || organizationId == null) {
      debugPrint('[UserLedgerTable] Missing userId or organizationId - showing fallback message');
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AuthColors.textMainWithOpacity(0.1),
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Please select an organization to view your ledger.',
                style: TextStyle(
                  color: AuthColors.textSub,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Text(
                  'Debug: userId=$userId, orgId=$organizationId',
                  style: TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    final userDocPath = 'ORGANIZATIONS/$organizationId/USERS/$userId';
    final phoneNumber = authState.userProfile?.phoneNumber;
    debugPrint('[UserLedgerTable] Watching user document at: $userDocPath');
    debugPrint('[UserLedgerTable] Phone number: $phoneNumber');

    // Use UsersRepository to fetch current user first (handles fallback logic)
    // Then watch the actual document ID found
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      future: _fetchUserDocument(context, organizationId, userId, phoneNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('[UserLedgerTable] Fetching user document...');
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: AuthColors.primary,
              ),
            ),
          );
        }

        final userDoc = snapshot.data;
        if (userDoc == null || !userDoc.exists) {
          debugPrint('[UserLedgerTable] User document not found after fallback lookup');
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AuthColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AuthColors.textMainWithOpacity(0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'User profile not found.',
                    style: TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 14,
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Debug: Path=$userDocPath\nPhone=$phoneNumber',
                      style: TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        // Now watch the actual document ID we found
        final actualUserId = userDoc.id;
        debugPrint('[UserLedgerTable] Found user document with ID: $actualUserId');
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('ORGANIZATIONS')
              .doc(organizationId)
              .collection('USERS')
              .doc(actualUserId)
              .snapshots(),
      builder: (context, userSnapshot) {
        debugPrint('[UserLedgerTable] StreamBuilder state: ${userSnapshot.connectionState}');
        debugPrint('[UserLedgerTable] StreamBuilder hasData: ${userSnapshot.hasData}');
        debugPrint('[UserLedgerTable] StreamBuilder hasError: ${userSnapshot.hasError}');
        if (userSnapshot.hasError) {
          debugPrint('[UserLedgerTable] StreamBuilder error: ${userSnapshot.error}');
        }
        if (userSnapshot.hasData) {
          debugPrint('[UserLedgerTable] Document exists: ${userSnapshot.data!.exists}');
          if (userSnapshot.data!.exists) {
            debugPrint('[UserLedgerTable] Document data: ${userSnapshot.data!.data()}');
          }
        }

        if (userSnapshot.connectionState == ConnectionState.waiting) {
          debugPrint('[UserLedgerTable] Waiting for user document...');
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: AuthColors.primary,
              ),
            ),
          );
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          debugPrint('[UserLedgerTable] User document not found or doesn\'t exist');
          debugPrint('[UserLedgerTable] Document path: $userDocPath');
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AuthColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AuthColors.textMainWithOpacity(0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'User profile not found.',
                    style: TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 14,
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Debug: Path=$userDocPath',
                      style: TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (userSnapshot.hasError)
                      Text(
                        'Error: ${userSnapshot.error}',
                        style: TextStyle(
                          color: AuthColors.error,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ],
              ),
            ),
          );
        }

        final userData = userSnapshot.data!.data()!;
        debugPrint('[UserLedgerTable] User data keys: ${userData.keys}');

        final ledgerConfig = _resolveLedgerSelectionConfig(userData);

        if (ledgerConfig.options.isEmpty || ledgerConfig.defaultEmployeeId == null) {
          debugPrint('[UserLedgerTable] No ledger employee mapping found in user document');
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AuthColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AuthColors.textMainWithOpacity(0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AuthColors.textSub,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No ledger account linked',
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Contact your administrator to link your ledger access.',
                    style: TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Debug: No employee_id / trackingEmployeeId / ledgerEmployeeIds mapped',
                      style: TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        debugPrint(
          '[UserLedgerTable] Ledger options found: ${ledgerConfig.options.map((o) => o.employeeId).toList()}',
        );

        return _EmployeeLedgerHost(
          organizationId: organizationId,
          options: ledgerConfig.options,
          defaultEmployeeId: ledgerConfig.defaultEmployeeId!,
        );
      },
        );
      },
    );
  }
}

class _EmployeeLedgerHost extends StatefulWidget {
  const _EmployeeLedgerHost({
    required this.organizationId,
    required this.options,
    required this.defaultEmployeeId,
  });

  final String organizationId;
  final List<_LedgerEmployeeOption> options;
  final String defaultEmployeeId;

  @override
  State<_EmployeeLedgerHost> createState() => _EmployeeLedgerHostState();
}

class _EmployeeLedgerHostState extends State<_EmployeeLedgerHost> {
  late String _selectedEmployeeId;

  String _resolveEmployeeName(Map<String, String> namesById, _LedgerEmployeeOption option) {
    final resolved = namesById[option.employeeId]?.trim();
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
    return option.label;
  }

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = widget.defaultEmployeeId;
  }

  @override
  void didUpdateWidget(covariant _EmployeeLedgerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedStillValid =
        widget.options.any((o) => o.employeeId == _selectedEmployeeId);
    if (!selectedStillValid) {
      _selectedEmployeeId = widget.defaultEmployeeId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedOption = widget.options.firstWhere(
      (o) => o.employeeId == _selectedEmployeeId,
      orElse: () => widget.options.first,
    );

    final employeeIds = widget.options
        .map((o) => o.employeeId)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    if (employeeIds.isEmpty) {
      return _EmployeeTransactionsTable(
        organizationId: widget.organizationId,
        employeeId: _selectedEmployeeId,
        employeeDisplayName: selectedOption.label,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('EMPLOYEES')
          .where('organizationId', isEqualTo: widget.organizationId)
          .where(FieldPath.documentId, whereIn: employeeIds)
          .snapshots(),
      builder: (context, employeeSnapshot) {
        final namesById = <String, String>{};
        if (employeeSnapshot.hasData) {
          for (final doc in employeeSnapshot.data!.docs) {
            final data = doc.data();
            final employeeName =
                (data['employeeName'] as String?)?.trim() ??
                (data['name'] as String?)?.trim();
            if (employeeName != null && employeeName.isNotEmpty) {
              namesById[doc.id] = employeeName;
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.options.length > 1) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedOption.employeeId,
                    isExpanded: true,
                    dropdownColor: AuthColors.surface,
                    items: widget.options
                        .map(
                          (o) => DropdownMenuItem<String>(
                            value: o.employeeId,
                            child: Text(
                              _resolveEmployeeName(namesById, o),
                              style: const TextStyle(
                                color: AuthColors.textMain,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedEmployeeId = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _EmployeeTransactionsTable(
              organizationId: widget.organizationId,
              employeeId: _selectedEmployeeId,
              employeeDisplayName:
                  _resolveEmployeeName(namesById, selectedOption),
            ),
          ],
        );
      },
    );
  }
}

class _LedgerEmployeeOption {
  const _LedgerEmployeeOption({required this.employeeId, required this.label});

  final String employeeId;
  final String label;
}

class _LedgerSelectionConfig {
  const _LedgerSelectionConfig({
    required this.options,
    required this.defaultEmployeeId,
  });

  final List<_LedgerEmployeeOption> options;
  final String? defaultEmployeeId;
}

class _EmployeeTransactionsTable extends StatelessWidget {
  const _EmployeeTransactionsTable({
    required this.organizationId,
    required this.employeeId,
    required this.employeeDisplayName,
  });

  final String organizationId;
  final String employeeId;
  final String employeeDisplayName;

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  String _formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);

  DateTime? _getTransactionDate(_LedgerTransactionData tx) {
    return tx.transactionDate ?? tx.createdAt ?? tx.updatedAt;
  }

  _LedgerTransactionData _mapLedgerTransaction(Map<String, dynamic> raw) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    final typeRaw = (raw['type'] as String?)?.toLowerCase();
    final type = typeRaw == 'credit' ? TransactionType.credit : TransactionType.debit;

    final metadataRaw = raw['metadata'];
    final metadata = metadataRaw is Map
        ? metadataRaw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    final category = (raw['category'] as String?) ?? '';
    final description = (raw['description'] as String?) ?? _formatCategoryName(category);
    final id =
        (raw['transactionId'] as String?) ?? (raw['id'] as String?) ?? '${parseDate(raw['transactionDate'])?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}_${raw['amount'] ?? 0}';

    return _LedgerTransactionData(
      id: id,
      amount: (raw['amount'] as num?)?.toDouble() ?? 0,
      type: type,
      description: description,
      category: category,
      metadata: metadata,
      balanceAfter: (raw['balanceAfter'] as num?)?.toDouble() ?? 0,
      transactionDate: parseDate(raw['transactionDate']),
      createdAt: parseDate(raw['createdAt']),
      updatedAt: parseDate(raw['updatedAt']),
    );
  }

  List<_LedgerTransactionData> _filterPast7Days(List<_LedgerTransactionData> transactions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.subtract(const Duration(days: 6));

    return transactions.where((tx) {
      final date = _getTransactionDate(tx);
      if (date == null) return false;
      final dateOnly = DateTime(date.year, date.month, date.day);
      return !dateOnly.isBefore(cutoff);
    }).toList();
  }

  /// Group transactions by date and source type (production batch, trip, or other)
  _GroupedLedgerEntries _groupTransactions(List<_LedgerTransactionData> transactions) {
    final productionGroups = <String, List<_LedgerTransactionData>>{};
    final tripGroups = <String, List<_LedgerTransactionData>>{};
    final otherTransactions = <_LedgerTransactionData>[];

    for (final tx in transactions) {
      final date = _getTransactionDate(tx);
      if (date == null) {
        otherTransactions.add(tx);
        continue;
      }

      final metadata = tx.metadata;
      final sourceType = metadata?['sourceType'] as String?;
      final batchIdFromMeta = metadata?['batchId'] as String?;
      final tripWageIdFromMeta = metadata?['tripWageId'] as String?;

      final isProduction = sourceType == 'productionBatch' ||
          (batchIdFromMeta != null && batchIdFromMeta.isNotEmpty);
      final isTrip = sourceType == 'tripWage' ||
          (tripWageIdFromMeta != null && tripWageIdFromMeta.isNotEmpty);

      if (isProduction) {
        final batchId = batchIdFromMeta ?? 'Unknown';
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final key = '$dateKey|$batchId';
        productionGroups.putIfAbsent(key, () => []).add(tx);
      } else if (isTrip) {
        final tripWageId = tripWageIdFromMeta;
        final tripIdentifier =
            (tripWageId != null && tripWageId.isNotEmpty) ? tripWageId : tx.id;
        final vehicleNo = metadata?['vehicleNumber'] as String? ?? 'N/A';
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final key = '$dateKey|$vehicleNo|$tripIdentifier';
        tripGroups.putIfAbsent(key, () => []).add(tx);
      } else {
        otherTransactions.add(tx);
      }
    }

    // Convert to entry objects
    final productionEntries = <_ProductionLedgerEntry>[];
    for (final entry in productionGroups.entries) {
      final parts = entry.key.split('|');
      final dateStr = parts[0];
      final batchId = parts[1];
      final txs = entry.value;
      if (txs.isEmpty) continue;

      final date = DateTime.parse(dateStr);
      // Sort transactions by date (newest first), then by amount
      txs.sort((a, b) {
        final dateA = _getTransactionDate(a) ?? DateTime(1970);
        final dateB = _getTransactionDate(b) ?? DateTime(1970);
        final dateCompare = dateB.compareTo(dateA);
        if (dateCompare != 0) return dateCompare;
        return (b.amount).compareTo(a.amount);
      });

      final batchNo = batchId.length > 8 ? '${batchId.substring(0, 8)}...' : batchId;

      productionEntries.add(_ProductionLedgerEntry(
        date: date,
        batchNo: batchNo,
        transactions: txs.map((tx) => _LedgerTransactionRow(
          description: tx.description,
          amount: tx.amount,
          type: tx.type,
          balanceAfter: tx.balanceAfter,
        )).toList(),
      ));
    }

    final tripEntries = <_TripLedgerEntry>[];
    for (final entry in tripGroups.entries) {
      final parts = entry.key.split('|');
      final dateStr = parts[0];
      final vehicleNo = parts[1];
      final txs = entry.value;
      if (txs.isEmpty) continue;

      final date = DateTime.parse(dateStr);
      // Sort transactions by date (newest first), then by amount
      txs.sort((a, b) {
        final dateA = _getTransactionDate(a) ?? DateTime(1970);
        final dateB = _getTransactionDate(b) ?? DateTime(1970);
        final dateCompare = dateB.compareTo(dateA);
        if (dateCompare != 0) return dateCompare;
        return (b.amount).compareTo(a.amount);
      });

        final tripCountFromMeta = txs
          .map((tx) => (tx.metadata?['tripCount'] as num?)?.toInt() ?? 0)
          .where((value) => value > 0)
          .fold<int>(0, (maxValue, value) => value > maxValue ? value : maxValue);
        final tripCount = tripCountFromMeta > 0 ? tripCountFromMeta : 1;

      tripEntries.add(_TripLedgerEntry(
        date: date,
        vehicleNo: vehicleNo,
        tripCount: tripCount,
        transactions: txs.map((tx) => _LedgerTransactionRow(
          description: tx.description,
          amount: tx.amount,
          type: tx.type,
          balanceAfter: tx.balanceAfter,
        )).toList(),
      ));
    }

    // Group other transactions by date
    final otherGroups = <String, List<_LedgerTransactionData>>{};
    for (final tx in otherTransactions) {
      final date = _getTransactionDate(tx);
      if (date == null) continue;
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      otherGroups.putIfAbsent(dateKey, () => []).add(tx);
    }

    final otherEntries = <_OtherLedgerEntry>[];
    for (final entry in otherGroups.entries) {
      final date = DateTime.parse(entry.key);
      final txs = entry.value;
      // Sort transactions by date (newest first), then by amount
      txs.sort((a, b) {
        final dateA = _getTransactionDate(a) ?? DateTime(1970);
        final dateB = _getTransactionDate(b) ?? DateTime(1970);
        final dateCompare = dateB.compareTo(dateA);
        if (dateCompare != 0) return dateCompare;
        return (b.amount).compareTo(a.amount);
      });

      otherEntries.add(_OtherLedgerEntry(
        date: date,
        transactions: txs.map((tx) => _LedgerTransactionRow(
          description: tx.description,
          amount: tx.amount,
          type: tx.type,
          balanceAfter: tx.balanceAfter,
        )).toList(),
      ));
    }

    // Sort entries by date (newest first)
    productionEntries.sort((a, b) => b.date.compareTo(a.date));
    tripEntries.sort((a, b) {
      final d = b.date.compareTo(a.date);
      if (d != 0) return d;
      return a.vehicleNo.compareTo(b.vehicleNo);
    });
    otherEntries.sort((a, b) => b.date.compareTo(a.date));

    return _GroupedLedgerEntries(
      productionEntries: productionEntries,
      tripEntries: tripEntries,
      otherEntries: otherEntries,
    );
  }

  String _formatCategoryName(String? category) {
    if (category == null || category.isEmpty) return '';
    return category
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<EmployeeWagesRepository>();

    debugPrint('[UserLedgerTable] _EmployeeTransactionsTable building');
    debugPrint('[UserLedgerTable] organizationId: $organizationId');
    debugPrint('[UserLedgerTable] employeeId: $employeeId');

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: repository.watchSelectedEmployeeLedgerTransactions(
        ledgerEmployeeId: employeeId,
        limit: 200,
      ),
      builder: (context, snapshot) {
        debugPrint('[UserLedgerTable] Transactions StreamBuilder state: ${snapshot.connectionState}');
        debugPrint('[UserLedgerTable] Transactions StreamBuilder hasData: ${snapshot.hasData}');
        debugPrint('[UserLedgerTable] Transactions StreamBuilder hasError: ${snapshot.hasError}');
        if (snapshot.hasError) {
          debugPrint('[UserLedgerTable] Transactions StreamBuilder error: ${snapshot.error}');
          debugPrint('[UserLedgerTable] Error stack trace: ${snapshot.stackTrace}');
        }
        if (snapshot.hasData) {
          debugPrint('[UserLedgerTable] Transactions count: ${snapshot.data!.length}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('[UserLedgerTable] Waiting for transactions...');
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: AuthColors.primary,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('[UserLedgerTable] Error loading transactions, showing error message');
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AuthColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AuthColors.textMainWithOpacity(0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AuthColors.error,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Error loading transactions',
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (kDebugMode && snapshot.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Debug: ${snapshot.error}',
                      style: TextStyle(
                        color: AuthColors.error,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        final ledgerTransactionsRaw = snapshot.data ?? const <Map<String, dynamic>>[];
        final transactions = ledgerTransactionsRaw.map(_mapLedgerTransaction).toList();
        final recentTransactions = _filterPast7Days(transactions);

        if (recentTransactions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AuthColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AuthColors.textMainWithOpacity(0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                'No transactions found in the past 7 days.',
                style: TextStyle(
                  color: AuthColors.textSub,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }

        // Group transactions by date and source
        final groupedEntries = _groupTransactions(recentTransactions);

        final productionMatrix = _buildProductionMatrix(groupedEntries.productionEntries);
        final tripMatrix = _buildTripMatrix(groupedEntries.tripEntries);
        final otherMatrix = _buildOtherMatrix(groupedEntries.otherEntries);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (productionMatrix != null) ...[
                _SectionHeader(title: 'Productions'),
                const SizedBox(height: 8),
                _LedgerMatrixTable(
                  matrix: productionMatrix,
                  detailHeader: 'Production',
                  formatCurrency: _formatCurrency,
                  formatDate: _formatDate,
                ),
                const SizedBox(height: 24),
              ],
              if (tripMatrix != null) ...[
                _SectionHeader(title: 'Trips'),
                const SizedBox(height: 8),
                _LedgerMatrixTable(
                  matrix: tripMatrix,
                  detailHeader: 'No. of Trips',
                  formatCurrency: _formatCurrency,
                  formatDate: _formatDate,
                ),
                const SizedBox(height: 24),
              ],
              if (otherMatrix != null) ...[
                _SectionHeader(title: 'Other Transactions'),
                const SizedBox(height: 8),
                _LedgerMatrixTable(
                  matrix: otherMatrix,
                  detailHeader: 'Description',
                  formatCurrency: _formatCurrency,
                  formatDate: _formatDate,
                ),
              ],
              if (groupedEntries.productionEntries.isEmpty &&
                  groupedEntries.tripEntries.isEmpty &&
                  groupedEntries.otherEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No transactions found.',
                    style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

  _SingleEmployeeLedgerMatrix? _buildProductionMatrix(List<_ProductionLedgerEntry> entries) {
    if (entries.isEmpty) return null;

    final dateSet = <DateTime>{};
    final cells = <DateTime, _LedgerMatrixCellBuilder>{};
    final allTx = <_LedgerTransactionRow>[];
    double total = 0;

    for (final entry in entries) {
      final dateKey = _normalizeDate(entry.date);
      dateSet.add(dateKey);
      final cell = cells.putIfAbsent(dateKey, _LedgerMatrixCellBuilder.new);
      cell.addDetail('Batch ${entry.batchNo}');

      final entryAmount = entry.transactions.fold<double>(0.0, (acc, tx) => acc + tx.amount);
      cell.amount += entryAmount;
      total += entryAmount;
      allTx.addAll(entry.transactions);
    }

    return _buildSingleEmployeeMatrix(
      dateSet: dateSet,
      cells: cells,
      total: total,
      allTransactions: allTx,
    );
  }

  _SingleEmployeeLedgerMatrix? _buildTripMatrix(List<_TripLedgerEntry> entries) {
    if (entries.isEmpty) return null;

    final dateSet = <DateTime>{};
    final cells = <DateTime, _LedgerMatrixCellBuilder>{};
    final allTx = <_LedgerTransactionRow>[];
    double total = 0;

    for (final entry in entries) {
      final dateKey = _normalizeDate(entry.date);
      dateSet.add(dateKey);
      final cell = cells.putIfAbsent(dateKey, _LedgerMatrixCellBuilder.new);
      cell.addDetail('${entry.vehicleNo} (${entry.tripCount})');

      final entryAmount = entry.transactions.fold<double>(0.0, (acc, tx) => acc + tx.amount);
      cell.amount += entryAmount;
      total += entryAmount;
      allTx.addAll(entry.transactions);
    }

    return _buildSingleEmployeeMatrix(
      dateSet: dateSet,
      cells: cells,
      total: total,
      allTransactions: allTx,
    );
  }

  _SingleEmployeeLedgerMatrix? _buildOtherMatrix(List<_OtherLedgerEntry> entries) {
    if (entries.isEmpty) return null;

    final dateSet = <DateTime>{};
    final cells = <DateTime, _LedgerMatrixCellBuilder>{};
    final allTx = <_LedgerTransactionRow>[];
    double total = 0;

    for (final entry in entries) {
      final dateKey = _normalizeDate(entry.date);
      dateSet.add(dateKey);
      final cell = cells.putIfAbsent(dateKey, _LedgerMatrixCellBuilder.new);

      for (final tx in entry.transactions) {
        cell.addDetail(tx.description);
      }

      final entryAmount = entry.transactions.fold<double>(0.0, (acc, tx) => acc + tx.amount);
      cell.amount += entryAmount;
      total += entryAmount;
      allTx.addAll(entry.transactions);
    }

    return _buildSingleEmployeeMatrix(
      dateSet: dateSet,
      cells: cells,
      total: total,
      allTransactions: allTx,
    );
  }

  _SingleEmployeeLedgerMatrix _buildSingleEmployeeMatrix({
    required Set<DateTime> dateSet,
    required Map<DateTime, _LedgerMatrixCellBuilder> cells,
    required double total,
    required List<_LedgerTransactionRow> allTransactions,
  }) {
    final dates = dateSet.toList()..sort();
    final builtCells = cells.map((date, builder) => MapEntry(date, builder.build()));

    final debitTotal = allTransactions
        .where((tx) => tx.type == TransactionType.debit)
      .fold<double>(0.0, (acc, tx) => acc + tx.amount);

    final currentBalance = allTransactions.isEmpty ? 0.0 : allTransactions.first.balanceAfter;
    final openingBalance = currentBalance - total + debitTotal;

    final row = _SingleEmployeeLedgerRow(
      employeeName: employeeDisplayName,
      cells: builtCells,
      totalAmount: total,
      debitTotal: debitTotal,
      currentBalance: currentBalance,
      openingBalance: openingBalance,
    );

    final totalsByDate = <DateTime, double>{
      for (final date in dates) date: builtCells[date]?.amount ?? 0.0,
    };

    return _SingleEmployeeLedgerMatrix(
      dates: dates,
      row: row,
      totalsByDate: totalsByDate,
      grandTotal: total,
      totalDebit: debitTotal,
      totalCurrentBalance: currentBalance,
      totalOpeningBalance: openingBalance,
    );
  }
}

class _LedgerTransactionData {
  const _LedgerTransactionData({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    required this.category,
    required this.metadata,
    required this.balanceAfter,
    this.transactionDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final double amount;
  final TransactionType type;
  final String description;
  final String category;
  final Map<String, dynamic>? metadata;
  final double balanceAfter;
  final DateTime? transactionDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

// Helper classes for grouped ledger entries
class _LedgerTransactionRow {
  const _LedgerTransactionRow({
    required this.description,
    required this.amount,
    required this.type,
    this.balanceAfter = 0,
  });

  final String description;
  final double amount;
  final TransactionType type;
  final double balanceAfter;
}

class _ProductionLedgerEntry {
  const _ProductionLedgerEntry({
    required this.date,
    required this.batchNo,
    required this.transactions,
  });

  final DateTime date;
  final String batchNo;
  final List<_LedgerTransactionRow> transactions;
}

class _TripLedgerEntry {
  const _TripLedgerEntry({
    required this.date,
    required this.vehicleNo,
    required this.tripCount,
    required this.transactions,
  });

  final DateTime date;
  final String vehicleNo;
  final int tripCount;
  final List<_LedgerTransactionRow> transactions;
}

class _OtherLedgerEntry {
  const _OtherLedgerEntry({
    required this.date,
    required this.transactions,
  });

  final DateTime date;
  final List<_LedgerTransactionRow> transactions;
}

class _GroupedLedgerEntries {
  const _GroupedLedgerEntries({
    required this.productionEntries,
    required this.tripEntries,
    required this.otherEntries,
  });

  final List<_ProductionLedgerEntry> productionEntries;
  final List<_TripLedgerEntry> tripEntries;
  final List<_OtherLedgerEntry> otherEntries;
}

// Section header widget
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AuthColors.textMain,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: 'SF Pro Display',
      ),
    );
  }
}

class _LedgerMatrixCell {
  const _LedgerMatrixCell({required this.details, required this.amount});

  final List<String> details;
  final double amount;

  String get detailsText => details.isEmpty ? '—' : details.join(', ');
}

class _LedgerMatrixCellBuilder {
  final List<String> _details = [];
  double amount = 0;

  void addDetail(String value) {
    if (value.isEmpty || _details.contains(value)) return;
    _details.add(value);
  }

  _LedgerMatrixCell build() => _LedgerMatrixCell(
        details: List.unmodifiable(_details),
        amount: amount,
      );
}

class _SingleEmployeeLedgerRow {
  const _SingleEmployeeLedgerRow({
    required this.employeeName,
    required this.cells,
    required this.totalAmount,
    required this.debitTotal,
    required this.currentBalance,
    required this.openingBalance,
  });

  final String employeeName;
  final Map<DateTime, _LedgerMatrixCell> cells;
  final double totalAmount;
  final double debitTotal;
  final double currentBalance;
  final double openingBalance;
}

class _SingleEmployeeLedgerMatrix {
  const _SingleEmployeeLedgerMatrix({
    required this.dates,
    required this.row,
    required this.totalsByDate,
    required this.grandTotal,
    required this.totalDebit,
    required this.totalCurrentBalance,
    required this.totalOpeningBalance,
  });

  final List<DateTime> dates;
  final _SingleEmployeeLedgerRow row;
  final Map<DateTime, double> totalsByDate;
  final double grandTotal;
  final double totalDebit;
  final double totalCurrentBalance;
  final double totalOpeningBalance;
}

class _LedgerMatrixTable extends StatelessWidget {
  const _LedgerMatrixTable({
    required this.matrix,
    required this.detailHeader,
    required this.formatCurrency,
    required this.formatDate,
  });

  final _SingleEmployeeLedgerMatrix matrix;
  final String detailHeader;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;

  static const double _employeeColWidth = 150;
  static const double _openingColWidth = 110;
  static const double _detailColWidth = 170;
  static const double _amountColWidth = 90;
  static const double _debitColWidth = 90;
  static const double _totalColWidth = 100;
  static const double _currentColWidth = 120;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 700;

    if (isMobile) {
      return _buildMobileView();
    }

    return _buildDesktopView();
  }

  Widget _buildDesktopView() {
    final dateCount = matrix.dates.length;
    final colCount = 2 + (dateCount * 2) + 3;

    final columnWidths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(_employeeColWidth),
      1: const FixedColumnWidth(_openingColWidth),
      for (int i = 0; i < dateCount * 2; i++)
        2 + i: i.isEven
            ? const FixedColumnWidth(_detailColWidth)
            : const FixedColumnWidth(_amountColWidth),
      colCount - 3: const FixedColumnWidth(_debitColWidth),
      colCount - 2: const FixedColumnWidth(_totalColWidth),
      colCount - 1: const FixedColumnWidth(_currentColWidth),
    };

    return Container(
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderRow1(),
          _buildHeaderRow2(),
          Divider(height: 1, thickness: 1, color: AuthColors.textMainWithOpacity(0.1)),
          Table(
            border: TableBorder.symmetric(
              inside: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
              outside: BorderSide.none,
            ),
            columnWidths: columnWidths,
            children: [
              _buildDataRow(),
              _buildFooterRow(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView() {
    final row = matrix.row;

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Text(
              row.employeeName,
              style: const TextStyle(
                color: AuthColors.textMain,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Column(
              children: [
                _summaryMetricRow('Opening', formatCurrency(row.openingBalance), isStrong: true),
                _summaryMetricRow('Debit', formatCurrency(row.debitTotal)),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: AuthColors.textMainWithOpacity(0.1)),
          for (final date in matrix.dates)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AuthColors.textMainWithOpacity(0.08)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatDate(date),
                          style: const TextStyle(
                            color: AuthColors.textMain,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        formatCurrency(matrix.totalsByDate[date] ?? 0.0),
                        style: const TextStyle(
                          color: AuthColors.textMain,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$detailHeader: ${row.cells[date]?.detailsText ?? '—'}',
                    style: const TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: AuthColors.background,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                _summaryMetricRow('TOTAL', formatCurrency(matrix.grandTotal), isStrong: true),
                const SizedBox(height: 8),
                _summaryMetricRow('Current Balance', formatCurrency(row.currentBalance), isStrong: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetricRow(String label, String value, {bool isStrong = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AuthColors.textSub,
                fontSize: 12,
                fontWeight: isStrong ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 12,
              fontWeight: isStrong ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow1() {
    return Container(
      color: AuthColors.background,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: _employeeColWidth, child: _cell('EMPLOYEES NAMES', isHeader: true)),
          SizedBox(width: _openingColWidth, child: _cell('Opening Balance', isHeader: true)),
          for (final date in matrix.dates)
            SizedBox(
              width: _detailColWidth + _amountColWidth,
              child: _cell(formatDate(date), isHeader: true),
            ),
          SizedBox(width: _debitColWidth, child: _cell('Debit', isHeader: true)),
          SizedBox(width: _totalColWidth, child: _cell('Total', isHeader: true)),
          SizedBox(width: _currentColWidth, child: _cell('Current Balance', isHeader: true)),
        ],
      ),
    );
  }

  Widget _buildHeaderRow2() {
    return Container(
      color: AuthColors.background.withValues(alpha: 0.85),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: _employeeColWidth, child: _cell('', isHeader: true)),
          SizedBox(width: _openingColWidth, child: _cell('', isHeader: true)),
          for (int i = 0; i < matrix.dates.length; i++) ...[
            SizedBox(width: _detailColWidth, child: _cell(detailHeader, isHeader: true)),
            SizedBox(width: _amountColWidth, child: _cell('Amount', isHeader: true, numeric: true)),
          ],
          SizedBox(width: _debitColWidth, child: _cell('', isHeader: true)),
          SizedBox(width: _totalColWidth, child: _cell('', isHeader: true)),
          SizedBox(width: _currentColWidth, child: _cell('', isHeader: true)),
        ],
      ),
    );
  }

  TableRow _buildDataRow() {
    final row = matrix.row;
    return TableRow(
      children: [
        _cell(row.employeeName),
        _cell(formatCurrency(row.openingBalance), numeric: true),
        for (final date in matrix.dates) ...[
          _cell(row.cells[date]?.detailsText ?? '—', small: true),
          _cell(formatCurrency(row.cells[date]?.amount ?? 0.0), numeric: true),
        ],
        _cell(formatCurrency(row.debitTotal), numeric: true),
        _cell(formatCurrency(row.totalAmount), numeric: true),
        _cell(formatCurrency(row.currentBalance), numeric: true),
      ],
    );
  }

  TableRow _buildFooterRow() {
    return TableRow(
      decoration: const BoxDecoration(color: AuthColors.background),
      children: [
        _cell('TOTAL', isHeader: true),
        _cell(formatCurrency(matrix.totalOpeningBalance), isHeader: true, numeric: true),
        for (final date in matrix.dates) ...[
          _cell('', isHeader: true),
          _cell(formatCurrency(matrix.totalsByDate[date] ?? 0.0), isHeader: true, numeric: true),
        ],
        _cell(formatCurrency(matrix.totalDebit), isHeader: true, numeric: true),
        _cell(formatCurrency(matrix.grandTotal), isHeader: true, numeric: true),
        _cell(formatCurrency(matrix.totalCurrentBalance), isHeader: true, numeric: true),
      ],
    );
  }

  Widget _cell(String text, {bool isHeader = false, bool numeric = false, bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Text(
        text,
        style: TextStyle(
          color: isHeader ? AuthColors.textSub : AuthColors.textMain,
          fontSize: small ? 12 : (isHeader ? 12 : 13),
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 3,
        textAlign: TextAlign.center,
      ),
    );
  }
}
