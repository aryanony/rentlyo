class UnitModel {
  final String id;
  final String propertyId;
  final String label; // e.g. "Shop 1" / "Flat 101" / "Bed A-1"
  final String type; // 'commercial' | 'residential' | 'pg_hostel'
  final String category; // 'shop' | 'flat' | 'pg_bed' | 'room'
  final String floor; // "Ground", "1st", etc.
  final double? sizeSqft;
  final int sharingCapacity; // 1 = Single/Private, 2 = Double, 3 = Triple
  final String? bedNumber;
  final String status; // 'occupied' | 'vacant'

  UnitModel({
    required this.id,
    required this.propertyId,
    required this.label,
    required this.type,
    String? category,
    required this.floor,
    this.sizeSqft,
    this.sharingCapacity = 1,
    this.bedNumber,
    required this.status,
  }) : category = (category != null && category.isNotEmpty)
            ? category
            : (type == 'commercial' ? 'shop' : 'flat');

  factory UnitModel.fromMap(Map<String, dynamic> map, String docId) {
    String rawType = (map['type'] ?? '').toString().toLowerCase().trim();
    String rawCat = (map['category'] ?? '').toString().toLowerCase().trim();
    String labelStr = (map['label'] ?? '').toString().toLowerCase().trim();

    if (rawType.isEmpty) {
      if (rawCat == 'flat' || rawCat == 'room' || rawCat == 'pg_bed' || labelStr.contains('room') || labelStr.contains('flat') || labelStr.contains('bed')) {
        rawType = 'residential';
      } else if (rawCat == 'shop' || labelStr.contains('shop') || labelStr.contains('store')) {
        rawType = 'commercial';
      } else {
        rawType = 'commercial';
      }
    }

    if (rawCat.isEmpty) {
      rawCat = rawType == 'commercial' ? 'shop' : 'flat';
    } else if (rawType == 'commercial' && rawCat == 'flat') {
      rawCat = 'shop';
    } else if (rawType == 'residential' && rawCat == 'shop') {
      rawCat = 'flat';
    }

    return UnitModel(
      id: docId,
      propertyId: map['propertyId'] ?? '',
      label: map['label'] ?? '',
      type: rawType,
      category: rawCat,
      floor: map['floor'] ?? 'Ground',
      sizeSqft: map['sizeSqft'] != null ? (map['sizeSqft'] as num).toDouble() : null,
      sharingCapacity: map['sharingCapacity'] ?? 1,
      bedNumber: map['bedNumber'],
      status: map['status'] ?? 'vacant',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'label': label,
      'type': type,
      'category': category,
      'floor': floor,
      'sizeSqft': sizeSqft,
      'sharingCapacity': sharingCapacity,
      'bedNumber': bedNumber,
      'status': status,
    };
  }

  bool get isCommercial {
    final t = type.toLowerCase().trim();
    final c = category.toLowerCase().trim();
    final l = label.toLowerCase().trim();
    final u = id.toLowerCase().trim();

    if (t == 'commercial') return true;
    if (t == 'residential') return false;

    if (c == 'shop') return true;
    if (c == 'flat' || c == 'room' || c == 'pg_bed') return false;

    if (l.contains('shop') || l.contains('store') || u.contains('shop') || u.contains('store')) {
      return true;
    }
    if (l.contains('flat') || l.contains('room') || l.contains('bed') || u.contains('flat') || u.contains('room') || u.contains('bed')) {
      return false;
    }
    final shopCodeRegex = RegExp(r'^g\-?\d+', caseSensitive: false);
    if (shopCodeRegex.hasMatch(l) || shopCodeRegex.hasMatch(u)) {
      return true;
    }
    return false;
  }
}
