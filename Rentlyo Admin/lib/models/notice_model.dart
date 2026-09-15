import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeModel {
  final String id;
  final String propertyId;
  final String title;
  final String message;
  final String type; // 'announcement' | 'maintenance' | 'warning' | 'event'
  final String postedBy;
  final DateTime postedAt;
  final String targetAudience; // 'all' | 'commercial' | 'residential'

  NoticeModel({
    required this.id,
    required this.propertyId,
    required this.title,
    required this.message,
    required this.type,
    required this.postedBy,
    required this.postedAt,
    required this.targetAudience,
  });

  factory NoticeModel.fromMap(Map<String, dynamic> map, String docId) {
    return NoticeModel(
      id: docId,
      propertyId: map['propertyId'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'announcement',
      postedBy: map['postedBy'] ?? 'Management',
      postedAt: (map['postedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      targetAudience: map['targetAudience'] ?? 'all',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'title': title,
      'message': message,
      'type': type,
      'postedBy': postedBy,
      'postedAt': Timestamp.fromDate(postedAt),
      'targetAudience': targetAudience,
    };
  }
}
