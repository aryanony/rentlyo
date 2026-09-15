import 'package:cloud_firestore/cloud_firestore.dart';

class VisitorLogModel {
  final String id;
  final String propertyId;
  final String unitId;
  final String renterId;
  final String renterName;
  final String visitorName;
  final String visitorPhone;
  final DateTime visitDate;
  final String? vehicleNumber;
  final String status; // 'pre-approved' | 'checked-in' | 'completed'
  final DateTime createdAt;

  VisitorLogModel({
    required this.id,
    required this.propertyId,
    required this.unitId,
    required this.renterId,
    required this.renterName,
    required this.visitorName,
    required this.visitorPhone,
    required this.visitDate,
    this.vehicleNumber,
    required this.status,
    required this.createdAt,
  });

  factory VisitorLogModel.fromMap(Map<String, dynamic> map, String docId) {
    return VisitorLogModel(
      id: docId,
      propertyId: map['propertyId'] ?? '',
      unitId: map['unitId'] ?? '',
      renterId: map['renterId'] ?? map['renterUid'] ?? '',
      renterName: map['renterName'] ?? 'Resident',
      visitorName: map['visitorName'] ?? '',
      visitorPhone: map['visitorPhone'] ?? '',
      visitDate: (map['visitDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      vehicleNumber: map['vehicleNumber'],
      status: map['status'] ?? 'pre-approved',
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
      'visitorName': visitorName,
      'visitorPhone': visitorPhone,
      'visitDate': Timestamp.fromDate(visitDate),
      'vehicleNumber': vehicleNumber,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
