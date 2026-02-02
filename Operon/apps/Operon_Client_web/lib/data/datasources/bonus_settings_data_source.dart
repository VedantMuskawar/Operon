import 'package:cloud_firestore/cloud_firestore.dart';

/// One bonus tier: e.g. "for 23 days → 3000", "for 25 days → 5000".
class BonusTier {
  const BonusTier({
    required this.minDays,
    required this.amount,
  });

  final int minDays;
  final double amount;

  Map<String, dynamic> toJson() {
    return {
      'minDays': minDays,
      'amount': amount,
    };
  }

  factory BonusTier.fromJson(Map<String, dynamic> json) {
    return BonusTier(
      minDays: json['minDays'] as int? ?? json['minDaysPresent'] as int? ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? (json['bonusAmount'] as num?)?.toDouble() ?? 0,
    );
  }

  BonusTier copyWith({int? minDays, double? amount}) {
    return BonusTier(
      minDays: minDays ?? this.minDays,
      amount: amount ?? this.amount,
    );
  }
}

/// Per-role bonus: multiple tiers. Employee gets the highest tier where daysPresent >= tier.minDays.
class RoleBonusSetting {
  const RoleBonusSetting({
    required this.tiers,
  });

  final List<BonusTier> tiers;

  /// Legacy: single minDays + bonusAmount (for backward compatibility).
  int get minDaysPresent => tiers.isEmpty ? 0 : tiers.map((t) => t.minDays).reduce((a, b) => a > b ? a : b);
  double get bonusAmount => tiers.isEmpty ? 0 : tiers.map((t) => t.amount).reduce((a, b) => a > b ? a : b);

  /// Resolve bonus for given days present: best tier where daysPresent >= tier.minDays (highest such minDays wins).
  double resolveAmount(int daysPresent) {
    if (tiers.isEmpty) return 0;
    BonusTier? best;
    for (final t in tiers) {
      if (daysPresent >= t.minDays && (best == null || t.minDays > best.minDays)) {
        best = t;
      }
    }
    return best?.amount ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'tiers': tiers.map((t) => t.toJson()).toList(),
    };
  }

  factory RoleBonusSetting.fromJson(Map<String, dynamic> json) {
    final tiersList = json['tiers'] as List<dynamic>?;
    if (tiersList != null && tiersList.isNotEmpty) {
      final tiers = tiersList
          .map((e) => BonusTier.fromJson(e as Map<String, dynamic>))
          .toList();
      return RoleBonusSetting(tiers: tiers);
    }
    // Legacy: single minDaysPresent / bonusAmount
    final minDays = json['minDaysPresent'] as int? ?? 0;
    final amount = (json['bonusAmount'] as num?)?.toDouble() ?? 0;
    return RoleBonusSetting(tiers: minDays > 0 || amount > 0 ? [BonusTier(minDays: minDays, amount: amount)] : []);
  }
}

/// Bonus settings for an organization: map of jobRoleId -> RoleBonusSetting.
class BonusSettings {
  const BonusSettings({
    required this.roleSettings,
    this.updatedAt,
    this.updatedBy,
  });

  final Map<String, RoleBonusSetting> roleSettings;
  final DateTime? updatedAt;
  final String? updatedBy;

  Map<String, dynamic> toJson() {
    return {
      'roleSettings': roleSettings.map(
        (k, v) => MapEntry(k, v.toJson()),
      ),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  factory BonusSettings.fromJson(Map<String, dynamic> json) {
    final roleSettingsRaw = json['roleSettings'] as Map<String, dynamic>? ?? {};
    final roleSettings = roleSettingsRaw.map(
      (k, v) => MapEntry(k, RoleBonusSetting.fromJson(v as Map<String, dynamic>)),
    );
    return BonusSettings(
      roleSettings: roleSettings,
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: json['updatedBy'] as String?,
    );
  }
}

/// Data source for ORGANIZATIONS/{organizationId}/BONUS_SETTINGS.
/// Single document per org (doc id: 'default').
class BonusSettingsDataSource {
  BonusSettingsDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _docId = 'default';

  DocumentReference<Map<String, dynamic>> _settingsRef(String orgId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('BONUS_SETTINGS')
        .doc(_docId);
  }

  Future<BonusSettings?> fetch(String organizationId) async {
    final doc = await _settingsRef(organizationId).get();
    if (!doc.exists || doc.data() == null) return null;
    return BonusSettings.fromJson(doc.data()!);
  }

  Future<void> save({
    required String organizationId,
    required BonusSettings settings,
    String? updatedBy,
  }) async {
    final data = settings.toJson();
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (updatedBy != null) data['updatedBy'] = updatedBy;
    await _settingsRef(organizationId).set(data, SetOptions(merge: true));
  }
}
