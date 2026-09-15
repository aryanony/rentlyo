import 'package:cloud_firestore/cloud_firestore.dart';

class UtilityBillModel {
  final String id;
  final String propertyId;
  final String unitId;
  final String dealId;
  final String renterId;
  final String periodMonth; // e.g. "2026-08"
  final String utilityType; // 'electricity' | 'water' | 'maintenance' | 'gas' | 'other'
  final double previousReading;
  final double currentReading;
  final double unitRate;
  final double netAmount;
  final String notes;
  final DateTime createdAt;

  UtilityBillModel({
    required this.id,
    required this.propertyId,
    required this.unitId,
    required this.dealId,
    required this.renterId,
    required this.periodMonth,
    required this.utilityType,
    required this.previousReading,
    required this.currentReading,
    required this.unitRate,
    required this.netAmount,
    required this.notes,
    required this.createdAt,
  });

  factory UtilityBillModel.fromMap(Map<String, dynamic> map, String docId) {
    return UtilityBillModel(
      id: docId,
      propertyId: map['propertyId'] ?? '',
      unitId: map['unitId'] ?? '',
      dealId: map['dealId'] ?? '',
      renterId: map['renterId'] ?? map['renterUid'] ?? '',
      periodMonth: map['periodMonth'] ?? '',
      utilityType: map['utilityType'] ?? 'electricity',
      previousReading: (map['previousReading'] as num?)?.toDouble() ?? 0.0,
      currentReading: (map['currentReading'] as num?)?.toDouble() ?? 0.0,
      unitRate: (map['unitRate'] as num?)?.toDouble() ?? 0.0,
      netAmount: (map['netAmount'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'unitId': unitId,
      'dealId': dealId,
      'renterId': renterId,
      'renterUid': renterId,
      'periodMonth': periodMonth,
      'utilityType': utilityType,
      'previousReading': previousReading,
      'currentReading': currentReading,
      'unitRate': unitRate,
      'netAmount': netAmount,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
