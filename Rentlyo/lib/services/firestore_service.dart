import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/deal_model.dart';
import '../models/payment_record_model.dart';
import '../models/notification_model.dart';
import '../models/maintenance_request_model.dart';
import '../models/notice_model.dart';
import '../core/app_config.dart';
import '../core/rent_engine.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream current renter user doc
  Stream<UserModel?> streamUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  // Stream single deal by ID
  Stream<DealModel?> streamDealById(String dealId) {
    return _db.collection('deals').doc(dealId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return DealModel.fromMap(doc.data()!, doc.id);
    });
  }

  // Stream deal for renter (by UserModel or uid)
  Stream<DealModel?> streamRenterDeal(dynamic userOrUid, [String? optionalRenterId, String? optionalPhone]) {
    return streamRenterDeals(userOrUid, optionalRenterId, optionalPhone).map((deals) => deals.isNotEmpty ? deals.first : null);
  }

  // Stream all deals for renter using real-time snapshots scoped to the signed-in user
  Stream<List<DealModel>> streamRenterDeals(dynamic userOrUid, [String? optionalRenterId, String? optionalPhone]) {
    String uid = '';
    String renterId = optionalRenterId ?? '';

    if (userOrUid is User) {
      uid = userOrUid.uid;
    } else if (userOrUid is UserModel) {
      uid = userOrUid.uid;
      renterId = userOrUid.renterId;
    } else if (userOrUid is String) {
      uid = userOrUid;
      if (renterId.isEmpty) renterId = uid;
    } else if (userOrUid != null) {
      try {
        uid = (userOrUid as dynamic).uid ?? '';
      } catch (_) {}
    }

    if (uid.isEmpty && renterId.isEmpty) {
      return Stream.value([]);
    }

    // If renterId is known upfront, query directly
    if (renterId.isNotEmpty) {
      return _queryDealsForRenter(renterId, uid);
    }

    // Otherwise stream the user document to resolve renterId, then stream their deals
    return _db.collection('users').doc(uid).snapshots().asyncExpand((userDoc) {
      final data = userDoc.data() ?? {};
      final effectiveRenterId = (data['renterId'] as String?) ?? (data['uid'] as String?) ?? uid;
      return _queryDealsForRenter(effectiveRenterId, uid);
    });
  }

  Stream<List<DealModel>> _queryDealsForRenter(String renterId, String uid) {
    Query query;
    if (renterId.isNotEmpty && uid.isNotEmpty && renterId != uid) {
      query = _db.collection('deals').where('renterId', whereIn: [renterId, uid]);
    } else {
      final target = renterId.isNotEmpty ? renterId : uid;
      query = _db.collection('deals').where('renterId', isEqualTo: target);
    }

    return query.snapshots().map((dealSnap) {
      final all = dealSnap.docs
          .map((d) => DealModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();

      final activeDeals = <DealModel>[];
      final endedDeals = <DealModel>[];

      for (var d in all) {
        if (d.status == 'active') {
          activeDeals.add(d);
        } else if (d.status == 'ended' || d.status == 'closed') {
          endedDeals.add(d);
        }
      }

      final result = <DealModel>[...activeDeals, ...endedDeals];
      result.sort((a, b) {
        if (a.status == 'active' && b.status != 'active') return -1;
        if (a.status != 'active' && b.status == 'active') return 1;
        final aTime = a.updatedAt.isAfter(a.createdAt) ? a.updatedAt : a.createdAt;
        final bTime = b.updatedAt.isAfter(b.createdAt) ? b.updatedAt : b.createdAt;
        return bTime.compareTo(aTime);
      });
      return result;
    });
  }

  // Stream payment records for deal
  Stream<List<PaymentRecordModel>> streamRenterLedger(String dealId, [String? renterId]) {
    final targetRenterId = (renterId != null && renterId.isNotEmpty)
        ? renterId
        : (FirebaseAuth.instance.currentUser?.uid ?? '');

    Query query = _db.collection('paymentRecords');
    if (targetRenterId.isNotEmpty) {
      query = query.where('renterId', isEqualTo: targetRenterId);
    }
    if (dealId.isNotEmpty) {
      query = query.where('dealId', isEqualTo: dealId);
    }

    return query.snapshots().map((snap) {
      final rawRecords = snap.docs
          .map((d) => PaymentRecordModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .where((r) => dealId.isEmpty || r.dealId == dealId)
          .toList();
      
      // Deduplicate by periodMonth
      final map = <String, PaymentRecordModel>{};
      for (var r in rawRecords) {
        final key = r.periodMonth.isNotEmpty ? r.periodMonth : 'm_${r.monthIndex}';
        if (!map.containsKey(key)) {
          map[key] = r;
        } else {
          final existing = map[key]!;
          if (r.status == 'confirmed-paid' || r.status == 'paid' || r.totalPaid > existing.totalPaid) {
            map[key] = r;
          }
        }
      }
      final records = map.values.toList();
      records.sort((a, b) => b.periodMonth.compareTo(a.periodMonth));
      return records;
    });
  }

  // Waterfall Rebalancing & Sync for Deal Ledger with Auto-Repair
  Future<List<PaymentRecordModel>> rebalanceDealLedger(DealModel deal) async {
    final querySnap = await _db
        .collection('paymentRecords')
        .where('renterId', isEqualTo: deal.renterId)
        .get();

    final rawRecords = querySnap.docs
        .map((d) => PaymentRecordModel.fromMap(d.data(), d.id))
        .where((r) => r.dealId == deal.id)
        .toList();

    // Auto-Repair: Check if any record has an oversized bulk installment from legacy settlement bug
    bool requiredBulkFix = false;
    for (var rec in rawRecords) {
      for (var inst in rec.installments) {
        if (inst.amount > rec.effectiveRent * 1.5 &&
            (inst.addedBy == 'owner' || inst.method == 'settlement' || (inst.note?.toLowerCase().contains('paid') ?? false) || (inst.note?.toLowerCase().contains('settled') ?? false))) {
          requiredBulkFix = true;
          break;
        }
      }
      if (requiredBulkFix) break;
    }

    if (requiredBulkFix) {
      final now = DateTime.now();
      final allMonths = RentEngine.rebalanceLedgerRecords(rawRecords, deal);
      final batch = _db.batch();

      for (var m in allMonths) {
        if (m.paymentSource == 'direct') {
          final docRef = _db.collection('paymentRecords').doc(m.id);
          final singleInst = PaymentInstallment(
            amount: m.effectiveRent,
            date: now,
            method: 'cash',
            note: 'all paid',
            addedBy: 'owner',
          );
          final healedRec = PaymentRecordModel(
            id: m.id,
            dealId: deal.id,
            renterId: deal.renterId,
            propertyId: deal.propertyId,
            unitId: deal.currentUnitId.isNotEmpty ? deal.currentUnitId : deal.unitId,
            monthIndex: m.monthIndex,
            periodMonth: m.periodMonth,
            effectiveRent: m.effectiveRent,
            dueDate: m.dueDate,
            paymentSource: 'direct',
            dueFromRenter: m.effectiveRent,
            carriedOverDue: 0.0,
            status: 'confirmed-paid',
            totalPaid: m.effectiveRent,
            amountPending: 0.0,
            installments: [singleInst],
            adminConfirmedAt: now,
            adminConfirmedBy: 'owner',
          );
          batch.set(docRef, healedRec.toMap(), SetOptions(merge: true));
        }
      }
      await batch.commit();

      final healedSnap = await _db.collection('paymentRecords').where('renterId', isEqualTo: deal.renterId).get();
      rawRecords.clear();
      rawRecords.addAll(healedSnap.docs.map((d) => PaymentRecordModel.fromMap(d.data(), d.id)).where((r) => r.dealId == deal.id));
    }

    final updatedRecords = RentEngine.rebalanceLedgerRecords(rawRecords, deal);

    WriteBatch batch = _db.batch();
    int batchCount = 0;

    for (var rec in updatedRecords) {
      final docRef = _db.collection('paymentRecords').doc(rec.id);
      final existingDoc = querySnap.docs.where((d) => d.id == rec.id).firstOrNull;

      if (existingDoc == null || !existingDoc.exists) {
        batch.set(docRef, rec.toMap());
        batchCount++;
      } else {
        final data = existingDoc.data();
        if (data['totalPaid'] != rec.totalPaid ||
            data['amountPending'] != rec.amountPending ||
            data['carriedOverDue'] != rec.carriedOverDue ||
            data['dueFromRenter'] != rec.dueFromRenter ||
            data['status'] != rec.status) {
          batch.update(docRef, {
            'effectiveRent': rec.effectiveRent,
            'dueFromRenter': rec.dueFromRenter,
            'carriedOverDue': rec.carriedOverDue,
            'totalPaid': rec.totalPaid,
            'amountPaidByRenter': rec.totalPaid,
            'amountPending': rec.amountPending,
            'status': rec.status,
          });
          batchCount++;
        }
      }

      if (batchCount >= 400) {
        await batch.commit();
        batch = _db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    return updatedRecords;
  }

  // Lazy Month Generation & Overdue Check on App Open (Section 6.3 / 7.3)
  Future<void> checkAndLazyGenerateMonthRecord(DealModel deal) async {
    await rebalanceDealLedger(deal);
  }

  // Submit payment installment by renter (Section 6.3)
  Future<void> submitPayment({
    required PaymentRecordModel record,
    required DealModel deal,
    required double enteredAmount,
    required String paymentMethod, // 'cash' | 'bank' | 'upi'
    String? note,
    required String ownerUid,
  }) async {
    final newInstallment = PaymentInstallment(
      amount: enteredAmount,
      date: DateTime.now(),
      method: paymentMethod,
      note: note,
      addedBy: 'renter',
    );

    final updatedInstallments = [...record.installments, newInstallment];

    await _db.collection('paymentRecords').doc(record.id).update({
      'installments': updatedInstallments.map((i) => i.toMap()).toList(),
      'status': 'pending-confirmation',
      'renterSubmittedAt': FieldValue.serverTimestamp(),
    });

    await rebalanceDealLedger(deal);

    // Notify property owner with deterministic doc ID to prevent duplicates
    final instIndex = updatedInstallments.length;
    final notifDocId = "owner_${record.id}_installment_$instIndex";
    await _db.collection('notifications').doc(notifDocId).set(NotificationModel(
      id: notifDocId,
      toUid: ownerUid,
      propertyId: record.propertyId,
      type: 'payment-request',
      title: 'Payment Reported',
      message: "Tenant reported installment of ₹${enteredAmount.toStringAsFixed(0)} via ${paymentMethod.toUpperCase()} for ${record.periodMonth}.",
      priority: 'info',
      relatedRecordId: record.id,
      read: false,
      createdAt: DateTime.now(),
    ).toMap(), SetOptions(merge: true));
  }

  // Stream notifications for renter
  Stream<List<NotificationModel>> streamNotifications(String uid) {
    return _db
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => NotificationModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Mark single notification as read
  Future<void> markNotificationAsRead(String docId, {bool read = true}) async {
    try {
      await _db.collection('notifications').doc(docId).update({'read': read});
    } catch (e) {
      debugPrint("Error marking notification read: $e");
    }
  }

  // Mark all notifications as read for a user
  Future<void> markAllNotificationsAsRead(String uid) async {
    try {
      final snap = await _db
          .collection('notifications')
          .where('toUid', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .get();

      final batch = _db.batch();
      for (var doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking all notifications as read: $e");
    }
  }

  // Delete single notification
  Future<void> deleteNotification(String docId) async {
    try {
      await _db.collection('notifications').doc(docId).delete();
    } catch (e) {
      debugPrint("Error deleting notification: $e");
    }
  }

  // Clear all read notifications for a user
  Future<int> clearAllReadNotifications(String uid) async {
    try {
      final snap = await _db
          .collection('notifications')
          .where('toUid', isEqualTo: uid)
          .where('read', isEqualTo: true)
          .get();

      if (snap.docs.isEmpty) return 0;

      final batch = _db.batch();
      for (var doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return snap.docs.length;
    } catch (e) {
      debugPrint("Error clearing read notifications: $e");
      return 0;
    }
  }

  // Purge duplicate notifications from Firestore
  Future<void> cleanupDuplicateNotifications(String uid) async {
    try {
      final snap = await _db
          .collection('notifications')
          .where('toUid', isEqualTo: uid)
          .get();

      final seenKeys = <String, String>{};
      final duplicatesToDelete = <DocumentReference>[];

      for (var doc in snap.docs) {
        final data = doc.data();
        final type = data['type'] as String? ?? '';
        final msg = (data['message'] as String? ?? '').trim().toLowerCase();
        final relatedId = data['relatedRecordId'] as String? ?? '';
        final title = (data['title'] as String? ?? '').trim().toLowerCase();

        // Key based on content & entity
        final key = relatedId.isNotEmpty
            ? "${type}_${relatedId}_$msg"
            : "${type}_${title}_$msg";

        if (seenKeys.containsKey(key)) {
          duplicatesToDelete.add(doc.reference);
        } else {
          seenKeys[key] = doc.id;
        }
      }

      if (duplicatesToDelete.isNotEmpty) {
        final batch = _db.batch();
        for (var ref in duplicatesToDelete) {
          batch.delete(ref);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Error cleaning duplicate notifications: $e");
    }
  }


  // Stream maintenance requests for renter (supports renterUid and renterId filtering)
  Stream<List<MaintenanceRequestModel>> streamRenterMaintenanceRequests(String userUid, [String? optionalRenterId]) {
    final targetRenterId = (optionalRenterId != null && optionalRenterId.isNotEmpty) ? optionalRenterId : userUid;
    return _db
        .collection('maintenanceRequests')
        .where('renterId', isEqualTo: targetRenterId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => MaintenanceRequestModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Submit maintenance request by renter with property owner notification
  Future<void> submitMaintenanceRequest(MaintenanceRequestModel request, {String? ownerUid}) async {
    final ref = await _db.collection('maintenanceRequests').add(request.toMap());

    // Send notification to admin/owner with deterministic ID
    final targetOwner = (ownerUid != null && ownerUid.isNotEmpty) ? ownerUid : 'admin_owner';
    final notifDocId = "owner_maint_${ref.id}";
    await _db.collection('notifications').doc(notifDocId).set(NotificationModel(
      id: notifDocId,
      toUid: targetOwner,
      propertyId: request.propertyId.isNotEmpty ? request.propertyId : AppConfig.defaultPropertyId,
      type: 'maintenance',
      title: 'New Maintenance Complaint',
      message: "New Maintenance Complaint for Unit ${request.unitId.isNotEmpty ? request.unitId : 'Unit'}: ${request.title} (${request.renterName})",
      priority: request.priority.toLowerCase() == 'emergency' ? 'urgent' : (request.priority.toLowerCase() == 'high' ? 'warning' : 'info'),
      relatedRecordId: ref.id,
      read: false,
      createdAt: DateTime.now(),
    ).toMap(), SetOptions(merge: true));
  }

  // Stream property notices for renter with property fallback and audience filtering
  Stream<List<NoticeModel>> streamPropertyNotices(String propertyId, {String? renterType}) {
    final targetPropId = propertyId.isNotEmpty ? propertyId : AppConfig.defaultPropertyId;
    return _db.collection('notices').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => NoticeModel.fromMap(d.data(), d.id))
          .where((n) {
            bool propMatch = n.propertyId == targetPropId ||
                n.propertyId.isEmpty ||
                targetPropId.contains(n.propertyId) ||
                n.propertyId.contains(targetPropId);
            if (!propMatch) return false;

            final targetAudience = n.targetAudience.toLowerCase().trim();
            if (targetAudience == 'all' || targetAudience.isEmpty) return true;

            if (renterType != null && renterType.isNotEmpty) {
              final cleanType = renterType.toLowerCase().trim();
              if (targetAudience == cleanType) return true;
            }
            return true;
          })
          .toList();
      list.sort((a, b) => b.postedAt.compareTo(a.postedAt));
      return list;
    });
  }

  // Stream utility bills for renter deal (supports multi-unit deals)
  Stream<List<Map<String, dynamic>>> streamUtilityBills(dynamic dealOrUnitId, [String? optionalRenterId]) {
    String dealId = '';
    String renterId = optionalRenterId ?? '';
    final unitIds = <String>{};

    if (dealOrUnitId is DealModel) {
      dealId = dealOrUnitId.id;
      renterId = dealOrUnitId.renterId;
      if (dealOrUnitId.currentUnitId.isNotEmpty) unitIds.add(dealOrUnitId.currentUnitId);
      if (dealOrUnitId.unitId.isNotEmpty) unitIds.add(dealOrUnitId.unitId);
      unitIds.addAll(dealOrUnitId.assignedUnitIds);
      unitIds.addAll(dealOrUnitId.assignedUnitLabels);
    } else if (dealOrUnitId is String) {
      if (dealOrUnitId.isNotEmpty) unitIds.add(dealOrUnitId);
    }

    if (renterId.isEmpty) {
      renterId = FirebaseAuth.instance.currentUser?.uid ?? '';
    }

    Query query = _db.collection('utilityBills');
    if (renterId.isNotEmpty) {
      query = query.where('renterId', isEqualTo: renterId);
    }

    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .where((b) {
            final bDealId = (b['dealId'] ?? '').toString();
            final bRenterId = (b['renterId'] ?? b['renterUid'] ?? '').toString();
            final bUnitId = (b['unitId'] ?? '').toString();

            if (dealId.isNotEmpty && bDealId == dealId) return true;
            if (renterId.isNotEmpty && bRenterId == renterId) return true;
            if (unitIds.contains(bUnitId)) return true;
            return false;
          })
          .toList();
      list.sort((a, b) {
        final aTs = a['createdAt'] as Timestamp?;
        final bTs = b['createdAt'] as Timestamp?;
        if (aTs != null && bTs != null) return bTs.compareTo(aTs);
        return 0;
      });
      return list;
    });
  }

  // Submit gate pass / night-out request
  Future<void> submitGatePass(Map<String, dynamic> data) async {
    await _db.collection('gatePasses').add(data);
  }

  Stream<List<Map<String, dynamic>>> streamGatePasses(String renterId) {
    return _db
        .collection('gatePasses')
        .where('renterId', isEqualTo: renterId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      list.sort((a, b) {
        final aTs = a['createdAt'];
        final bTs = b['createdAt'];
        final aDate = aTs is Timestamp ? aTs.toDate() : (aTs is DateTime ? aTs : DateTime.now());
        final bDate = bTs is Timestamp ? bTs.toDate() : (bTs is DateTime ? bTs : DateTime.now());
        return bDate.compareTo(aDate);
      });
      return list;
    });
  }

  // Submit pre-approved visitor log
  Future<void> submitVisitorLog(Map<String, dynamic> data) async {
    await _db.collection('visitorLogs').add(data);
  }

  // Stream visitor logs for renter (v2.2 §6 — server-side filter)
  Stream<List<Map<String, dynamic>>> streamVisitorLogs(String renterId) {
    return _db
        .collection('visitorLogs')
        .where('renterId', isEqualTo: renterId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  // Stream mess menus for property
  Stream<List<Map<String, dynamic>>> streamMessMenus(String propertyId) {
    return _db
        .collection('messMenus')
        .where('propertyId', isEqualTo: propertyId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}
