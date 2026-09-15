import 'package:cloud_firestore/cloud_firestore.dart';

class PropertyModel {
  final String id;
  final String name;
  final String? brandName;
  final String? tagline;
  final String address;
  final String ownerUid;
  final String defaultCurrency;
  final String? logoAssetRef;
  final String? logoBase64;
  final String? primaryColorHex;
  final String? accentColorHex;
  final String? backgroundColorHex;
  final String? contactPhone;
  final String? whatsappNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  PropertyModel({
    required this.id,
    required this.name,
    this.brandName,
    this.tagline,
    required this.address,
    required this.ownerUid,
    this.defaultCurrency = 'INR',
    this.logoAssetRef,
    this.logoBase64,
    this.primaryColorHex = '083B4C',
    this.accentColorHex = 'C58B2B',
    this.backgroundColorHex = '041B23',
    this.contactPhone,
    this.whatsappNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  String get effectiveBrandName => (brandName != null && brandName!.trim().isNotEmpty) ? brandName!.trim() : name;

  factory PropertyModel.fromMap(Map<String, dynamic> map, String docId) {
    return PropertyModel(
      id: docId,
      name: map['name'] ?? '',
      brandName: map['brandName'],
      tagline: map['tagline'],
      address: map['address'] ?? '',
      ownerUid: map['ownerUid'] ?? '',
      defaultCurrency: map['defaultCurrency'] ?? 'INR',
      logoAssetRef: map['logoAssetRef'],
      logoBase64: map['logoBase64'],
      primaryColorHex: map['primaryColorHex'] ?? '083B4C',
      accentColorHex: map['accentColorHex'] ?? 'C58B2B',
      backgroundColorHex: map['backgroundColorHex'] ?? '041B23',
      contactPhone: map['contactPhone'],
      whatsappNumber: map['whatsappNumber'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brandName': brandName ?? name,
      'tagline': tagline,
      'address': address,
      'ownerUid': ownerUid,
      'defaultCurrency': defaultCurrency,
      'logoAssetRef': logoAssetRef,
      'logoBase64': logoBase64,
      'primaryColorHex': primaryColorHex,
      'accentColorHex': accentColorHex,
      'backgroundColorHex': backgroundColorHex,
      'contactPhone': contactPhone,
      'whatsappNumber': whatsappNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
