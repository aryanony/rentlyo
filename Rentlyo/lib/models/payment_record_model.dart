import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentInstallment {
  final double amount;
  final DateTime date;
  final String method; // 'cash' | 'bank' | 'upi'
  final String? note;
  final String addedBy; // 'renter' | 'owner'

  PaymentInstallment({
    required this.amount,
    required this.date,
    required this.method,
    this.note,
    required this.addedBy,
  });

  factory PaymentInstallment.fromMap(Map<String, dynamic> map) {
    return PaymentInstallment(
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      method: map['method'] ?? 'cash',
      note: map['note'],
      addedBy: map['addedBy'] ?? 'renter',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'method': method,
      'note': note,
      'addedBy': addedBy,
    };
  }
}

class PaymentRecordModel {
  final String id;
  final String dealId;
  final String renterId; // Stable ID
  final String propertyId;
  final String unitId;
  final String periodMonth; // "2026-08"
  final int monthIndex; // 1-indexed
  final double effectiveRent;
  final DateTime? dueDate;
  final String paymentSource; // 'advance' | 'direct'
  final double dueFromRenter;
  final double carriedOverDue;
  final List<PaymentInstallment> installments;
  final double totalPaid;
  final double amountPending;
  final String status; // 'adjusted-against-advance' | 'pending' | 'pending-confirmation' | 'confirmed-paid' | 'confirmed-partial' | 'overdue'
  final DateTime? renterSubmittedAt;
  final DateTime? adminConfirmedAt;
  final String? adminConfirmedBy;

  PaymentRecordModel({
    required this.id,
    required this.dealId,
    required this.renterId,
    required this.propertyId,
    required this.unitId,
    required this.periodMonth,
    required this.monthIndex,
    required this.effectiveRent,
    this.dueDate,
    required this.paymentSource,
    required this.dueFromRenter,
    required this.carriedOverDue,
    this.installments = const [],
    required this.totalPaid,
    required this.amountPending,
    required this.status,
    this.renterSubmittedAt,
    this.adminConfirmedAt,
    this.adminConfirmedBy,
  });

  // Backwards compatibility getters
  double get amountPaidByRenter => totalPaid;
  String? get paymentMethod => installments.isNotEmpty ? installments.last.method : null;
  String? get renterNote => installments.isNotEmpty ? installments.last.note : null;

  factory PaymentRecordModel.fromMap(Map<String, dynamic> map, String docId) {
    List<PaymentInstallment> insts = [];
    if (map['installments'] != null && (map['installments'] as List).isNotEmpty) {
      insts = (map['installments'] as List)
          .map((i) => PaymentInstallment.fromMap(Map<String, dynamic>.from(i)))
          .toList();
    } else {
      double oldPaid = (map['amountPaidByRenter'] as num?)?.toDouble() ?? 0.0;
      if (oldPaid > 0) {
        insts = [
          PaymentInstallment(
            amount: oldPaid,
            date: (map['renterSubmittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            method: map['paymentMethod'] ?? 'cash',
            note: map['renterNote'],
            addedBy: 'renter',
          )
        ];
      }
    }

    double computedTotalPaid = insts.fold(0.0, (acc, item) => acc + item.amount);
    if (map['totalPaid'] != null) {
      computedTotalPaid = (map['totalPaid'] as num).toDouble();
    }

    return PaymentRecordModel(
      id: docId,
      dealId: map['dealId'] ?? '',
      renterId: map['renterId'] ?? map['renterUid'] ?? '',
      propertyId: map['propertyId'] ?? '',
      unitId: map['unitId'] ?? '',
      periodMonth: map['periodMonth'] ?? '',
      monthIndex: map['monthIndex'] ?? 1,
      effectiveRent: (map['effectiveRent'] as num?)?.toDouble() ?? 0.0,
      dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
      paymentSource: map['paymentSource'] ?? 'direct',
      dueFromRenter: (map['dueFromRenter'] as num?)?.toDouble() ?? 0.0,
      carriedOverDue: (map['carriedOverDue'] as num?)?.toDouble() ?? 0.0,
      installments: insts,
      totalPaid: computedTotalPaid,
      amountPending: (map['amountPending'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pending',
      renterSubmittedAt: (map['renterSubmittedAt'] as Timestamp?)?.toDate(),
      adminConfirmedAt: (map['adminConfirmedAt'] as Timestamp?)?.toDate(),
      adminConfirmedBy: map['adminConfirmedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dealId': dealId,
      'renterId': renterId,
      'renterUid': renterId, // Compatibility
      'propertyId': propertyId,
      'unitId': unitId,
      'periodMonth': periodMonth,
      'monthIndex': monthIndex,
      'effectiveRent': effectiveRent,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'paymentSource': paymentSource,
      'dueFromRenter': dueFromRenter,
      'carriedOverDue': carriedOverDue,
      'installments': installments.map((i) => i.toMap()).toList(),
      'totalPaid': totalPaid,
      'amountPaidByRenter': totalPaid, // Compatibility
      'amountPending': amountPending,
      'paymentMethod': paymentMethod, // Compatibility
      'renterNote': renterNote, // Compatibility
      'status': status,
      'renterSubmittedAt': renterSubmittedAt != null ? Timestamp.fromDate(renterSubmittedAt!) : null,
      'adminConfirmedAt': adminConfirmedAt != null ? Timestamp.fromDate(adminConfirmedAt!) : null,
      'adminConfirmedBy': adminConfirmedBy,
    };
  }
}
