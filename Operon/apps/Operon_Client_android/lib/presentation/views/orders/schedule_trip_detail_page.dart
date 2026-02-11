import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:core_datasources/core_datasources.dart'
    hide ScheduledTripsRepository, ScheduledTripsDataSource;
import 'package:dash_mobile/data/repositories/payment_accounts_repository.dart';
import 'package:dash_mobile/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_mobile/data/utils/financial_year_utils.dart';
import 'package:dash_mobile/domain/entities/payment_account.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/data/services/dm_print_service.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/dm_print_dialog.dart';
import 'package:dash_mobile/presentation/widgets/return_payment_dialog.dart';
import 'package:dash_mobile/presentation/widgets/quick_action_menu.dart';
import 'package:dash_mobile/presentation/widgets/modern_tile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ScheduleTripDetailPage extends StatefulWidget {
  const ScheduleTripDetailPage({
    super.key,
    required this.trip,
  });

  final Map<String, dynamic> trip;

  @override
  State<ScheduleTripDetailPage> createState() => _ScheduleTripDetailPageState();
}

class _ScheduleTripDetailPageState extends State<ScheduleTripDetailPage> {
  late Map<String, dynamic> _trip;
  int _selectedTabIndex = 0;
  StreamSubscription<DocumentSnapshot>? _tripSubscription;

  @override
  void initState() {
    super.initState();
    _trip = Map<String, dynamic>.from(widget.trip);
    _subscribeToTrip();
  }

  void _subscribeToTrip() {
    final tripId = _trip['id'] as String?;
    if (tripId == null) return;

    // Use WidgetsBinding to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final orgContext = context.read<OrganizationContextCubit>().state;
      final organization = orgContext.organization;
      if (organization == null) return;

      _tripSubscription?.cancel();
      _tripSubscription = FirebaseFirestore.instance
          .collection('SCHEDULE_TRIPS')
          .doc(tripId)
          .snapshots()
          .listen(
        (snapshot) {
          if (snapshot.exists && mounted) {
            final data = snapshot.data()!;
            final updatedTrip = <String, dynamic>{
              'id': snapshot.id,
            };

            data.forEach((key, value) {
              if (value is Timestamp) {
                updatedTrip[key] = value.toDate();
              } else {
                updatedTrip[key] = value;
              }
            });

            setState(() {
              _trip = updatedTrip;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            debugPrint('[ScheduleTripDetailPage] Error watching trip: $error');
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openPrintDialog(BuildContext context) async {
    final org = context.read<OrganizationContextCubit>().state.organization;
    if (org == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an organization first')),
      );
      return;
    }
    final printService = context.read<DmPrintService>();
    final dmNumber = (_trip['dmNumber'] as num?)?.toInt();
    if (dmNumber == null) return;
    final dmData = await printService.fetchDmByNumberOrId(
      organizationId: org.id,
      dmNumber: dmNumber,
      dmId: _trip['dmId'] as String?,
      tripData: _trip,
    );
    if (dmData == null || !context.mounted) return;
    await DmPrintDialog.show(
      context: context,
      dmPrintService: printService,
      organizationId: org.id,
      dmData: dmData,
      dmNumber: dmNumber,
    );
  }

  Future<void> _dispatchTrip(
      BuildContext context, double? initialReading) async {
    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    // Check if DM is generated (mandatory for dispatch)
    final dmNumber = _trip['dmNumber'] as num?;
    if (dmNumber == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('DM must be generated before dispatching trip'),
            backgroundColor: AuthColors.error,
          ),
        );
      }
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
      }
      return;
    }

    final orgContext = context.read<OrganizationContextCubit>().state;
    final userRole = orgContext.appAccessRole?.name ?? 'unknown';

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispatching trip...')),
      );

      final repository = context.read<ScheduledTripsRepository>();
      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'dispatched',
        initialReading: initialReading,
        source: 'client',
      );

      // Update local state
      setState(() {
        _trip['orderStatus'] = 'dispatched';
        _trip['tripStatus'] = 'dispatched';
        if (initialReading != null) _trip['initialReading'] = initialReading;
        _trip['dispatchedAt'] = DateTime.now();
        _trip['dispatchedBy'] = currentUser.uid;
        _trip['dispatchedByRole'] = userRole;
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip dispatched successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to dispatch trip: $e')),
      );
    }
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
    final dmNumber = (_trip['dmNumber'] as num?)?.toInt();
    final tripStatus =
        (_trip['orderStatus'] ?? _trip['tripStatus'] ?? 'pending')
            .toString()
            .toLowerCase();
    final statusColor = () {
      switch (tripStatus) {
        case 'delivered':
          return AuthColors.success;
        case 'dispatched':
          return AuthColors.primary;
        case 'returned':
          return AuthColors.info;
        default:
          return AuthColors.textDisabled;
      }
    }();

    final items = _trip['items'] as List<dynamic>? ?? [];
    final tripPricing = _trip['tripPricing'] as Map<String, dynamic>? ?? {};
    final includeGstInTotal = _trip['includeGstInTotal'] as bool? ?? true;

    final clientName = _trip['clientName'] as String? ?? 'N/A';
    final driverName = _trip['driverName'] as String?;
    final vehicleNumber = _trip['vehicleNumber'] as String? ?? 'Not assigned';
    final scheduledDate = _trip['scheduledDate'];

    return Scaffold(
      backgroundColor: AuthColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Enhanced Header
                _TripHeader(
                  trip: _trip,
                  clientName: clientName,
                  driverName: driverName,
                  vehicleNumber: vehicleNumber,
                  scheduledDate: scheduledDate,
                  tripStatus: tripStatus,
                  statusColor: statusColor,
                  dmNumber: dmNumber,
                  formatDate: _formatDate,
                ),

                // Spacing between header and tab bar
                const SizedBox(height: AppSpacing.paddingLG),

                // Tab Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.paddingLG),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.paddingXS / 2),
                    decoration: BoxDecoration(
                      color: AuthColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                      border: Border.all(
                        color: AuthColors.textSub.withOpacity(0.1),
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
                            label: 'Items',
                            isSelected: _selectedTabIndex == 1,
                            onTap: () => setState(() => _selectedTabIndex = 1),
                          ),
                        ),
                        Expanded(
                          child: _TabButton(
                            label: 'Payments',
                            isSelected: _selectedTabIndex == 2,
                            onTap: () => setState(() => _selectedTabIndex = 2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingMD),

                // Tab Content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      setState(() {});
                    },
                    color: AuthColors.primary,
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: [
                        _OverviewTab(
                          trip: _trip,
                          formatDate: _formatDate,
                          tripStatus: tripStatus,
                          statusColor: statusColor,
                          dmNumber: dmNumber,
                          onCallDriver: () {
                            final driverPhone = _trip['driverPhone'] as String?;
                            if (driverPhone != null)
                              _callNumber(driverPhone, 'Driver');
                          },
                          onCallCustomer: () {
                            final clientPhone =
                                _trip['clientPhone'] as String? ??
                                    _trip['customerNumber'] as String?;
                            if (clientPhone != null)
                              _callNumber(clientPhone, 'Customer');
                          },
                          onPrintDM: dmNumber != null
                              ? () => _openPrintDialog(context)
                              : null,
                          onDispatch: (value) async {
                            if (value) {
                              await _dispatchTrip(context, null);
                            } else {
                              await _revertDispatch(context);
                            }
                          },
                          onDelivery: (value) async {
                            if (value) {
                              await _markAsDelivered(context);
                            } else {
                              await _revertDelivery(context);
                            }
                          },
                          onReturn: (value) async {
                            if (value) {
                              await _markAsReturned(context, null);
                            } else {
                              await _revertReturn(context);
                            }
                          },
                          onRecordPayment: (context) =>
                              _recordPaymentManually(context),
                        ),
                        _ItemsTab(
                          items: items,
                          tripPricing: tripPricing,
                          includeGstInTotal: includeGstInTotal,
                          trip: _trip,
                          formatDate: _formatDate,
                        ),
                        _PaymentsTab(
                          trip: _trip,
                          tripPricing: tripPricing,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // FAB Menu - positioned at bottom right with safe padding
            QuickActionMenu(
              right: QuickActionMenu.standardRight,
              bottom:
                  MediaQuery.of(context).padding.bottom + AppSpacing.paddingLG,
              actions: [
                QuickActionItem(
                  icon: Icons.call_outlined,
                  label: 'Call Driver',
                  onTap: () {
                    final driverPhone = _trip['driverPhone'] as String?;
                    if (driverPhone != null && driverPhone.isNotEmpty) {
                      _callNumber(driverPhone, 'Driver');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Driver phone not available'),
                          backgroundColor: AuthColors.warning,
                        ),
                      );
                    }
                  },
                ),
                QuickActionItem(
                  icon: Icons.call_outlined,
                  label: 'Call Customer',
                  onTap: () {
                    final clientPhone = _trip['clientPhone'] as String? ??
                        _trip['customerNumber'] as String?;
                    if (clientPhone != null && clientPhone.isNotEmpty) {
                      _callNumber(clientPhone, 'Customer');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Customer phone not available'),
                          backgroundColor: AuthColors.warning,
                        ),
                      );
                    }
                  },
                ),
                if (dmNumber != null)
                  QuickActionItem(
                    icon: Icons.print_outlined,
                    label: 'Print DM',
                    onTap: () => _openPrintDialog(context),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _revertDispatch(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text('Revert Dispatch',
            style: TextStyle(color: AuthColors.textMain)),
        content: const Text(
          'Are you sure you want to revert dispatch? This will change the trip status back to scheduled.',
          style: TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('Revert', style: TextStyle(color: AuthColors.info)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reverting dispatch...')),
      );

      final repository = context.read<ScheduledTripsRepository>();
      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'scheduled',
        source: 'client',
      );

      // Update local state
      setState(() {
        _trip['orderStatus'] = 'scheduled';
        _trip['tripStatus'] = 'scheduled';
        _trip.remove('initialReading');
        _trip.remove('dispatchedAt');
        _trip.remove('dispatchedBy');
        _trip.remove('dispatchedByRole');
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispatch reverted successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to revert dispatch: $e')),
      );
    }
  }

  Future<void> _markAsReturned(
      BuildContext context, double? finalReading) async {
    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
      }
      return;
    }

    final orgContext = context.read<OrganizationContextCubit>().state;
    final userRole = orgContext.appAccessRole?.name ?? 'unknown';
    final organization = orgContext.organization;
    if (organization == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization not found')),
        );
      }
      return;
    }

    // When meterType is KM we have finalReading; compute distance. Otherwise skip.
    double? distanceTravelled;
    if (finalReading != null) {
      final initialReading = _trip['initialReading'] as double?;
      if (initialReading == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Initial reading not found. Cannot calculate distance.')),
          );
        }
        return;
      }
      final d = finalReading - initialReading;
      distanceTravelled = d;
      if (d < 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Final reading cannot be less than initial reading')),
          );
        }
        return;
      }
    }

    // Pricing and payments
    final paymentType = (_trip['paymentType'] as String?)?.toLowerCase() ?? '';
    final tripPricing = _trip['tripPricing'] as Map<String, dynamic>? ?? {};
    final tripTotal = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
    final existingPayments = (_trip['paymentDetails'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final alreadyPaid = existingPayments.fold<double>(
      0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
    );

    List<Map<String, dynamic>> newPayments = [];
    double newPaidAmount = 0;

    // If pay_on_delivery, collect payment entries
    if (paymentType == 'pay_on_delivery') {
      // Fetch payment accounts
      try {
        final accountsRepo = context.read<PaymentAccountsRepository>();
        final accounts = await accountsRepo.fetchAccounts(organization.id);
        final activeAccounts = accounts.where((a) => a.isActive).toList();

        if (activeAccounts.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No active payment accounts found')),
            );
          }
          return;
        }

        final result = await showDialog<List<Map<String, dynamic>>>(
          context: context,
          builder: (ctx) => ReturnPaymentDialog(
            paymentAccounts: activeAccounts,
            tripTotal: tripTotal,
            alreadyPaid: alreadyPaid,
          ),
        );

        if (result == null) {
          // User cancelled payment entry
          return;
        }

        newPayments = result
            .map((p) => {
                  ...p,
                  'paidAt': DateTime.now(),
                  'paidBy': currentUser.uid,
                  'returnPayment': true,
                })
            .toList();
        newPaidAmount = newPayments.fold<double>(
          0,
          (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load payment accounts: $e')),
          );
        }
        return;
      }
    }

    final totalPaidAfter = alreadyPaid + newPaidAmount;
    final double remainingAmount =
        (tripTotal - totalPaidAfter).clamp(0, double.infinity).toDouble();
    final paymentStatus = totalPaidAfter >= tripTotal - 0.001
        ? 'full'
        : totalPaidAfter > 0
            ? 'partial'
            : 'pending';

    // Create transactions for new payments and optional credit
    final transactionsRepo = context.read<TransactionsRepository>();
    final financialYear = FinancialYearUtils.getFinancialYear(DateTime.now());
    final dmNumber = (_trip['dmNumber'] as num?)?.toInt();
    final dmText = dmNumber != null ? 'DM-$dmNumber' : 'Order Payment';
    final clientId = _trip['clientId'] as String? ?? '';
    final clientName = _trip['clientName'] as String?;

    final List<String> transactionIds =
        (_trip['returnTransactions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

    Future<void> createPaymentTransaction(
      Map<String, dynamic> payment,
      int index,
    ) async {
      final amount = (payment['amount'] as num).toDouble();
      final txnId = await transactionsRepo.createTransaction(
        Transaction(
          id: '',
          organizationId: organization.id,
          clientId: clientId,
          clientName: clientName,
          ledgerType: LedgerType.clientLedger,
          type: TransactionType
              .debit, // Debit = client paid on delivery (decreases receivable)
          category:
              TransactionCategory.tripPayment, // Payment collected on delivery
          amount: amount,
          paymentAccountId: payment['paymentAccountId'] as String?,
          paymentAccountType: payment['paymentAccountType'] as String?,
          tripId: tripId,
          description: 'Trip Payment - $dmText',
          metadata: {
            'tripId': tripId,
            if (dmNumber != null) 'dmNumber': dmNumber,
            'paymentIndex': index,
            'returnPayment': true,
          },
          createdBy: currentUser.uid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          financialYear: financialYear,
        ),
      );
      transactionIds.add(txnId);
    }

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marking trip as returned...')),
      );

      // Create payment transactions (debit) for pay_on_delivery
      // Note: Order Credit transaction was already created at DM generation (dispatch)
      for (int i = 0; i < newPayments.length; i++) {
        await createPaymentTransaction(newPayments[i], i);
      }

      // For pay_on_delivery: Order Credit transaction was created at DM generation (dispatch)
      // Trip Payment (debit) transactions are created above when payment is received on return
      // If partial payment, the remaining amount is already covered by the credit transaction

      // For pay_later: Order Credit transaction was created at DM generation (dispatch)
      // No additional transactions needed at return (customer pays later via manual Debit Payment)

      // Update trip with status + payment info
      final repository = context.read<ScheduledTripsRepository>();
      final combinedPayments = [...existingPayments, ...newPayments];

      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'returned',
        finalReading: finalReading,
        distanceTravelled: distanceTravelled,
        returnedBy: currentUser.uid,
        returnedByRole: userRole,
        paymentDetails: combinedPayments,
        totalPaidOnReturn: totalPaidAfter,
        paymentStatus: paymentStatus,
        remainingAmount:
            paymentType == 'pay_on_delivery' ? remainingAmount : null,
        source: 'client',
        returnTransactions: transactionIds,
      );

      // Update local state
      setState(() {
        _trip['orderStatus'] = 'returned';
        _trip['tripStatus'] = 'returned';
        if (finalReading != null) _trip['finalReading'] = finalReading;
        if (distanceTravelled != null)
          _trip['distanceTravelled'] = distanceTravelled;
        _trip['returnedAt'] = DateTime.now();
        _trip['returnedBy'] = currentUser.uid;
        _trip['returnedByRole'] = userRole;
        _trip['paymentDetails'] = combinedPayments;
        _trip['totalPaidOnReturn'] = totalPaidAfter;
        _trip['paymentStatus'] = paymentStatus;
        if (paymentType == 'pay_on_delivery') {
          _trip['remainingAmount'] = remainingAmount;
        } else {
          _trip.remove('remainingAmount');
        }
        _trip['returnTransactions'] = transactionIds;
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            distanceTravelled != null
                ? 'Trip marked as returned. Distance: ${distanceTravelled.toStringAsFixed(2)} km'
                : 'Trip marked as returned.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as returned: $e')),
      );
    }
  }

  Future<void> _markAsDelivered(BuildContext context) async {
    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
      }
      return;
    }

    final orgContext = context.read<OrganizationContextCubit>().state;
    final userRole = orgContext.appAccessRole?.name ?? 'unknown';

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marking trip as delivered...')),
      );

      final repository = context.read<ScheduledTripsRepository>();
      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'delivered',
        deliveredBy: currentUser.uid,
        deliveredByRole: userRole,
        source: 'client',
      );

      setState(() {
        _trip['orderStatus'] = 'delivered';
        _trip['tripStatus'] = 'delivered';
        _trip['deliveredAt'] = DateTime.now();
        _trip['deliveredBy'] = currentUser.uid;
        _trip['deliveredByRole'] = userRole;
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip marked as delivered')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as delivered: $e')),
      );
    }
  }

  Future<void> _revertDelivery(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text('Revert Delivery',
            style: TextStyle(color: AuthColors.textMain)),
        content: const Text(
          'Are you sure you want to revert delivery? This will change the trip status back to dispatched.',
          style: TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('Revert', style: TextStyle(color: AuthColors.info)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reverting delivery...')),
      );

      final repository = context.read<ScheduledTripsRepository>();
      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'dispatched',
        source: 'client',
      );

      setState(() {
        _trip['orderStatus'] = 'dispatched';
        _trip['tripStatus'] = 'dispatched';
        _trip.remove('deliveredAt');
        _trip.remove('deliveredBy');
        _trip.remove('deliveredByRole');
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery reverted successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to revert delivery: $e')),
      );
    }
  }

  Future<void> _recordPaymentManually(BuildContext context) async {
    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
      }
      return;
    }

    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;
    if (organization == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization not found')),
        );
      }
      return;
    }

    final tripPricing = _trip['tripPricing'] as Map<String, dynamic>? ?? {};
    final tripTotal = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
    final existingPayments = (_trip['paymentDetails'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final alreadyPaid = existingPayments.fold<double>(
      0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
    );

    // Fetch payment accounts
    try {
      final accountsRepo = context.read<PaymentAccountsRepository>();
      final accounts = await accountsRepo.fetchAccounts(organization.id);
      final activeAccounts = accounts.where((a) => a.isActive).toList();

      if (activeAccounts.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active payment accounts found')),
          );
        }
        return;
      }

      final result = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        builder: (ctx) => ReturnPaymentDialog(
          paymentAccounts: activeAccounts,
          tripTotal: tripTotal,
          alreadyPaid: alreadyPaid,
        ),
      );

      if (result == null || result.isEmpty) {
        // User cancelled payment entry
        return;
      }

      final newPayments = result
          .map((p) => {
                ...p,
                'paidAt': DateTime.now(),
                'paidBy': currentUser.uid,
                'manualPayment': true,
              })
          .toList();
      final newPaidAmount = newPayments.fold<double>(
        0,
        (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
      );

      final totalPaidAfter = alreadyPaid + newPaidAmount;
      final double remainingAmount =
          (tripTotal - totalPaidAfter).clamp(0, double.infinity).toDouble();
      final paymentStatus = totalPaidAfter >= tripTotal - 0.001
          ? 'full'
          : totalPaidAfter > 0
              ? 'partial'
              : 'pending';

      // Create payment transactions
      final transactionsRepo = context.read<TransactionsRepository>();
      final financialYear = FinancialYearUtils.getFinancialYear(DateTime.now());
      final clientId = _trip['clientId'] as String?;
      final clientName = _trip['clientName'] as String?;
      final dmNumber = (_trip['dmNumber'] as num?)?.toInt();
      final dmText = dmNumber != null ? 'DM-$dmNumber' : 'Trip';
      final List<String> transactionIds = [];

      Future<void> createPaymentTransaction(
          Map<String, dynamic> payment, int index) async {
        final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
        if (amount <= 0) return;

        final txnId = await transactionsRepo.createTransaction(
          Transaction(
            id: '', // Will be generated
            organizationId: organization.id,
            clientId: clientId,
            clientName: clientName,
            ledgerType: LedgerType.clientLedger,
            type: TransactionType
                .debit, // Debit = client paid (decreases receivable)
            category: TransactionCategory.clientPayment, // Manual payment
            amount: amount,
            paymentAccountId: payment['paymentAccountId'] as String?,
            paymentAccountType: payment['paymentAccountType'] as String?,
            tripId: tripId,
            description: 'Payment - $dmText',
            metadata: {
              'tripId': tripId,
              if (dmNumber != null) 'dmNumber': dmNumber,
              'paymentIndex': index,
              'manualPayment': true,
            },
            createdBy: currentUser.uid,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            financialYear: financialYear,
          ),
        );
        transactionIds.add(txnId);
      }

      try {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording payment...')),
        );

        // Create payment transactions
        for (int i = 0; i < newPayments.length; i++) {
          await createPaymentTransaction(newPayments[i], i);
        }

        // Update trip with payment info
        final repository = context.read<ScheduledTripsRepository>();
        final combinedPayments = [...existingPayments, ...newPayments];
        final currentTripStatus =
            (_trip['tripStatus'] as String?) ?? 'scheduled';

        await repository.updateTripStatus(
          tripId: tripId,
          tripStatus: currentTripStatus, // Keep current trip status
          paymentDetails: combinedPayments,
          totalPaidOnReturn: totalPaidAfter,
          paymentStatus: paymentStatus,
          remainingAmount: remainingAmount > 0.001 ? remainingAmount : null,
          source: 'client',
        );

        // Update local state
        setState(() {
          _trip['paymentDetails'] = combinedPayments;
          _trip['totalPaidOnReturn'] = totalPaidAfter;
          _trip['paymentStatus'] = paymentStatus;
          if (remainingAmount > 0.001) {
            _trip['remainingAmount'] = remainingAmount;
          } else {
            _trip.remove('remainingAmount');
          }
        });

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded successfully')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record payment: $e')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load payment accounts: $e')),
        );
      }
    }
  }

  Future<void> _revertReturn(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text('Revert Return',
            style: TextStyle(color: AuthColors.textMain)),
        content: const Text(
          'Are you sure you want to revert return? This will change the trip status back to delivered.',
          style: TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('Revert', style: TextStyle(color: AuthColors.info)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reverting return...')),
      );

      // Cancel transactions created during return (if any)
      final transactionIds = (_trip['returnTransactions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final transactionsRepo = context.read<TransactionsRepository>();
        for (final txnId in transactionIds) {
          try {
            await transactionsRepo.cancelTransaction(
              transactionId: txnId,
              cancelledBy: currentUser.uid,
              cancellationReason: 'Return reverted - trip moved to delivered',
            );
          } catch (_) {
            // continue cancelling others
          }
        }
      }

      final repository = context.read<ScheduledTripsRepository>();
      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'delivered',
        paymentDetails: const [],
        totalPaidOnReturn: null,
        paymentStatus: null,
        remainingAmount: null,
        returnTransactions: const [],
        clearPaymentInfo: true,
        source: 'client',
      );

      // Update local state - remove return fields but keep delivery and dispatch fields
      setState(() {
        _trip['orderStatus'] = 'delivered';
        _trip['tripStatus'] = 'delivered';
        _trip.remove('finalReading');
        _trip.remove('distanceTravelled');
        _trip.remove('returnedAt');
        _trip.remove('returnedBy');
        _trip.remove('returnedByRole');
        _trip.remove('paymentDetails');
        _trip.remove('totalPaidOnReturn');
        _trip.remove('paymentStatus');
        _trip.remove('remainingAmount');
        _trip.remove('returnTransactions');
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Return reverted successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to revert return: $e')),
      );
    }
  }

  Future<void> _callNumber(String? phone, String label) async {
    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label phone not available')),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not call $label')),
      );
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ModernTile(
        padding: const EdgeInsets.all(AppSpacing.paddingMD),
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.h4.copyWith(
                fontSize: 15,
              ),
            ),
            const SizedBox(height: AppSpacing.paddingMD),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final effectiveValueColor = valueColor ?? AuthColors.textSub;
    final effectiveValueStyle = AppTypography.body.copyWith(
      color: effectiveValueColor,
      fontWeight: FontWeight.normal,
    );

    final content = Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AuthColors.textDisabled,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: effectiveValueStyle,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingXS),
      child: content,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    required this.onTap,
    this.isFullWidth = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return Material(
      color: AuthColors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        child: Container(
          width: isFullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.paddingMD,
            vertical: AppSpacing.paddingMD,
          ),
          decoration: BoxDecoration(
            gradient: isDisabled
                ? null
                : LinearGradient(
                    colors: [
                      color.withOpacity(0.2),
                      color.withOpacity(0.15),
                    ],
                  ),
            color: isDisabled ? AuthColors.surface : null,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            border: Border.all(
              color: isDisabled
                  ? AuthColors.textMain.withOpacity(0.1)
                  : color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isDisabled ? AuthColors.textSub : color,
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isDisabled
                            ? AuthColors.textSub
                            : AuthColors.textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.paddingXS / 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: isDisabled
                              ? AuthColors.textSub
                              : AuthColors.textMain.withOpacity(0.6),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusToggleRow extends StatelessWidget {
  const _StatusToggleRow({
    required this.label,
    required this.value,
    this.hint,
    required this.enabled,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final String? hint;
  final bool enabled;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: AppSpacing.paddingXS / 2),
                Text(
                  hint!,
                  style: TextStyle(
                    color: activeColor.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeThumbColor: activeColor,
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

class _PaymentDetailsSection extends StatefulWidget {
  const _PaymentDetailsSection({
    required this.trip,
    required this.onPaymentUpdated,
  });

  final Map<String, dynamic> trip;
  final VoidCallback onPaymentUpdated;

  @override
  State<_PaymentDetailsSection> createState() => _PaymentDetailsSectionState();
}

class _PaymentDetailsSectionState extends State<_PaymentDetailsSection> {
  List<PaymentAccount>? _paymentAccounts;
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentAccounts();
  }

  Future<void> _loadPaymentAccounts() async {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;
    if (organization == null) return;

    try {
      setState(() => _isLoading = true);
      final repo = context.read<PaymentAccountsRepository>();
      final accounts = await repo.fetchAccounts(organization.id);
      // Filter only active accounts
      setState(() {
        _paymentAccounts = accounts.where((a) => a.isActive).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load payment accounts: $e')),
        );
      }
    }
  }

  Future<void> _showAddPaymentDialog() async {
    if (_paymentAccounts == null || _paymentAccounts!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active payment accounts available')),
        );
      }
      return;
    }

    PaymentAccount? selectedAccount;
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AuthColors.surface,
          title: const Text(
            'Add Payment',
            style: TextStyle(color: AuthColors.textMain),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<PaymentAccount>(
                    initialValue: selectedAccount,
                    decoration: InputDecoration(
                      labelText: 'Payment Account',
                      labelStyle: const TextStyle(color: AuthColors.textSub),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: AuthColors.textMain.withOpacity(0.3)),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSM),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AuthColors.info),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSM),
                      ),
                    ),
                    dropdownColor: AuthColors.surface,
                    style: const TextStyle(color: AuthColors.textMain),
                    items: _paymentAccounts!.map((account) {
                      return DropdownMenuItem<PaymentAccount>(
                        value: account,
                        child: Text('${account.name} (${account.type.name})'),
                      );
                    }).toList(),
                    onChanged: (account) {
                      setDialogState(() => selectedAccount = account);
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a payment account';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AuthColors.textMain),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      labelStyle: const TextStyle(color: AuthColors.textSub),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: AuthColors.textMain.withOpacity(0.3)),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSM),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AuthColors.info),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSM),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AuthColors.info,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (shouldAdd == true && selectedAccount != null) {
      final amount = double.tryParse(amountController.text);
      if (amount != null && amount > 0) {
        await _addPayment(selectedAccount!, amount);
      }
    }
  }

  Future<void> _addPayment(PaymentAccount account, double amount) async {
    final tripId = widget.trip['id'] as String?;
    if (tripId == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;
    if (organization == null) return;

    final tripPricing =
        widget.trip['tripPricing'] as Map<String, dynamic>? ?? {};
    final totalAmount = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
    final existingPayments =
        (widget.trip['paymentDetails'] as List<dynamic>?) ?? [];
    final paidAmount = existingPayments.fold<double>(
      0.0,
      (sum, payment) {
        final amount = (payment as Map<String, dynamic>)['amount'] as num?;
        return sum + (amount?.toDouble() ?? 0.0);
      },
    );

    if (paidAmount + amount > totalAmount) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Payment amount exceeds total. Remaining: ₹${(totalAmount - paidAmount).toStringAsFixed(2)}')),
        );
      }
      return;
    }

    try {
      setState(() => _isSubmitting = true);

      final paymentDetail = {
        'paymentAccountId': account.id,
        'paymentAccountName': account.name,
        'paymentAccountType': account.type.name,
        'amount': amount,
        'paidAt': DateTime.now(),
        'paidBy': currentUser.uid,
      };

      // Create transaction
      final transactionsRepo = context.read<TransactionsRepository>();
      final financialYear = FinancialYearUtils.getFinancialYear(DateTime.now());
      final clientId = widget.trip['clientId'] as String? ?? '';
      final clientName = widget.trip['clientName'] as String?;
      final dmNumber = (widget.trip['dmNumber'] as num?)?.toInt();
      final dmText = dmNumber != null ? 'DM-$dmNumber' : 'Order Payment';

      await transactionsRepo.createTransaction(
        Transaction(
          id: '',
          organizationId: organization.id,
          clientId: clientId,
          clientName: clientName,
          ledgerType: LedgerType.clientLedger,
          type: TransactionType
              .debit, // Debit = client paid on delivery (decreases receivable)
          category:
              TransactionCategory.tripPayment, // Payment collected on delivery
          amount: amount,
          createdBy: currentUser.uid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          financialYear: financialYear,
          paymentAccountId: account.id,
          paymentAccountType: account.type.name,
          tripId: tripId,
          description: 'Trip Payment - $dmText',
          metadata: {
            'tripId': tripId,
            if (dmNumber != null) 'dmNumber': dmNumber,
          },
        ),
      );

      // Update local state
      final updatedPayments = List<Map<String, dynamic>>.from(existingPayments);
      updatedPayments.add(paymentDetail);
      widget.trip['paymentDetails'] = updatedPayments;

      setState(() => _isSubmitting = false);
      widget.onPaymentUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment added successfully')),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add payment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripPricing =
        widget.trip['tripPricing'] as Map<String, dynamic>? ?? {};
    final totalAmount = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
    final existingPayments =
        (widget.trip['paymentDetails'] as List<dynamic>?) ?? [];
    final paidAmount = existingPayments.fold<double>(
      0.0,
      (sum, payment) {
        final amount = (payment as Map<String, dynamic>)['amount'] as num?;
        return sum + (amount?.toDouble() ?? 0.0);
      },
    );
    final remainingAmount = totalAmount - paidAmount;

    return _InfoCard(
      title: 'Payment Details',
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Total Amount',
                style: TextStyle(color: AuthColors.textSub, fontSize: 12),
              ),
            ),
            Text(
              '₹${totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: AuthColors.textMain,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.paddingSM),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Paid Amount',
                style: TextStyle(color: AuthColors.textSub, fontSize: 12),
              ),
            ),
            Text(
              '₹${paidAmount.toStringAsFixed(2)}',
              style: TextStyle(
                color: paidAmount > 0 ? AuthColors.success : AuthColors.textSub,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.paddingSM),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Remaining',
                style: TextStyle(color: AuthColors.textSub, fontSize: 12),
              ),
            ),
            Text(
              '₹${remainingAmount.toStringAsFixed(2)}',
              style: TextStyle(
                color: remainingAmount > 0
                    ? AuthColors.warning
                    : AuthColors.success,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (existingPayments.isNotEmpty) ...[
          const SizedBox(height: 16),
          Divider(color: AuthColors.textMain.withOpacity(0.24), height: 1),
          const SizedBox(height: AppSpacing.paddingMD),
          ...existingPayments.map((payment) {
            final paymentMap = payment as Map<String, dynamic>;
            final amount = (paymentMap['amount'] as num?)?.toDouble() ?? 0.0;
            final accountName =
                paymentMap['paymentAccountName'] as String? ?? 'Unknown';
            final accountType =
                paymentMap['paymentAccountType'] as String? ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.paddingSM),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          accountName,
                          style: const TextStyle(
                            color: AuthColors.textMain,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          accountType,
                          style: TextStyle(
                            color: AuthColors.textMain.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        if (remainingAmount > 0 && !_isSubmitting) ...[
          const SizedBox(height: AppSpacing.paddingMD),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _showAddPaymentDialog,
              style: FilledButton.styleFrom(
                backgroundColor: AuthColors.info,
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.paddingMD),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Payment'),
            ),
          ),
        ],
        if (_isSubmitting) ...[
          const SizedBox(height: AppSpacing.paddingMD),
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
      ],
    );
  }
}

// Enhanced Trip Header Widget
class _TripHeader extends StatelessWidget {
  const _TripHeader({
    required this.trip,
    required this.clientName,
    required this.driverName,
    required this.vehicleNumber,
    required this.scheduledDate,
    required this.tripStatus,
    required this.statusColor,
    required this.dmNumber,
    required this.formatDate,
  });

  final Map<String, dynamic> trip;
  final String clientName;
  final String? driverName;
  final String vehicleNumber;
  final dynamic scheduledDate;
  final String tripStatus;
  final Color statusColor;
  final int? dmNumber;
  final String Function(dynamic) formatDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.paddingLG,
        AppSpacing.paddingMD,
        AppSpacing.paddingLG,
        AppSpacing.paddingMD,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuthColors.surface,
            AuthColors.surface.withOpacity(0.95),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AuthColors.textSub.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back,
                  color: AuthColors.textSub,
                  size: AppSpacing.iconMD,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: AppTypography.h3,
                    ),
                    const SizedBox(height: AppSpacing.paddingXS / 2),
                    Row(
                      children: [
                        if (dmNumber != null) ...[
                          Text(
                            'DM-$dmNumber',
                            style: AppTypography.caption.copyWith(
                              color: AuthColors.textDisabled,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.paddingSM),
                          Text(
                            '•',
                            style: AppTypography.caption.copyWith(
                              color: AuthColors.textDisabled,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.paddingSM),
                        ],
                        Text(
                          formatDate(scheduledDate),
                          style: AppTypography.caption.copyWith(
                            color: AuthColors.textDisabled,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.paddingMD,
                  vertical: AppSpacing.paddingSM,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withOpacity(0.25),
                      statusColor.withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                  border: Border.all(
                    color: statusColor.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  tripStatus.toUpperCase(),
                  style: AppTypography.captionSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          // Quick Info Row
          Row(
            children: [
              if (driverName != null && driverName!.isNotEmpty) ...[
                Expanded(
                  child: _InfoPill(
                    icon: Icons.person_outline,
                    label: 'Driver',
                    value: driverName!,
                    color: AuthColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.paddingMD),
              ],
              Expanded(
                child: _InfoPill(
                  icon: Icons.directions_car_outlined,
                  label: 'Vehicle',
                  value: vehicleNumber,
                  color: AuthColors.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Info Pill Widget
class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.paddingMD,
        vertical: AppSpacing.paddingSM,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: AppSpacing.paddingSM),
          Expanded(
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
                const SizedBox(height: AppSpacing.paddingXS / 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Tab Button Widget
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
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.paddingSM,
          horizontal: AppSpacing.paddingXS,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AuthColors.primary : AuthColors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            color: isSelected ? AuthColors.textMain : AuthColors.textSub,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// Overview Tab
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.trip,
    required this.formatDate,
    required this.tripStatus,
    required this.statusColor,
    required this.dmNumber,
    required this.onCallDriver,
    required this.onCallCustomer,
    required this.onPrintDM,
    required this.onDispatch,
    required this.onDelivery,
    required this.onReturn,
    required this.onRecordPayment,
  });

  final Map<String, dynamic> trip;
  final String Function(dynamic) formatDate;
  final String tripStatus;
  final Color statusColor;
  final int? dmNumber;
  final VoidCallback onCallDriver;
  final VoidCallback onCallCustomer;
  final VoidCallback? onPrintDM;
  final ValueChanged<bool> onDispatch;
  final ValueChanged<bool> onDelivery;
  final ValueChanged<bool> onReturn;
  final Future<void> Function(BuildContext) onRecordPayment;

  @override
  Widget build(BuildContext context) {
    final driverPhone = trip['driverPhone'] as String?;
    final clientPhone =
        trip['clientPhone'] as String? ?? trip['customerNumber'] as String?;
    final tripPricing = trip['tripPricing'] as Map<String, dynamic>? ?? {};
    final totalAmount = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
    final paymentType = (trip['paymentType'] as String?)?.toLowerCase() ?? '';
    final paymentDetails = (trip['paymentDetails'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final totalPaidStored = (trip['totalPaidOnReturn'] as num?)?.toDouble();
    final computedPaid = paymentDetails.fold<double>(
      0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
    );
    final totalPaid = totalPaidStored ?? computedPaid;
    final remainingStored = (trip['remainingAmount'] as num?)?.toDouble();
    final remaining = remainingStored ?? (totalAmount - totalPaid);
    final status = (trip['paymentStatus'] as String?) ??
        (remaining <= 0.001
            ? 'full'
            : totalPaid > 0
                ? 'partial'
                : 'pending');

    final isDispatched = tripStatus.toLowerCase() == 'dispatched';
    final isDelivered = tripStatus.toLowerCase() == 'delivered';
    final isReturned = tripStatus.toLowerCase() == 'returned';
    final isPending = tripStatus.toLowerCase() == 'pending' ||
        tripStatus.toLowerCase() == 'scheduled';
    final hasDM = dmNumber != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Actions
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.call_outlined,
                  label: 'Driver',
                  subtitle: driverPhone ?? 'Not available',
                  color: AuthColors.primary,
                  onTap: driverPhone != null && driverPhone.isNotEmpty
                      ? onCallDriver
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.paddingMD),
              Expanded(
                child: _ActionButton(
                  icon: Icons.call_outlined,
                  label: 'Customer',
                  subtitle: clientPhone ?? 'Not available',
                  color: AuthColors.info,
                  onTap: clientPhone != null && clientPhone.isNotEmpty
                      ? onCallCustomer
                      : null,
                ),
              ),
            ],
          ),
          if (onPrintDM != null) ...[
            const SizedBox(height: AppSpacing.paddingMD),
            SizedBox(
              width: double.infinity,
              child: _ActionButton(
                icon: Icons.print_outlined,
                label: 'Print DM',
                subtitle: 'DM-${trip['dmNumber']}',
                color: AuthColors.info,
                onTap: onPrintDM,
                isFullWidth: true,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.paddingXL),

          // Trip Status
          _InfoCard(
            title: 'Trip Status',
            children: [
              _InfoRow(
                label: 'Status',
                value: tripStatus.toUpperCase(),
              ),
              const SizedBox(height: AppSpacing.paddingLG),
              Divider(
                color: AuthColors.textMain.withOpacity(0.1),
                height: AppSpacing.paddingMD,
                thickness: 1,
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              _StatusToggleRow(
                label: 'Dispatch',
                value: isDispatched,
                hint: !hasDM && isPending ? 'Generate DM first' : null,
                enabled: (isPending || isDispatched) && !isDelivered && hasDM,
                activeColor: AuthColors.info,
                onChanged: onDispatch,
              ),
              if (isDispatched || isDelivered || isReturned) ...[
                const SizedBox(height: AppSpacing.paddingLG),
                Divider(
                  color: AuthColors.textMain.withOpacity(0.1),
                  height: AppSpacing.paddingMD,
                  thickness: 1,
                ),
                const SizedBox(height: AppSpacing.paddingMD),
                _StatusToggleRow(
                  label: 'Delivery',
                  value: isDelivered,
                  enabled: (isDispatched && !isDelivered && !isReturned) ||
                      (isDelivered && !isReturned),
                  activeColor: AuthColors.success,
                  onChanged: onDelivery,
                ),
              ],
              if (isDelivered || isReturned) ...[
                const SizedBox(height: AppSpacing.paddingLG),
                Divider(
                  color: AuthColors.textMain.withOpacity(0.1),
                  height: AppSpacing.paddingMD,
                  thickness: 1,
                ),
                const SizedBox(height: AppSpacing.paddingMD),
                _StatusToggleRow(
                  label: 'Return',
                  value: isReturned,
                  enabled: (isDelivered && !isReturned) || isReturned,
                  activeColor: AuthColors.info,
                  onChanged: onReturn,
                ),
              ],
            ],
          ),
          if (paymentType.isNotEmpty && status.toLowerCase() == 'pending') ...[
            const SizedBox(height: AppSpacing.paddingMD),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => onRecordPayment(context),
                icon: const Icon(Icons.payment, size: 18),
                label: const Text('Record Payment'),
                style: FilledButton.styleFrom(
                  backgroundColor: AuthColors.primary,
                  foregroundColor: AuthColors.textMain,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.paddingMD,
                    horizontal: AppSpacing.paddingLG,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.paddingMD),

          // Quick Stats
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.currency_rupee,
                  label: 'Total Value',
                  value: '₹${totalAmount.toStringAsFixed(2)}',
                  color: AuthColors.info,
                ),
              ),
            ],
          ),
          SizedBox(
              height:
                  MediaQuery.of(context).padding.bottom + AppSpacing.paddingXL),
        ],
      ),
    );
  }
}

// Items Tab
class _ItemsTab extends StatelessWidget {
  const _ItemsTab({
    required this.items,
    required this.tripPricing,
    required this.includeGstInTotal,
    required this.trip,
    required this.formatDate,
  });

  final List<dynamic> items;
  final Map<String, dynamic> tripPricing;
  final bool includeGstInTotal;
  final Map<String, dynamic> trip;
  final String Function(dynamic) formatDate;

  @override
  Widget build(BuildContext context) {
    final subtotal = (tripPricing['subtotal'] as num?)?.toDouble() ?? 0.0;
    final gstAmount = (tripPricing['gstAmount'] as num?)?.toDouble() ?? 0.0;
    final total = includeGstInTotal ? subtotal + gstAmount : subtotal;

    final scheduledDate = trip['scheduledDate'];
    final slot = trip['slot'] as int?;
    final deliveryZone = trip['deliveryZone'] as Map<String, dynamic>? ?? {};
    final address = deliveryZone['region'] ??
        deliveryZone['zone'] ??
        deliveryZone['city'] ??
        deliveryZone['city_name'] ??
        'Not provided';
    final city = deliveryZone['city'] ?? deliveryZone['city_name'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            title: 'Order Summary',
            children: [
              // Product rows
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value as Map<String, dynamic>;
                final productName = item['productName'] as String? ??
                    item['name'] as String? ??
                    'Unknown';
                final qty =
                    (item['fixedQuantityPerTrip'] as num?)?.toInt() ?? 0;
                final unitPrice = (item['unitPrice'] as num?)?.toDouble() ??
                    (item['unit_price'] as num?)?.toDouble() ??
                    0.0;
                final itemTotal = qty * unitPrice;

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < items.length - 1 ? AppSpacing.paddingMD : 0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: const TextStyle(
                                color: AuthColors.textMain,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.paddingXS / 2),
                            Row(
                              children: [
                                Text(
                                  'Qty: $qty',
                                  style: TextStyle(
                                    color: AuthColors.textMain.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.paddingSM),
                                Text(
                                  '× ₹${unitPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: AuthColors.textMain.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${itemTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AuthColors.textMain,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.paddingMD),
              Divider(
                color: AuthColors.textMain.withOpacity(0.1),
                height: AppSpacing.paddingLG,
                thickness: 1,
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              // Subtotal
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.paddingSM),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Subtotal',
                        style: TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '₹${subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // GST
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.paddingSM),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'GST ${includeGstInTotal ? "(Included)" : "(Excluded)"}',
                        style: TextStyle(
                          color: includeGstInTotal
                              ? AuthColors.success
                              : AuthColors.textSub,
                          fontSize: 13,
                          fontWeight: includeGstInTotal
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      '₹${gstAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: includeGstInTotal
                            ? AuthColors.success
                            : AuthColors.textSub,
                        fontSize: 14,
                        fontWeight: includeGstInTotal
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              Divider(
                color: AuthColors.textMain.withOpacity(0.1),
                height: AppSpacing.paddingLG,
                thickness: 1,
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              // Total
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Total',
                      style: TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingLG),

          // Trip Information
          _InfoCard(
            title: 'Trip Information',
            children: [
              _InfoRow(
                label: 'Date',
                value: formatDate(scheduledDate),
              ),
              if (slot != null)
                _InfoRow(
                  label: 'Slot',
                  value: 'Slot $slot',
                ),
              _InfoRow(
                label: 'Address',
                value: address,
              ),
              if (city.isNotEmpty)
                _InfoRow(
                  label: 'City',
                  value: city,
                ),
            ],
          ),
          SizedBox(
              height:
                  MediaQuery.of(context).padding.bottom + AppSpacing.paddingXL),
        ],
      ),
    );
  }
}

// Payments Tab
class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({
    required this.trip,
    required this.tripPricing,
  });

  final Map<String, dynamic> trip;
  final Map<String, dynamic> tripPricing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      child: _buildPaymentSummary(context),
    );
  }

  Widget _buildPaymentSummary(BuildContext context) {
    final paymentType = (trip['paymentType'] as String?)?.toLowerCase() ?? '';
    if (paymentType.isEmpty) {
      return const _InfoCard(
        title: 'Payments',
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.paddingXL),
              child: Text(
                'No payment information available',
                style: TextStyle(
                  color: AuthColors.textSub,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final tripTotal = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
    final paymentDetails = (trip['paymentDetails'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final totalPaidStored = (trip['totalPaidOnReturn'] as num?)?.toDouble();
    final computedPaid = paymentDetails.fold<double>(
      0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
    );
    final totalPaid = totalPaidStored ?? computedPaid;
    final remainingStored = (trip['remainingAmount'] as num?)?.toDouble();
    final remaining = remainingStored ?? (tripTotal - totalPaid);
    final status = (trip['paymentStatus'] as String?) ??
        (remaining <= 0.001
            ? 'full'
            : totalPaid > 0
                ? 'partial'
                : 'pending');

    Color statusColor() {
      switch (status.toLowerCase()) {
        case 'full':
          return AuthColors.success;
        case 'partial':
          return AuthColors.info;
        default:
          return AuthColors.textSub;
      }
    }

    return _InfoCard(
      title: 'Payments',
      children: [
        _InfoRow(
          label: 'Payment Type',
          value: paymentType.replaceAll('_', ' ').toUpperCase(),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  'Status',
                  style: TextStyle(
                    color: AuthColors.textMain.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.paddingMD,
                  vertical: AppSpacing.paddingSM,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor().withOpacity(0.25),
                      statusColor().withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                  border: Border.all(
                    color: statusColor().withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor(),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        _InfoRow(
          label: 'Total',
          value: '₹${tripTotal.toStringAsFixed(2)}',
        ),
        _InfoRow(
          label: 'Paid',
          value: '₹${totalPaid.toStringAsFixed(2)}',
          valueColor: totalPaid > 0 ? AuthColors.success : null,
        ),
        if (remaining > 0.001)
          _InfoRow(
            label: 'Remaining',
            value: '₹${remaining.toStringAsFixed(2)}',
            valueColor: AuthColors.warning,
          ),
        if (paymentDetails.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.paddingMD),
          Divider(
            color: AuthColors.textMain.withOpacity(0.1),
            height: AppSpacing.paddingLG,
            thickness: 1,
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          Text(
            'Payment Entries',
            style: TextStyle(
              color: AuthColors.textMain.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          ...paymentDetails.asMap().entries.map((entry) {
            final index = entry.key;
            final p = entry.value;
            final name = p['paymentAccountName'] as String? ?? 'Account';
            final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
            final type = (p['paymentAccountType'] as String?) ?? '';
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < paymentDetails.length - 1
                    ? AppSpacing.paddingMD
                    : 0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: AuthColors.textMain,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (type.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.paddingXS / 2),
                          Text(
                            type.toUpperCase(),
                            style: TextStyle(
                              color: AuthColors.textMain.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ModernTile(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.2),
                      color.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: AppSpacing.iconSM,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          Text(
            value,
            style: AppTypography.h3.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingXS / 2),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AuthColors.textSub,
            ),
          ),
        ],
      ),
    );
  }
}
