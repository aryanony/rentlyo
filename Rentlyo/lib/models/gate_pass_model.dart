import 'package:cloud_firestore/cloud_firestore.dart';

class GatePassModel {
  final String id;
  final String propertyId;
  final String unitId;
  final String renterId;
  final String renterName;
  final String reason;
  final DateTime departureDate;
  final DateTime returnDate;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? adminComment;
  final DateTime createdAt;

  GatePassModel({
    required this.id,
    required this.propertyId,
    required this.unitId,
    required this.renterId,
    required this.renterName,
    required this.reason,
    required this.departureDate,
    required this.returnDate,
    required this.status,
    this.adminComment,
    required this.createdAt,
  });

  factory GatePassModel.fromMap(Map<String, dynamic> map, String docId) {
    return GatePassModel(
      id: docId,
      propertyId: map['propertyId'] ?? '',
      unitId: map['unitId'] ?? '',
      renterId: map['renterId'] ?? map['renterUid'] ?? '',
      renterName: map['renterName'] ?? 'Resident',
      reason: map['reason'] ?? '',
      departureDate: (map['departureDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      returnDate: (map['returnDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
      adminComment: map['adminComment'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'unitId': unitId,
      'renterId': renterId,
      'renterUid': renterId,
      'renterName': renterName,
      'reason': reason,
      'departureDate': Timestamp.fromDate(departureDate),
      'returnDate': Timestamp.fromDate(returnDate),
      'status': status,
      'adminComment': adminComment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
