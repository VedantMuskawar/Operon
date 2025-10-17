import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Subscription extends Equatable {
  final String subscriptionId;
  final String tier;
  final String subscriptionType;
  final DateTime startDate;
  final DateTime endDate;
  final int userLimit;
  final String status;
  final double amount;
  final String currency;
  final bool isActive;
  final bool autoRenew;
  final DateTime createdDate;
  final DateTime updatedDate;

  const Subscription({
    required this.subscriptionId,
    required this.tier,
    required this.subscriptionType,
    required this.startDate,
    required this.endDate,
    required this.userLimit,
    required this.status,
    required this.amount,
    required this.currency,
    required this.isActive,
    required this.autoRenew,
    required this.createdDate,
    required this.updatedDate,
  });

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      subscriptionId: map['subscriptionId'] ?? '',
      tier: map['tier'] ?? 'basic',
      subscriptionType: map['subscriptionType'] ?? 'monthly',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      userLimit: map['userLimit'] ?? 10,
      status: map['status'] ?? 'active',
      amount: (map['amount'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? 'INR',
      isActive: map['isActive'] ?? true,
      autoRenew: map['autoRenew'] ?? false,
      createdDate: (map['createdDate'] as Timestamp).toDate(),
      updatedDate: (map['updatedDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subscriptionId': subscriptionId,
      'tier': tier,
      'subscriptionType': subscriptionType,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'userLimit': userLimit,
      'status': status,
      'amount': amount,
      'currency': currency,
      'isActive': isActive,
      'autoRenew': autoRenew,
      'createdDate': Timestamp.fromDate(createdDate),
      'updatedDate': Timestamp.fromDate(updatedDate),
    };
  }

  Subscription copyWith({
    String? subscriptionId,
    String? tier,
    String? subscriptionType,
    DateTime? startDate,
    DateTime? endDate,
    int? userLimit,
    String? status,
    double? amount,
    String? currency,
    bool? isActive,
    bool? autoRenew,
    DateTime? createdDate,
    DateTime? updatedDate,
  }) {
    return Subscription(
      subscriptionId: subscriptionId ?? this.subscriptionId,
      tier: tier ?? this.tier,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      userLimit: userLimit ?? this.userLimit,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      autoRenew: autoRenew ?? this.autoRenew,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
    );
  }

  bool get isExpired => endDate.isBefore(DateTime.now());
  bool get isExpiringSoon => endDate.difference(DateTime.now()).inDays <= 7;

  @override
  List<Object?> get props => [
        subscriptionId,
        tier,
        subscriptionType,
        startDate,
        endDate,
        userLimit,
        status,
        amount,
        currency,
        isActive,
        autoRenew,
        createdDate,
        updatedDate,
      ];
}

enum SubscriptionTier {
  basic('basic', 'Basic'),
  premium('premium', 'Premium'),
  enterprise('enterprise', 'Enterprise');

  const SubscriptionTier(this.value, this.displayName);
  final String value;
  final String displayName;
}

enum SubscriptionType {
  monthly('monthly', 'Monthly'),
  yearly('yearly', 'Yearly');

  const SubscriptionType(this.value, this.displayName);
  final String value;
  final String displayName;
}

enum SubscriptionStatus {
  active('active', 'Active'),
  expired('expired', 'Expired'),
  cancelled('cancelled', 'Cancelled');

  const SubscriptionStatus(this.value, this.displayName);
  final String value;
  final String displayName;
}
