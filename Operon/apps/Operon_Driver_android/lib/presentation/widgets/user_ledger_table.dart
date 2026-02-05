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
    // Force print to ensure logs appear
    print('═══════════════════════════════════════════════════════');
    print('[UserLedgerTable] ===== WIDGET BUILDING =====');
    print('═══════════════════════════════════════════════════════');
    
    final authState = context.watch<AuthBloc>().state;
    final orgState = context.watch<OrganizationContextCubit>().state;
    
    final userId = authState.userProfile?.id;
    final organizationId = orgState.organization?.id;
    
    debugPrint('[UserLedgerTable] Building widget');
    print('[UserLedgerTable] userId: $userId');
    print('[UserLedgerTable] organizationId: $organizationId');
    print('[UserLedgerTable] userProfile exists: ${authState.userProfile != null}');
    print('[UserLedgerTable] organization exists: ${orgState.organization != null}');
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
        final employeeId = userData['employee_id'] as String?;
        debugPrint('[UserLedgerTable] User data keys: ${userData.keys}');
        debugPrint('[UserLedgerTable] employee_id from document: $employeeId');

        // Show message if no employeeId linked
        if (employeeId == null || employeeId.isEmpty) {
          debugPrint('[UserLedgerTable] No employeeId found in user document');
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
                    'No employee account linked',
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Contact your administrator to link your employee account.',
                    style: TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Debug: User document found but employee_id is null/empty',
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

        debugPrint('[UserLedgerTable] EmployeeId found: $employeeId, loading transactions...');
        // Watch employee transactions
        return _EmployeeTransactionsTable(
          organizationId: organizationId,
          employeeId: employeeId,
        );
      },
        );
      },
    );
  }
}

class _EmployeeTransactionsTable extends StatelessWidget {
  const _EmployeeTransactionsTable({
    required this.organizationId,
    required this.employeeId,
  });

  final String organizationId;
  final String employeeId;

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  String _formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);

  DateTime? _getTransactionDate(Transaction tx) {
    return tx.createdAt ?? tx.updatedAt;
  }

  /// Group transactions by date and source type (production batch, trip, or other)
  _GroupedLedgerEntries _groupTransactions(List<Transaction> transactions) {
    final productionGroups = <String, List<Transaction>>{};
    final tripGroups = <String, List<Transaction>>{};
    final otherTransactions = <Transaction>[];

    for (final tx in transactions) {
      final date = _getTransactionDate(tx);
      if (date == null) {
        otherTransactions.add(tx);
        continue;
      }

      final metadata = tx.metadata;
      final sourceType = metadata?['sourceType'] as String?;

      if (sourceType == 'productionBatch') {
        final batchId = metadata?['batchId'] as String? ?? 'Unknown';
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final key = '$dateKey|$batchId';
        productionGroups.putIfAbsent(key, () => []).add(tx);
      } else if (sourceType == 'tripWage') {
        final tripWageId = metadata?['tripWageId'] as String? ?? 'Unknown';
        final vehicleNo = metadata?['vehicleNumber'] as String? ?? 'N/A';
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final key = '$dateKey|$vehicleNo|$tripWageId';
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

      // Get balance from the most recent transaction (first after sorting)
      final balance = txs.isNotEmpty ? (txs.first.balanceAfter ?? 0.0) : 0.0;
      final batchNo = batchId.length > 8 ? '${batchId.substring(0, 8)}...' : batchId;

      productionEntries.add(_ProductionLedgerEntry(
        date: date,
        batchNo: batchNo,
        balance: balance,
        transactions: txs.map((tx) => _LedgerTransactionRow(
          description: tx.description ?? _formatCategoryName(tx.category.name),
          amount: tx.amount,
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

      // Get balance from the most recent transaction (first after sorting)
      final balance = txs.isNotEmpty ? (txs.first.balanceAfter ?? 0.0) : 0.0;
      final tripCount = txs.length;

      tripEntries.add(_TripLedgerEntry(
        date: date,
        vehicleNo: vehicleNo,
        tripCount: tripCount,
        balance: balance,
        transactions: txs.map((tx) => _LedgerTransactionRow(
          description: tx.description ?? _formatCategoryName(tx.category.name),
          amount: tx.amount,
        )).toList(),
      ));
    }

    // Group other transactions by date
    final otherGroups = <String, List<Transaction>>{};
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

      // Get balance from the most recent transaction (first after sorting)
      final balance = txs.isNotEmpty ? (txs.first.balanceAfter ?? 0.0) : 0.0;

      otherEntries.add(_OtherLedgerEntry(
        date: date,
        balance: balance,
        transactions: txs.map((tx) => _LedgerTransactionRow(
          description: tx.description ?? _formatCategoryName(tx.category.name),
          amount: tx.amount,
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

    return StreamBuilder<List<Transaction>>(
      stream: repository.watchEmployeeTransactions(
        organizationId: organizationId,
        employeeId: employeeId,
        limit: 15,
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

        final transactions = snapshot.data ?? [];

        if (transactions.isEmpty) {
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
                'No transactions found.',
                style: TextStyle(
                  color: AuthColors.textSub,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }

        // Group transactions by date and source
        final groupedEntries = _groupTransactions(transactions);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (groupedEntries.productionEntries.isNotEmpty) ...[
                _SectionHeader(title: 'Productions'),
                const SizedBox(height: 8),
                _ProductionsTable(
                  entries: groupedEntries.productionEntries,
                  formatCurrency: _formatCurrency,
                  formatDate: _formatDate,
                ),
                const SizedBox(height: 24),
              ],
              if (groupedEntries.tripEntries.isNotEmpty) ...[
                _SectionHeader(title: 'Trips'),
                const SizedBox(height: 8),
                _TripsTable(
                  entries: groupedEntries.tripEntries,
                  formatCurrency: _formatCurrency,
                  formatDate: _formatDate,
                ),
                const SizedBox(height: 24),
              ],
              if (groupedEntries.otherEntries.isNotEmpty) ...[
                _SectionHeader(title: 'Other Transactions'),
                const SizedBox(height: 8),
                _OtherTransactionsTable(
                  entries: groupedEntries.otherEntries,
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
}

// Helper classes for grouped ledger entries
class _LedgerTransactionRow {
  const _LedgerTransactionRow({
    required this.description,
    required this.amount,
  });

  final String description;
  final double amount;
}

class _ProductionLedgerEntry {
  const _ProductionLedgerEntry({
    required this.date,
    required this.batchNo,
    required this.balance,
    required this.transactions,
  });

  final DateTime date;
  final String batchNo;
  final double balance;
  final List<_LedgerTransactionRow> transactions;
}

class _TripLedgerEntry {
  const _TripLedgerEntry({
    required this.date,
    required this.vehicleNo,
    required this.tripCount,
    required this.balance,
    required this.transactions,
  });

  final DateTime date;
  final String vehicleNo;
  final int tripCount;
  final double balance;
  final List<_LedgerTransactionRow> transactions;
}

class _OtherLedgerEntry {
  const _OtherLedgerEntry({
    required this.date,
    required this.balance,
    required this.transactions,
  });

  final DateTime date;
  final double balance;
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

// Productions table widget
class _ProductionsTable extends StatelessWidget {
  const _ProductionsTable({
    required this.entries,
    required this.formatCurrency,
    required this.formatDate,
  });

  final List<_ProductionLedgerEntry> entries;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
          outside: BorderSide.none,
        ),
        columnWidths: const {
          0: FixedColumnWidth(100),
          1: FixedColumnWidth(120),
          2: IntrinsicColumnWidth(flex: 1),
          3: FixedColumnWidth(90),
        },
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(color: AuthColors.background),
            children: [
              _cell('Date', isHeader: true),
              _cell('Batch No.', isHeader: true),
              _cell('Description', isHeader: true),
              _cell('Amount', isHeader: true),
            ],
          ),
          // Data rows per entry
          for (final entry in entries) ..._buildEntryRows(entry),
        ],
      ),
    );
  }

  List<TableRow> _buildEntryRows(_ProductionLedgerEntry entry) {
    final rows = <TableRow>[];

    // Row 1: Date, Batch No., empty, empty
    rows.add(
      TableRow(
        children: [
          _cell(formatDate(entry.date)),
          _cell(entry.batchNo),
          _cell(''),
          _cell(''),
        ],
      ),
    );
    // Row 2: empty, empty, Balance, empty
    rows.add(
      TableRow(
        decoration: BoxDecoration(color: AuthColors.background.withOpacity(0.3)),
        children: [
          _cell(''),
          _cell(''),
          _cell(formatCurrency(entry.balance), muted: true),
          _cell(''),
        ],
      ),
    );
    // Transaction rows
    for (final tx in entry.transactions) {
      rows.add(
        TableRow(
          children: [
            _cell(''),
            _cell(''),
            _cell(tx.description, small: true),
            _cell(formatCurrency(tx.amount), numeric: true, small: true),
          ],
        ),
      );
    }

    return rows;
  }

  Widget _cell(String text, {bool isHeader = false, bool muted = false, bool numeric = false, bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Text(
        text,
        style: TextStyle(
          color: isHeader ? AuthColors.textSub : (muted ? AuthColors.textSub : AuthColors.textMain),
          fontSize: small ? 12 : (isHeader ? 12 : 13),
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        textAlign: numeric ? TextAlign.right : TextAlign.start,
      ),
    );
  }
}

// Trips table widget
class _TripsTable extends StatelessWidget {
  const _TripsTable({
    required this.entries,
    required this.formatCurrency,
    required this.formatDate,
  });

  final List<_TripLedgerEntry> entries;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
          outside: BorderSide.none,
        ),
        columnWidths: const {
          0: FixedColumnWidth(100),
          1: FixedColumnWidth(140),
          2: IntrinsicColumnWidth(flex: 1),
          3: FixedColumnWidth(90),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: AuthColors.background),
            children: [
              _cell('Date', isHeader: true),
              _cell('Vehicle No. (Trips)', isHeader: true),
              _cell('Description', isHeader: true),
              _cell('Amount', isHeader: true),
            ],
          ),
          for (final entry in entries) ..._buildEntryRows(entry),
        ],
      ),
    );
  }

  List<TableRow> _buildEntryRows(_TripLedgerEntry entry) {
    final rows = <TableRow>[];
    final vehicleLabel = '${entry.vehicleNo} (${entry.tripCount})';

    rows.add(
      TableRow(
        children: [
          _cell(formatDate(entry.date)),
          _cell(vehicleLabel),
          _cell(''),
          _cell(''),
        ],
      ),
    );
    rows.add(
      TableRow(
        decoration: BoxDecoration(color: AuthColors.background.withOpacity(0.3)),
        children: [
          _cell(''),
          _cell(''),
          _cell(formatCurrency(entry.balance), muted: true),
          _cell(''),
        ],
      ),
    );
    for (final tx in entry.transactions) {
      rows.add(
        TableRow(
          children: [
            _cell(''),
            _cell(''),
            _cell(tx.description, small: true),
            _cell(formatCurrency(tx.amount), numeric: true, small: true),
          ],
        ),
      );
    }

    return rows;
  }

  Widget _cell(String text, {bool isHeader = false, bool muted = false, bool numeric = false, bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Text(
        text,
        style: TextStyle(
          color: isHeader ? AuthColors.textSub : (muted ? AuthColors.textSub : AuthColors.textMain),
          fontSize: small ? 12 : (isHeader ? 12 : 13),
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        textAlign: numeric ? TextAlign.right : TextAlign.start,
      ),
    );
  }
}

// Other transactions table widget
class _OtherTransactionsTable extends StatelessWidget {
  const _OtherTransactionsTable({
    required this.entries,
    required this.formatCurrency,
    required this.formatDate,
  });

  final List<_OtherLedgerEntry> entries;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
          outside: BorderSide.none,
        ),
        columnWidths: const {
          0: FixedColumnWidth(100),
          1: IntrinsicColumnWidth(flex: 1),
          2: FixedColumnWidth(90),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: AuthColors.background),
            children: [
              _cell('Date', isHeader: true),
              _cell('Description', isHeader: true),
              _cell('Amount', isHeader: true),
            ],
          ),
          for (final entry in entries) ..._buildEntryRows(entry),
        ],
      ),
    );
  }

  List<TableRow> _buildEntryRows(_OtherLedgerEntry entry) {
    final rows = <TableRow>[];

    rows.add(
      TableRow(
        children: [
          _cell(formatDate(entry.date)),
          _cell(''),
          _cell(''),
        ],
      ),
    );
    rows.add(
      TableRow(
        decoration: BoxDecoration(color: AuthColors.background.withOpacity(0.3)),
        children: [
          _cell(''),
          _cell(formatCurrency(entry.balance), muted: true),
          _cell(''),
        ],
      ),
    );
    for (final tx in entry.transactions) {
      rows.add(
        TableRow(
          children: [
            _cell(''),
            _cell(tx.description, small: true),
            _cell(formatCurrency(tx.amount), numeric: true, small: true),
          ],
        ),
      );
    }

    return rows;
  }

  Widget _cell(String text, {bool isHeader = false, bool muted = false, bool numeric = false, bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Text(
        text,
        style: TextStyle(
          color: isHeader ? AuthColors.textSub : (muted ? AuthColors.textSub : AuthColors.textMain),
          fontSize: small ? 12 : (isHeader ? 12 : 13),
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        textAlign: numeric ? TextAlign.right : TextAlign.start,
      ),
    );
  }
}
