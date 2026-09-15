import 'package:cloud_firestore/cloud_firestore.dart';

class RentScheduleItem {
  final DateTime effectiveFromDate;
  final double monthlyRent;

  RentScheduleItem({
    required this.effectiveFromDate,
    required this.monthlyRent,
  });

  factory RentScheduleItem.fromMap(Map<String, dynamic> map) {
    DateTime date;
    if (map['effectiveFromDate'] != null && map['effectiveFromDate'] is Timestamp) {
      date = (map['effectiveFromDate'] as Timestamp).toDate();
    } else if (map['effectiveFromMonth'] != null) {
      date = DateTime(2020, (map['effectiveFromMonth'] as int), 1);
    } else {
      date = DateTime.now();
    }
    return RentScheduleItem(
      effectiveFromDate: date,
      monthlyRent: (map['monthlyRent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'effectiveFromDate': Timestamp.fromDate(effectiveFromDate),
      'monthlyRent': monthlyRent,
    };
  }
}

class UnitHistoryItem {
  final String unitId;
  final String? unitLabel;
  final DateTime fromDate;
  final DateTime? toDate;

  UnitHistoryItem({
    required this.unitId,
    this.unitLabel,
    required this.fromDate,
    this.toDate,
  });

  factory UnitHistoryItem.fromMap(Map<String, dynamic> map) {
    return UnitHistoryItem(
      unitId: map['unitId'] ?? '',
      unitLabel: map['unitLabel'] ?? map['label'],
      fromDate: (map['fromDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      toDate: (map['toDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'unitId': unitId,
      'unitLabel': unitLabel,
      'fromDate': Timestamp.fromDate(fromDate),
      'toDate': toDate != null ? Timestamp.fromDate(toDate!) : null,
    };
  }

  String get displayLabel {
    if (unitLabel != null && unitLabel!.trim().isNotEmpty && !unitLabel!.startsWith('unit_') && unitLabel!.length <= 15) {
      return unitLabel!.trim();
    }
    if (unitId.isNotEmpty && !unitId.startsWith('unit_') && unitId.length <= 15) {
      return unitId.trim();
    }
    return 'G7';
  }
}

class AdvanceTransactionItem {
  final DateTime date;
  final double amount;
  final String? note;

  AdvanceTransactionItem({
    required this.date,
    required this.amount,
    this.note,
  });

  factory AdvanceTransactionItem.fromMap(Map<String, dynamic> map) {
    return AdvanceTransactionItem(
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'note': note,
    };
  }
}

class AmenityItem {
  final String name;
  final bool applicable;
  final String? notes;

  AmenityItem({
    required this.name,
    required this.applicable,
    this.notes,
  });

  factory AmenityItem.fromMap(Map<String, dynamic> map) {
    return AmenityItem(
      name: map['name'] ?? '',
      applicable: map['applicable'] ?? true,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'applicable': applicable,
      'notes': notes,
    };
  }
}

class DealModel {
  final String id;
  final String propertyId;
  final String currentUnitId;
  final String renterId; // Stable ID
  final String renterType;
  final DateTime dealStartDate;
  final List<RentScheduleItem> rentSchedule;
  final int rentDueDayOfMonth; // 1 to 28
  final List<AdvanceTransactionItem> advanceTransactions;
  final bool advanceConsumptionMode;
  final String? advanceDeductStartMonth;
  final String? advanceDeductEndMonth;
  final List<UnitHistoryItem> unitHistory;
  final List<AmenityItem> amenities;
  final bool carryForwardPendingBalance;
  final String agreementType; // 'upload' | 'drive-link'
  final String? agreementFileBase64;
  final String? agreementDriveLink;
  final String status; // 'active' | 'ended'
  final DateTime? dealEndDate;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? businessName;
  final String? businessCategory;
  final int? occupantCount;
  final bool? maintenanceIncluded;
  final String? unitLabel;
  final String? unitCode;
  final List<String> assignedUnitIds;
  final List<String> assignedUnitLabels;
  final double? advanceRefundAmount;
  final DateTime? advanceRefundDate;
  final String? advanceRefundNote;

  DealModel({
    required this.id,
    required this.propertyId,
    required this.currentUnitId,
    required this.renterId,
    required this.renterType,
    required this.dealStartDate,
    required this.rentSchedule,
    this.rentDueDayOfMonth = 1,
    required this.advanceTransactions,
    required this.advanceConsumptionMode,
    this.advanceDeductStartMonth,
    this.advanceDeductEndMonth,
    required this.unitHistory,
    this.amenities = const [],
    required this.carryForwardPendingBalance,
    this.agreementType = 'upload',
    this.agreementFileBase64,
    this.agreementDriveLink,
    required this.status,
    this.dealEndDate,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.businessName,
    this.businessCategory,
    this.occupantCount,
    this.maintenanceIncluded,
    this.unitLabel,
    this.unitCode,
    this.assignedUnitIds = const [],
    this.assignedUnitLabels = const [],
    this.advanceRefundAmount,
    this.advanceRefundDate,
    this.advanceRefundNote,
  });

  // Getter for unitId (backward compatibility)
  String get unitId => currentUnitId;
  DateTime get startDate => dealStartDate;
  double get startingRent => baseMonthlyRent;
  String get renterUserId => renterId;

  bool get isMultiUnit => multiUnitLabelsList.length > 1;

  List<String> get multiUnitLabelsList {
    if (assignedUnitLabels.isNotEmpty) return assignedUnitLabels;
    if (unitLabel != null && unitLabel!.trim().isNotEmpty && unitLabel!.trim().toLowerCase() != 'unit') {
      final tokens = unitLabel!.split(RegExp(r'[,\+&]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (tokens.length > 1) return tokens;
    }
    if (assignedUnitIds.length > 1) return assignedUnitIds;
    return [displayUnitCode];
  }

  String get displayMultiUnitLabel {
    final list = multiUnitLabelsList;
    if (list.length > 1) {
      return list.join(', ');
    }
    if (unitLabel != null && unitLabel!.trim().isNotEmpty && unitLabel!.trim().toLowerCase() != 'unit' && unitLabel!.length <= 25) {
      return unitLabel!.trim();
    }
    if (businessName != null && businessName!.trim().isNotEmpty) {
      return businessName!.trim();
    }
    if (unitCode != null && unitCode!.trim().isNotEmpty) {
      return unitCode!.trim();
    }
    if (currentUnitId.isNotEmpty && !currentUnitId.startsWith('unit_') && currentUnitId.length <= 10) {
      return currentUnitId.trim();
    }
    return displayUnitCode;
  }

  bool containsUnit(String idOrLabel) {
    final clean = idOrLabel.toLowerCase().trim();
    if (clean.isEmpty) return false;
    final cleanNoUnit = clean.startsWith('unit ') ? clean.substring(5).trim() : clean;
    if (currentUnitId.toLowerCase().trim() == clean || currentUnitId.toLowerCase().trim() == cleanNoUnit) return true;
    if (unitLabel != null && (unitLabel!.toLowerCase().trim() == clean || unitLabel!.toLowerCase().trim() == cleanNoUnit)) return true;
    if (unitCode != null && (unitCode!.toLowerCase().trim() == clean || unitCode!.toLowerCase().trim() == cleanNoUnit)) return true;
    if (assignedUnitIds.any((u) => u.toLowerCase().trim() == clean || u.toLowerCase().trim() == cleanNoUnit)) return true;
    if (assignedUnitLabels.any((u) => u.toLowerCase().trim() == clean || u.toLowerCase().trim() == cleanNoUnit)) return true;
    final parts = (unitLabel ?? '').split(RegExp(r'[,\+&\s]+')).map((s) => s.toLowerCase().trim());
    if (parts.contains(clean) || parts.contains(cleanNoUnit)) return true;
    for (var p in parts) {
      if (p == clean || p == cleanNoUnit || p == 'unit $clean' || clean == 'unit $p') return true;
    }
    return false;
  }

  // Catchy human-readable unit code getter (prevents "Unit Unit" duplication)
  String get displayUnitCode {
    String raw = '';
    if (unitCode != null && unitCode!.trim().isNotEmpty && unitCode!.trim().toLowerCase() != 'unit') {
      raw = unitCode!.trim();
    } else if (unitLabel != null && unitLabel!.trim().isNotEmpty && unitLabel!.trim().toLowerCase() != 'unit') {
      raw = unitLabel!.trim();
    } else if (businessName != null && businessName!.trim().isNotEmpty) {
      raw = businessName!.trim();
    } else if (currentUnitId.isNotEmpty && !currentUnitId.startsWith('unit_') && currentUnitId.length <= 10) {
      raw = currentUnitId.trim();
    } else {
      raw = 'G7';
    }

    if (raw.toLowerCase().startsWith('unit ')) {
      return raw.substring(5).trim();
    }
    return raw;
  }

  String get displayUnitLabel {
    final code = displayUnitCode;
    if (code.toLowerCase().startsWith('unit ')) return code;
    return 'Unit $code';
  }

  // Getter for total advance amount
  double get totalAdvanceAmount => advanceTransactions.fold(0.0, (acc, item) => acc + item.amount);
  double get advanceAmount => totalAdvanceAmount; // backward compatibility

  // Getter for baseMonthlyRent (the starting rent)
  double get baseMonthlyRent {
    if (rentSchedule.isEmpty) return 0.0;
    final sorted = List<RentScheduleItem>.from(rentSchedule)
      ..sort((a, b) => a.effectiveFromDate.compareTo(b.effectiveFromDate));
    return sorted.first.monthlyRent;
  }

  factory DealModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime startDate = (map['dealStartDate'] as Timestamp?)?.toDate() ??
        (map['startDate'] as Timestamp?)?.toDate() ??
        (map['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.now();

    List<RentScheduleItem> schedule = [];
    if (map['rentSchedule'] != null && (map['rentSchedule'] as List).isNotEmpty) {
      schedule = (map['rentSchedule'] as List).map((item) {
        final m = Map<String, dynamic>.from(item);
        // Backward compat: if old data has effectiveFromMonth (int) but no effectiveFromDate
        if (m['effectiveFromDate'] == null && m['effectiveFromMonth'] != null) {
          int monthIdx = (m['effectiveFromMonth'] as int) - 1; // 0-indexed offset
          DateTime date = DateTime(startDate.year, startDate.month + monthIdx, startDate.day);
          m['effectiveFromDate'] = Timestamp.fromDate(date);
        }
        return RentScheduleItem.fromMap(m);
      }).toList();
    } else {
      double baseRent = (map['baseMonthlyRent'] as num?)?.toDouble() ?? 0.0;
      schedule = [RentScheduleItem(effectiveFromDate: startDate, monthlyRent: baseRent)];
    }
    schedule.sort((a, b) => a.effectiveFromDate.compareTo(b.effectiveFromDate));

    // Align dealStartDate to earliest rent schedule start if schedule starts earlier
    if (schedule.isNotEmpty && schedule.first.effectiveFromDate.isBefore(startDate)) {
      startDate = schedule.first.effectiveFromDate;
    }

    // Unit History mapping
    List<UnitHistoryItem> uHist = [];
    if (map['unitHistory'] != null && (map['unitHistory'] as List).isNotEmpty) {
      uHist = (map['unitHistory'] as List)
          .map((item) => UnitHistoryItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } else {
      String uid = map['currentUnitId'] ?? map['unitId'] ?? '';
      uHist = [UnitHistoryItem(unitId: uid, fromDate: startDate, toDate: null)];
    }

    // Advance Transactions mapping & Reconciliation with advanceAmount
    List<AdvanceTransactionItem> advTx = [];
    if (map['advanceTransactions'] != null && (map['advanceTransactions'] as List).isNotEmpty) {
      advTx = (map['advanceTransactions'] as List)
          .map((item) => AdvanceTransactionItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    double docAdvanceAmount = (map['advanceAmount'] as num?)?.toDouble() ?? 0.0;
    double advTxSum = advTx.fold(0.0, (acc, item) => acc + item.amount);

    if (docAdvanceAmount > advTxSum) {
      double diff = docAdvanceAmount - advTxSum;
      advTx.add(AdvanceTransactionItem(
        date: startDate,
        amount: diff,
        note: advTx.isEmpty ? 'Initial Move-in Advance' : 'Advance Security Deposit Adjustment',
      ));
    } else if (advTx.isEmpty && docAdvanceAmount > 0) {
      advTx = [
        AdvanceTransactionItem(
          date: startDate,
          amount: docAdvanceAmount,
          note: 'Initial Move-in Advance',
        )
      ];
    }

    // Amenities mapping
    List<AmenityItem> amens = [];
    if (map['amenities'] != null && (map['amenities'] as List).isNotEmpty) {
      amens = (map['amenities'] as List)
          .map((item) => AmenityItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    String rawRenterType = (map['renterType'] ?? map['unitType'] ?? map['type'] ?? '').toString().toLowerCase().trim();
    if (rawRenterType.isEmpty) {
      String labelStr = (map['unitLabel'] ?? map['unitCode'] ?? map['businessName'] ?? '').toString().toLowerCase().trim();
      if (labelStr.contains('room') || labelStr.contains('flat') || labelStr.contains('apartment') || labelStr.contains('pg') || labelStr.contains('residential')) {
        rawRenterType = 'residential';
      } else {
        rawRenterType = 'commercial';
      }
    }

    final rawUIds = map['assignedUnitIds'];
    List<String> parsedUIds = rawUIds is List ? List<String>.from(rawUIds) : [];
    if (parsedUIds.isEmpty && map['currentUnitId'] != null && (map['currentUnitId'] as String).isNotEmpty) {
      parsedUIds.add(map['currentUnitId']);
    }

    final rawULabels = map['assignedUnitLabels'];
    List<String> parsedULabels = rawULabels is List ? List<String>.from(rawULabels) : [];
    if (map['unitLabel'] != null && (map['unitLabel'] as String).isNotEmpty) {
      final splitStr = map['unitLabel'] as String;
      final tokens = splitStr.split(RegExp(r'[,\+&]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      for (var t in tokens) {
        if (!parsedULabels.contains(t)) parsedULabels.add(t);
      }
    }

    return DealModel(
      id: docId,
      propertyId: map['propertyId'] ?? '',
      currentUnitId: map['currentUnitId'] ?? map['unitId'] ?? '',
      renterId: map['renterId'] ?? map['renterUid'] ?? '',
      renterType: rawRenterType,
      dealStartDate: startDate,
      rentSchedule: schedule,
      rentDueDayOfMonth: map['rentDueDayOfMonth'] ?? map['dueDayOfMonth'] ?? 1,
      advanceTransactions: advTx,
      advanceConsumptionMode: map['advanceConsumptionMode'] ?? false,
      advanceDeductStartMonth: map['advanceDeductStartMonth'],
      advanceDeductEndMonth: map['advanceDeductEndMonth'],
      unitHistory: uHist,
      amenities: amens,
      carryForwardPendingBalance: map['carryForwardPendingBalance'] ?? true,
      agreementType: map['agreementType'] ?? (map['agreementDriveLink'] != null || map['agreementPdfUrl'] != null ? 'drive-link' : 'upload'),
      agreementFileBase64: map['agreementFileBase64'],
      agreementDriveLink: map['agreementDriveLink'] ?? map['agreementPdfUrl'],
      status: map['status'] ?? 'active',
      dealEndDate: (map['dealEndDate'] as Timestamp?)?.toDate(),
      notes: map['notes'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      businessName: map['businessName'],
      businessCategory: map['businessCategory'],
      occupantCount: map['occupantCount'],
      maintenanceIncluded: map['maintenanceIncluded'],
      unitLabel: map['unitLabel'],
      unitCode: map['unitCode'],
      assignedUnitIds: parsedUIds,
      assignedUnitLabels: parsedULabels,
      advanceRefundAmount: (map['advanceRefundAmount'] as num?)?.toDouble(),
      advanceRefundDate: (map['advanceRefundDate'] as Timestamp?)?.toDate(),
      advanceRefundNote: map['advanceRefundNote'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'currentUnitId': currentUnitId,
      'unitId': currentUnitId,
      'renterId': renterId,
      'renterType': renterType,
      'dealStartDate': Timestamp.fromDate(dealStartDate),
      'rentSchedule': rentSchedule.map((s) => s.toMap()).toList(),
      'rentDueDayOfMonth': rentDueDayOfMonth,
      'advanceTransactions': advanceTransactions.map((t) => t.toMap()).toList(),
      'advanceConsumptionMode': advanceConsumptionMode,
      'advanceDeductStartMonth': advanceDeductStartMonth,
      'advanceDeductEndMonth': advanceDeductEndMonth,
      'unitHistory': unitHistory.map((h) => h.toMap()).toList(),
      'amenities': amenities.map((a) => a.toMap()).toList(),
      'carryForwardPendingBalance': carryForwardPendingBalance,
      'agreementType': agreementType,
      'agreementFileBase64': agreementFileBase64,
      'agreementDriveLink': agreementDriveLink,
      'status': status,
      'dealEndDate': dealEndDate != null ? Timestamp.fromDate(dealEndDate!) : null,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'businessName': businessName,
      'businessCategory': businessCategory,
      'occupantCount': occupantCount,
      'maintenanceIncluded': maintenanceIncluded,
      'unitLabel': unitLabel,
      'unitCode': unitCode,
      'assignedUnitIds': assignedUnitIds,
      'assignedUnitLabels': assignedUnitLabels,
      'advanceRefundAmount': advanceRefundAmount,
      'advanceRefundDate': advanceRefundDate != null ? Timestamp.fromDate(advanceRefundDate!) : null,
      'advanceRefundNote': advanceRefundNote,
      'baseMonthlyRent': baseMonthlyRent,
      'advanceAmount': totalAdvanceAmount,
    };
  }
}
