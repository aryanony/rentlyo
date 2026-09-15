import 'package:cloud_firestore/cloud_firestore.dart';

class MessMenuModel {
  final String id;
  final String propertyId;
  final String dayOfWeek; // 'Monday' | 'Tuesday' ...
  final String breakfast;
  final String lunch;
  final String snacks;
  final String dinner;
  final DateTime updatedAt;

  MessMenuModel({
    required this.id,
    required this.propertyId,
    required this.dayOfWeek,
    required this.breakfast,
    required this.lunch,
    required this.snacks,
    required this.dinner,
    required this.updatedAt,
  });

  factory MessMenuModel.fromMap(Map<String, dynamic> map, String docId) {
    return MessMenuModel(
      id: docId,
      propertyId: map['propertyId'] ?? '',
      dayOfWeek: map['dayOfWeek'] ?? 'Monday',
      breakfast: map['breakfast'] ?? '',
      lunch: map['lunch'] ?? '',
      snacks: map['snacks'] ?? '',
      dinner: map['dinner'] ?? '',
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'dayOfWeek': dayOfWeek,
      'breakfast': breakfast,
      'lunch': lunch,
      'snacks': snacks,
      'dinner': dinner,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
