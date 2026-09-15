import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String renterId; // Stable ID that survives login resets
  final String role; // 'owner' | 'renter'
  final String name;
  final String phone;
  final String pseudoEmail;
  final String? renterPassword;
  final List<String> propertyIds;
  final bool active;
  final DateTime createdAt;
  final String? createdBy;

  UserModel({
    required this.uid,
    required this.renterId,
    required this.role,
    required this.name,
    required this.phone,
    required this.pseudoEmail,
    this.renterPassword,
    required this.propertyIds,
    required this.active,
    required this.createdAt,
    this.createdBy,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      renterId: map['renterId'] ?? map['uid'] ?? id,
      role: map['role'] ?? 'renter',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      pseudoEmail: map['pseudoEmail'] ?? '',
      renterPassword: map['renterPassword'],
      propertyIds: List<String>.from(map['propertyIds'] ?? []),
      active: map['active'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'renterId': renterId,
      'role': role,
      'name': name,
      'phone': phone,
      'pseudoEmail': pseudoEmail,
      'renterPassword': renterPassword,
      'propertyIds': propertyIds,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }
}
