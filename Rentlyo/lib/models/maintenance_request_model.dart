import 'package:cloud_firestore/cloud_firestore.dart';

class MaintenanceRequestModel {
  final String id;
  final String propertyId;
  final String unitId;
  final String renterUid;
  final String? renterId; // Stable ID
  final String renterName;
  final String renterPhone;
  final String title;
  final String description;
  final String category; // 'plumbing' | 'electrical' | 'structural' | 'cleaning' | 'general'
  final String priority; // 'low' | 'medium' | 'high' | 'emergency'
  final String status; // 'open' | 'in-progress' | 'resolved' | 'closed'
  final String? adminNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  MaintenanceRequestModel({
    required this.id,
    required this.propertyId,
    required this.unitId,
    required this.renterUid,
    this.renterId,
    required this.renterName,
    required this.renterPhone,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.adminNote,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MaintenanceRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return MaintenanceRequestModel(
      id: docId,
      propertyId: map['propertyId'] ?? '',
      unitId: map['unitId'] ?? '',
      renterUid: map['renterUid'] ?? '',
      renterId: map['renterId'],
      renterName: map['renterName'] ?? 'Tenant',
      renterPhone: map['renterPhone'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'general',
      priority: map['priority'] ?? 'medium',
      status: map['status'] ?? 'open',
      adminNote: map['adminNote'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'unitId': unitId,
      'renterUid': renterUid,
      'renterId': renterId ?? renterUid,
      'renterName': renterName,
      'renterPhone': renterPhone,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'status': status,
      'adminNote': adminNote,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
