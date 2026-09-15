import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String toUid;
  final String propertyId;
  final String type; // 'rent-cycle-start' | 'rent-overdue-warning' | 'payment-confirmed' | 'payment-request' | 'notice' | 'maintenance'
  final String title;
  final String message;
  final String priority; // 'gentle' | 'info' | 'warning' | 'urgent'
  final String? relatedRecordId;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.toUid,
    required this.propertyId,
    required this.type,
    this.title = '',
    required this.message,
    this.priority = 'info',
    this.relatedRecordId,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String docId) {
    return NotificationModel(
      id: docId,
      toUid: map['toUid'] ?? '',
      propertyId: map['propertyId'] ?? '',
      type: map['type'] ?? 'payment-request',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      priority: map['priority'] ?? 'info',
      relatedRecordId: map['relatedRecordId'],
      read: map['read'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'toUid': toUid,
      'propertyId': propertyId,
      'type': type,
      'title': title,
      'message': message,
      'priority': priority,
      'relatedRecordId': relatedRecordId,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
