import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/property_model.dart';
import '../models/unit_model.dart';
import '../models/deal_model.dart';
import '../models/payment_record_model.dart';
import '../models/notification_model.dart';
import '../models/maintenance_request_model.dart';
import '../models/notice_model.dart';
import '../core/rent_engine.dart';
import '../core/secondary_auth.dart';
import '../core/phone_utils.dart';
import '../core/app_config.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream current owner user doc
  Stream<UserModel?> streamUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    });
  }

  // Save or update user document
  Future<void> saveUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }
  Stream<UserModel?> streamRenterUser(String renterIdOrUid) {
    if (renterIdOrUid.trim().isEmpty) return Stream.value(null);
    return _db
        .collection('users')
        .where('renterId', isEqualTo: renterIdOrUid)
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isNotEmpty) {
        return UserModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
      }
      final doc = await _db.collection('users').doc(renterIdOrUid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  // Stream properties owned by owner
  Stream<List<PropertyModel>> streamProperties(String ownerUid) {
    return _db
        .collection('properties')
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .map((snap) => snap.docs.map((d) => PropertyModel.fromMap(d.data(), d.id)).toList());
  }

  // Create initial or white-label property
  Future<String> createProperty(PropertyModel prop) async {
    final ref = await _db.collection('properties').add(prop.toMap());
    return ref.id;
  }

  // Update existing property details (Section 11)
  Future<void> updateProperty(PropertyModel prop) async {
    await _db.collection('properties').doc(prop.id).update(prop.toMap());
  }

  // Stream units for property
  Stream<List<UnitModel>> streamUnits(String propertyId, {String? type}) {
    Query query = _db.collection('units').where('propertyId', isEqualTo: propertyId);
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    return query.snapshots().map((snap) =>
        snap.docs.map((d) => UnitModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  // Add unit
  Future<void> addUnit(UnitModel unit) async {
    await _db.collection('units').add(unit.toMap());
  }

  // Stream deals for property with optional status filtering & de-duplication
  Stream<List<DealModel>> streamDeals(
    String propertyId, {
    String? renterType,
    bool activeOnly = true,
    bool pastOnly = false,
  }) {
    Query query = _db.collection('deals').where('propertyId', isEqualTo: propertyId);
    if (renterType != null) {
      query = query.where('renterType', isEqualTo: renterType);
    }
    return query.snapshots().map((snap) {
      final all = snap.docs.map((d) => DealModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();

      if (pastOnly) {
        final activeDeals = all.where((d) => d.status == 'active').toList();
        final rawEnded = all.where((d) => d.status == 'ended' || d.status == 'closed').toList();

        final filteredEnded = <DealModel>[];
        for (var ended in rawEnded) {
          bool isSupersededByActive = false;
          for (var active in activeDeals) {
            bool sameRenter = ended.renterId == active.renterId;
            bool sameBiz = ended.businessName?.trim().toLowerCase() == active.businessName?.trim().toLowerCase() &&
                (ended.businessName?.trim().isNotEmpty == true);
            bool sameUnit = ended.currentUnitId == active.currentUnitId ||
                ended.containsUnit(active.currentUnitId) ||
                active.containsUnit(ended.currentUnitId);

            if (sameRenter || sameBiz || sameUnit) {
              final activeStart = active.dealStartDate;
              final endedEnd = ended.dealEndDate ?? ended.updatedAt;
              if (endedEnd.isAfter(activeStart.subtract(const Duration(days: 1)))) {
                isSupersededByActive = true;
                break;
              }
            }
          }
          if (!isSupersededByActive) {
            filteredEnded.add(ended);
          }
        }
        return filteredEnded;
      }

      if (!activeOnly) return all;

      // Strict De-duplication: 1 active deal per unit maximum!
      final map = <String, DealModel>{};
      for (var d in all) {
        if (d.status != 'active') continue;
        if (!map.containsKey(d.currentUnitId)) {
          map[d.currentUnitId] = d;
        } else {
          final existing = map[d.currentUnitId]!;
          if (d.createdAt.isAfter(existing.createdAt)) {
            map[d.currentUnitId] = d;
          }
        }
      }
      return map.values.toList();
    });
  }

  // Stream a single deal by its document ID for live updates
  Stream<DealModel?> streamDealById(String dealId) {
    return _db.collection('deals').doc(dealId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return DealModel.fromMap(doc.data()!, doc.id);
    });
  }


  // Automatic cleanup helper to end older duplicate active deals on the same unit in Firestore
  Future<void> cleanupDuplicateDeals(String propertyId) async {
    try {
      final snap = await _db
          .collection('deals')
          .where('propertyId', isEqualTo: propertyId)
          .where('status', isEqualTo: 'active')
          .get();

      final dealsByUnit = <String, List<QueryDocumentSnapshot>>{};
      for (var doc in snap.docs) {
        final data = doc.data();
        final unitId = (data['currentUnitId'] as String?) ?? (data['unitId'] as String?) ?? '';
        final unitLabel = (data['unitLabel'] as String?) ?? '';
        final key = (unitLabel.isNotEmpty ? unitLabel : unitId).toLowerCase().trim();
        if (key.isNotEmpty) {
          dealsByUnit.putIfAbsent(key, () => []).add(doc);
        }
      }

      for (var entry in dealsByUnit.entries) {
        if (entry.value.length > 1) {
          entry.value.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>?;
            final dataB = b.data() as Map<String, dynamic>?;
            final tA = (dataA?['updatedAt'] as Timestamp?) ?? (dataA?['createdAt'] as Timestamp?);
            final tB = (dataB?['updatedAt'] as Timestamp?) ?? (dataB?['createdAt'] as Timestamp?);
            if (tA == null || tB == null) return 0;
            return tB.compareTo(tA);
          });

          // Keep the latest active deal (index 0), mark all older ones as deleted!
          for (int i = 1; i < entry.value.length; i++) {
            await entry.value[i].reference.update({
              'status': 'deleted',
              'dealEndDate': FieldValue.serverTimestamp(),
              'notes': 'Automatically closed duplicate deal',
            });
          }
        }
      }
    } catch (_) {}
  }

  // Stream payment records for a property
  Stream<List<PaymentRecordModel>> streamPaymentRecords(String propertyId) {
    return _db
        .collection('paymentRecords')
        .where('propertyId', isEqualTo: propertyId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PaymentRecordModel.fromMap(d.data(), d.id))
            .toList());
  }

  // Stream pending confirmation records across all renters
  Stream<List<PaymentRecordModel>> streamPendingConfirmations(String propertyId) {
    return _db
        .collection('paymentRecords')
        .where('propertyId', isEqualTo: propertyId)
        .where('status', isEqualTo: 'pending-confirmation')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PaymentRecordModel.fromMap(d.data(), d.id))
            .toList());
  }

  // Find existing renter user by phone number (supports 10-digit and +91 formatted strings)
  Future<UserModel?> findUserByPhone(String phone) async {
    final cleanPhone = PhoneUtils.sanitizeTenDigitPhone(phone);
    if (cleanPhone.isEmpty) return null;
    final formattedPhone = "+91$cleanPhone";

    final snap = await _db
        .collection('users')
        .where('phone', whereIn: [cleanPhone, formattedPhone])
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      return UserModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
    }
    final snap2 = await _db.collection('users').where('role', isEqualTo: 'renter').get();
    for (var doc in snap2.docs) {
      final p = PhoneUtils.sanitizeTenDigitPhone(doc.data()['phone'] as String? ?? '');
      if (p == cleanPhone && cleanPhone.isNotEmpty) {
        return UserModel.fromMap(doc.data(), doc.id);
      }
    }
    return null;
  }

  // Check if a renter already has an active lease for the specified unit
  Future<bool> checkIfRenterHasUnit({required String phone, required String unitId, required String unitLabel}) async {
    final user = await findUserByPhone(phone);
    if (user == null) return false;

    final dealsSnap = await _db
        .collection('deals')
        .where('status', isEqualTo: 'active')
        .get();

    for (var doc in dealsSnap.docs) {
      final data = doc.data();
      final rId = (data['renterId'] as String?) ?? '';
      final uId = (data['currentUnitId'] as String?) ?? (data['unitId'] as String?) ?? '';
      final uLbl = (data['unitLabel'] as String? ?? '').toLowerCase().trim();

      bool matchesRenter = rId == user.renterId || rId == user.uid;
      bool matchesUnit = uId == unitId || (uLbl.isNotEmpty && uLbl == unitLabel.toLowerCase().trim());

      if (matchesRenter && matchesUnit) {
        return true;
      }
    }
    return false;
  }

  // Create renter, deal, user doc, and flip unit status to 'occupied'
  Future<DealModel> createRenterAndDeal({
    required UserModel renterUser,
    required DealModel deal,
  }) async {
    // 0. Check if an active deal exists for this renter and this specific unit
    final existingActive = await _db
        .collection('deals')
        .where('propertyId', isEqualTo: deal.propertyId)
        .where('status', isEqualTo: 'active')
        .get();

    DocumentReference? existingDealRef;
    Map<String, dynamic>? existingDealData;
    final targetLabel = (deal.unitLabel ?? '').toLowerCase().trim();

    for (var doc in existingActive.docs) {
      final data = doc.data();
      final dUnitId = (data['currentUnitId'] as String?) ?? (data['unitId'] as String?) ?? '';
      final dUnitLabel = (data['unitLabel'] as String?) ?? '';
      final dRenterId = (data['renterId'] as String?) ?? '';

      bool matchesRenter = dRenterId == deal.renterId || dRenterId == renterUser.uid;
      bool matchesUnit = (dUnitId.isNotEmpty && (dUnitId == deal.currentUnitId || dUnitId == deal.unitId)) ||
          (dUnitLabel.isNotEmpty && targetLabel.isNotEmpty && dUnitLabel.toLowerCase().trim() == targetLabel);

      if (matchesRenter && matchesUnit && existingDealRef == null) {
        // Only reuse deal reference if it's the SAME renter AND the SAME unit
        existingDealRef = doc.reference;
        existingDealData = data;
      } else if (matchesUnit && !matchesRenter) {
        // If unit belonged to a different renter before, archive old deal
        await doc.reference.update({
          'status': 'deleted',
          'dealEndDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // Merge unit IDs and labels if reusing an existing deal for the same renter
    List<String> combinedUnitIds = List<String>.from(deal.assignedUnitIds);
    if (combinedUnitIds.isEmpty && deal.currentUnitId.isNotEmpty) {
      combinedUnitIds.add(deal.currentUnitId);
    }
    List<String> combinedUnitLabels = List<String>.from(deal.assignedUnitLabels);
    if (combinedUnitLabels.isEmpty && deal.unitLabel != null && deal.unitLabel!.isNotEmpty) {
      combinedUnitLabels.add(deal.unitLabel!);
    }

    if (existingDealData != null) {
      final oldUnitIds = List<String>.from(existingDealData['assignedUnitIds'] ?? []);
      for (var u in oldUnitIds) {
        if (!combinedUnitIds.contains(u) && u.isNotEmpty) combinedUnitIds.add(u);
      }
      final oldUnitLabels = List<String>.from(existingDealData['assignedUnitLabels'] ?? []);
      for (var l in oldUnitLabels) {
        if (!combinedUnitLabels.contains(l) && l.isNotEmpty) combinedUnitLabels.add(l);
      }
    }

    final mergedUnitLabel = combinedUnitLabels.isNotEmpty ? combinedUnitLabels.join(', ') : deal.unitLabel;

    final dealToSave = DealModel(
      id: deal.id,
      propertyId: deal.propertyId,
      currentUnitId: deal.currentUnitId,
      renterId: deal.renterId,
      renterType: deal.renterType,
      dealStartDate: deal.dealStartDate,
      rentSchedule: deal.rentSchedule,
      rentDueDayOfMonth: deal.rentDueDayOfMonth,
      advanceTransactions: deal.advanceTransactions,
      advanceConsumptionMode: deal.advanceConsumptionMode,
      advanceDeductStartMonth: deal.advanceDeductStartMonth,
      advanceDeductEndMonth: deal.advanceDeductEndMonth,
      unitHistory: deal.unitHistory,
      amenities: deal.amenities,
      carryForwardPendingBalance: deal.carryForwardPendingBalance,
      agreementType: deal.agreementType,
      agreementFileBase64: deal.agreementFileBase64,
      agreementDriveLink: deal.agreementDriveLink,
      status: deal.status,
      notes: deal.notes,
      createdAt: deal.createdAt,
      updatedAt: DateTime.now(),
      businessName: deal.businessName,
      businessCategory: deal.businessCategory,
      occupantCount: deal.occupantCount,
      maintenanceIncluded: deal.maintenanceIncluded,
      unitLabel: mergedUnitLabel,
      unitCode: deal.unitCode,
      assignedUnitIds: combinedUnitIds,
      assignedUnitLabels: combinedUnitLabels,
    );

    // 1. Write or update users/{uid}
    final existingUserDoc = await _db.collection('users').doc(renterUser.uid).get();
    if (existingUserDoc.exists) {
      final existingPropIds = List<String>.from(existingUserDoc.data()?['propertyIds'] ?? []);
      if (!existingPropIds.contains(deal.propertyId)) {
        existingPropIds.add(deal.propertyId);
      }
      await _db.collection('users').doc(renterUser.uid).update({
        'propertyIds': existingPropIds,
        'active': true,
      });
    } else {
      await _db.collection('users').doc(renterUser.uid).set(renterUser.toMap());
    }

    // 2. Write or update deals/{dealId}
    String finalDealId = '';
    if (existingDealRef != null) {
      finalDealId = existingDealRef.id;
      await existingDealRef.update(dealToSave.toMap());
    } else {
      final dealRef = await _db.collection('deals').add(dealToSave.toMap());
      finalDealId = dealRef.id;
    }

    final createdDeal = DealModel(
      id: finalDealId,
      propertyId: dealToSave.propertyId,
      currentUnitId: dealToSave.currentUnitId,
      renterId: dealToSave.renterId,
      renterType: dealToSave.renterType,
      dealStartDate: dealToSave.dealStartDate,
      rentSchedule: dealToSave.rentSchedule,
      rentDueDayOfMonth: dealToSave.rentDueDayOfMonth,
      advanceTransactions: dealToSave.advanceTransactions,
      advanceConsumptionMode: dealToSave.advanceConsumptionMode,
      advanceDeductStartMonth: dealToSave.advanceDeductStartMonth,
      advanceDeductEndMonth: dealToSave.advanceDeductEndMonth,
      unitHistory: dealToSave.unitHistory,
      amenities: dealToSave.amenities,
      carryForwardPendingBalance: dealToSave.carryForwardPendingBalance,
      agreementType: dealToSave.agreementType,
      agreementFileBase64: dealToSave.agreementFileBase64,
      agreementDriveLink: dealToSave.agreementDriveLink,
      status: dealToSave.status,
      notes: dealToSave.notes,
      createdAt: dealToSave.createdAt,
      updatedAt: DateTime.now(),
      businessName: dealToSave.businessName,
      businessCategory: dealToSave.businessCategory,
      occupantCount: dealToSave.occupantCount,
      maintenanceIncluded: dealToSave.maintenanceIncluded,
      unitLabel: dealToSave.unitLabel,
      unitCode: dealToSave.unitCode,
      assignedUnitIds: dealToSave.assignedUnitIds,
      assignedUnitLabels: dealToSave.assignedUnitLabels,
    );

    // 3. Update status of ALL assigned units to 'occupied' in Firestore database
    await syncDealUnitStatuses(createdDeal, isOccupied: true);

    // 4. Auto-generate month records & sync ledger
    await checkAndLazyGenerateMonthRecord(createdDeal);

    return createdDeal;
  }

  // Update existing deal terms (Rent Schedule, Due Day, Drive Link)
  Future<void> updateDeal(DealModel deal) async {
    await _db.collection('deals').doc(deal.id).update(deal.toMap());
    await syncDealUnitStatuses(deal, isOccupied: true);
  }

  /// Sync Firestore unit documents for all assigned units in a deal to 'occupied' or 'vacant'
  Future<void> syncDealUnitStatuses(DealModel deal, {bool isOccupied = true}) async {
    final statusStr = isOccupied ? 'occupied' : 'vacant';
    final targets = <String>{
      deal.currentUnitId,
      if (deal.unitLabel != null) deal.unitLabel!,
      ...deal.assignedUnitIds,
      ...deal.assignedUnitLabels,
    };
    if (deal.unitLabel != null && deal.unitLabel!.isNotEmpty) {
      final tokens = deal.unitLabel!.split(RegExp(r'[,\+&]+')).map((s) => s.trim()).where((s) => s.isNotEmpty);
      targets.addAll(tokens);
    }

    // Track which targets we've successfully updated
    final updatedIds = <String>{};

    for (var target in targets) {
      if (target.trim().isEmpty) continue;
      final docRef = _db.collection('units').doc(target);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.update({'status': statusStr});
        updatedIds.add(target);
      }
      final queryByLabel = await _db
          .collection('units')
          .where('propertyId', isEqualTo: deal.propertyId)
          .where('label', isEqualTo: target)
          .get();
      for (var uDoc in queryByLabel.docs) {
        await uDoc.reference.update({'status': statusStr});
        updatedIds.add(uDoc.id);
      }
    }

    // Fallback: scan all property units for case-insensitive label matches
    // This catches units missed by exact Firestore queries due to case/whitespace
    final targetLabelsLower = targets.map((t) => t.toLowerCase().trim()).where((t) => t.isNotEmpty).toSet();
    if (targetLabelsLower.isNotEmpty) {
      final allPropertyUnits = await _db
          .collection('units')
          .where('propertyId', isEqualTo: deal.propertyId)
          .get();
      for (var uDoc in allPropertyUnits.docs) {
        if (updatedIds.contains(uDoc.id)) continue;
        final uLabel = ((uDoc.data()['label'] ?? '') as String).toLowerCase().trim();
        if (targetLabelsLower.contains(uLabel) || targetLabelsLower.contains(uDoc.id.toLowerCase().trim())) {
          await uDoc.reference.update({'status': statusStr});
        }
      }
    }
  }

  /// Deep heal Firestore unit documents for property: ensures all units assigned to active deals
  /// are marked 'occupied' in Firestore database, and all unassigned units are marked 'vacant'.
  Future<void> healPropertyUnitStatuses(String propertyId) async {
    if (propertyId.isEmpty) return;
    try {
      final activeDealsSnap = await _db
          .collection('deals')
          .where('propertyId', isEqualTo: propertyId)
          .where('status', isEqualTo: 'active')
          .get();

      final activeDeals = activeDealsSnap.docs.map((d) => DealModel.fromMap(d.data(), d.id)).toList();

      final allUnitsSnap = await _db
          .collection('units')
          .where('propertyId', isEqualTo: propertyId)
          .get();

      for (var uDoc in allUnitsSnap.docs) {
        final unit = UnitModel.fromMap(uDoc.data(), uDoc.id);
        final isOccupiedInDeals = activeDeals.any((d) =>
          d.currentUnitId == unit.id ||
          d.containsUnit(unit.id) ||
          d.containsUnit(unit.label)
        );

        final expectedStatus = isOccupiedInDeals ? 'occupied' : 'vacant';
        if (unit.status != expectedStatus) {
          await uDoc.reference.update({'status': expectedStatus});
        }
      }
    } catch (_) {}
  }

  // Section 1: Transfer Unit
  Future<void> transferUnit({
    required DealModel deal,
    required String newUnitId,
    required DateTime transferDate,
  }) async {
    final oldUnitId = deal.currentUnitId;

    final updatedHistory = deal.unitHistory.map((item) {
      if (item.toDate == null) {
        return UnitHistoryItem(unitId: item.unitId, unitLabel: item.unitLabel, fromDate: item.fromDate, toDate: transferDate);
      }
      return item;
    }).toList();

    updatedHistory.add(UnitHistoryItem(unitId: newUnitId, unitLabel: newUnitId, fromDate: transferDate, toDate: null));

    await _db.collection('deals').doc(deal.id).update({
      'currentUnitId': newUnitId,
      'unitId': newUnitId,
      'unitHistory': updatedHistory.map((h) => h.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('units').doc(oldUnitId).update({'status': 'vacant'});
    await _db.collection('units').doc(newUnitId).update({'status': 'occupied'});
  }

  // Section 1B: Add Additional Unit to Deal
  Future<void> addUnitToDeal({
    required DealModel deal,
    required UnitModel newUnit,
    required DateTime effectiveDate,
    required double additionalRent,
    required double additionalAdvance,
    String? note,
  }) async {
    final updatedUnitIds = List<String>.from(deal.assignedUnitIds);
    if (!updatedUnitIds.contains(newUnit.id)) {
      updatedUnitIds.add(newUnit.id);
    }
    final updatedUnitLabels = List<String>.from(deal.assignedUnitLabels);
    if (!updatedUnitLabels.contains(newUnit.label)) {
      updatedUnitLabels.add(newUnit.label);
    }

    final mergedLabel = updatedUnitLabels.join(', ');

    final updatedHistory = [...deal.unitHistory, UnitHistoryItem(unitId: newUnit.id, unitLabel: newUnit.label, fromDate: effectiveDate, toDate: null)];

    final currentPeriodRent = RentEngine.getEffectiveRent(deal, RentEngine.getMonthIndex(deal.dealStartDate, effectiveDate));
    final newTotalRent = currentPeriodRent + additionalRent;

    final updatedSchedule = List<RentScheduleItem>.from(deal.rentSchedule);
    updatedSchedule.add(RentScheduleItem(effectiveFromDate: effectiveDate, monthlyRent: newTotalRent));
    updatedSchedule.sort((a, b) => a.effectiveFromDate.compareTo(b.effectiveFromDate));

    final updatedAdvTx = List<AdvanceTransactionItem>.from(deal.advanceTransactions);
    if (additionalAdvance > 0) {
      updatedAdvTx.add(AdvanceTransactionItem(
        date: effectiveDate,
        amount: additionalAdvance,
        note: note ?? 'Advance Top-Up for Unit ${newUnit.label}',
      ));
    }
    final totalAdv = updatedAdvTx.fold<double>(0.0, (acc, item) => acc + item.amount);

    await _db.collection('deals').doc(deal.id).update({
      'assignedUnitIds': updatedUnitIds,
      'assignedUnitLabels': updatedUnitLabels,
      'unitLabel': mergedLabel,
      'unitHistory': updatedHistory.map((h) => h.toMap()).toList(),
      'rentSchedule': updatedSchedule.map((s) => s.toMap()).toList(),
      'advanceTransactions': updatedAdvTx.map((t) => t.toMap()).toList(),
      'advanceAmount': totalAdv,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('units').doc(newUnit.id).update({'status': 'occupied'});

    final updatedDealDoc = await _db.collection('deals').doc(deal.id).get();
    if (updatedDealDoc.exists) {
      final updatedDeal = DealModel.fromMap(updatedDealDoc.data()!, updatedDealDoc.id);
      await syncDealUnitStatuses(updatedDeal);
      await rebalanceDealLedger(updatedDeal);
    }
  }

  // Section 1C: Vacate / Remove Unit from Deal
  Future<void> vacateUnitFromDeal({
    required DealModel deal,
    required String vacateUnitId,
    required String vacateUnitLabel,
    required DateTime vacateDate,
    required double newTotalRent,
    String? note,
  }) async {
    final updatedUnitIds = deal.assignedUnitIds.where((u) => u != vacateUnitId && u != vacateUnitLabel).toList();
    final updatedUnitLabels = deal.assignedUnitLabels.where((l) => l != vacateUnitLabel && l != vacateUnitId).toList();
    final mergedLabel = updatedUnitLabels.isNotEmpty ? updatedUnitLabels.join(', ') : (updatedUnitIds.isNotEmpty ? updatedUnitIds.join(', ') : 'Vacated');

    final updatedHistory = deal.unitHistory.map((item) {
      if ((item.unitId == vacateUnitId || item.unitId == vacateUnitLabel) && item.toDate == null) {
        return UnitHistoryItem(unitId: item.unitId, fromDate: item.fromDate, toDate: vacateDate);
      }
      return item;
    }).toList();

    final updatedSchedule = List<RentScheduleItem>.from(deal.rentSchedule);
    updatedSchedule.add(RentScheduleItem(effectiveFromDate: vacateDate, monthlyRent: newTotalRent));
    updatedSchedule.sort((a, b) => a.effectiveFromDate.compareTo(b.effectiveFromDate));

    await _db.collection('deals').doc(deal.id).update({
      'assignedUnitIds': updatedUnitIds,
      'assignedUnitLabels': updatedUnitLabels,
      'unitLabel': mergedLabel,
      'currentUnitId': updatedUnitIds.isNotEmpty ? updatedUnitIds.first : deal.currentUnitId,
      'unitHistory': updatedHistory.map((h) => h.toMap()).toList(),
      'rentSchedule': updatedSchedule.map((s) => s.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final unitDoc = await _db.collection('units').doc(vacateUnitId).get();
    if (unitDoc.exists) {
      await unitDoc.reference.update({'status': 'vacant'});
    } else {
      final unitsByLabel = await _db
          .collection('units')
          .where('propertyId', isEqualTo: deal.propertyId)
          .where('label', isEqualTo: vacateUnitLabel)
          .get();
      for (var uDoc in unitsByLabel.docs) {
        await uDoc.reference.update({'status': 'vacant'});
      }
    }

    final updatedDealDoc = await _db.collection('deals').doc(deal.id).get();
    if (updatedDealDoc.exists) {
      final updatedDeal = DealModel.fromMap(updatedDealDoc.data()!, updatedDealDoc.id);
      await rebalanceDealLedger(updatedDeal);
    }
  }

  // Section 2: Add Advance Transaction
  Future<void> addAdvanceTransaction({
    required DealModel deal,
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    final newTx = AdvanceTransactionItem(
      date: date ?? DateTime.now(),
      amount: amount,
      note: (note != null && note.trim().isNotEmpty) ? note.trim() : 'Advance Deposit Top-Up',
    );

    final updatedList = [...deal.advanceTransactions, newTx];
    final totalAdv = updatedList.fold<double>(0.0, (acc, item) => acc + item.amount);

    await _db.collection('deals').doc(deal.id).update({
      'advanceTransactions': updatedList.map((t) => t.toMap()).toList(),
      'advanceAmount': totalAdv,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final updatedDealDoc = await _db.collection('deals').doc(deal.id).get();
    if (updatedDealDoc.exists) {
      final updatedDeal = DealModel.fromMap(updatedDealDoc.data()!, updatedDealDoc.id);
      await rebalanceDealLedger(updatedDeal);
    }
  }

  // Delete Advance Transaction Item
  Future<void> deleteAdvanceTransaction({
    required DealModel deal,
    required int index,
  }) async {
    if (index < 0 || index >= deal.advanceTransactions.length) return;

    final updatedList = List<AdvanceTransactionItem>.from(deal.advanceTransactions)..removeAt(index);
    final totalAdv = updatedList.fold<double>(0.0, (acc, item) => acc + item.amount);

    await _db.collection('deals').doc(deal.id).update({
      'advanceTransactions': updatedList.map((t) => t.toMap()).toList(),
      'advanceAmount': totalAdv,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final updatedDealDoc = await _db.collection('deals').doc(deal.id).get();
    if (updatedDealDoc.exists) {
      final updatedDeal = DealModel.fromMap(updatedDealDoc.data()!, updatedDealDoc.id);
      await rebalanceDealLedger(updatedDeal);
    }
  }


  // Section 4: Add Amenity / Facility to Deal
  Future<void> addAmenity({
    required DealModel deal,
    required String name,
    String? note,
  }) async {
    final newItem = AmenityItem(
      name: name,
      applicable: true,
      notes: note ?? '',
    );

    final updatedList = [...deal.amenities, newItem];
    await _db.collection('deals').doc(deal.id).update({
      'amenities': updatedList.map((a) => a.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete Amenity / Facility from Deal
  Future<void> deleteAmenity({
    required DealModel deal,
    required int index,
  }) async {
    if (index < 0 || index >= deal.amenities.length) return;

    final updatedList = List<AmenityItem>.from(deal.amenities)..removeAt(index);
    await _db.collection('deals').doc(deal.id).update({
      'amenities': updatedList.map((a) => a.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }


  // Section 3: End Deal with Advance Deposit Refund Control
  Future<void> endDeal(
    DealModel deal, {
    double? refundAmount,
    String? refundNote,
  }) async {
    final now = DateTime.now();

    await _db.collection('deals').doc(deal.id).update({
      'status': 'ended',
      'dealEndDate': Timestamp.fromDate(now),
      'advanceRefundAmount': refundAmount ?? deal.totalAdvanceAmount,
      'advanceRefundDate': Timestamp.fromDate(now),
      'advanceRefundNote': refundNote ?? 'Advance deposit returned on deal closing',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await syncDealUnitStatuses(deal, isOccupied: false);
    await healPropertyUnitStatuses(deal.propertyId);
  }

  // Safe Delete Checks (v2.3)
  // Renter account can be deleted only when 0 deals ever created under it
  Future<bool> canDeleteRenter(String renterId) async {
    if (renterId.isEmpty) return false;
    final snap = await _db.collection('deals').where('renterId', isEqualTo: renterId).limit(1).get();
    return snap.docs.isEmpty;
  }

  // Deal can be deleted only when 0 payment records exist for it
  Future<bool> canDeleteDeal(String dealId) async {
    if (dealId.isEmpty) return false;
    final snap = await _db.collection('paymentRecords').where('dealId', isEqualTo: dealId).limit(1).get();
    return snap.docs.isEmpty;
  }

  // Unit can be deleted only when 0 deals have ever referenced it
  Future<bool> canDeleteUnit(String unitId, {String? unitLabel}) async {
    if (unitId.isEmpty) return false;
    final snap = await _db.collection('deals').get();
    for (var doc in snap.docs) {
      final data = doc.data();
      final curUnit = data['currentUnitId'] as String? ?? '';
      final assigned = List<String>.from(data['assignedUnitIds'] ?? []);
      final history = (data['unitHistory'] as List<dynamic>?) ?? [];

      if (curUnit == unitId || (unitLabel != null && unitLabel.isNotEmpty && curUnit == unitLabel)) return false;
      if (assigned.contains(unitId) || (unitLabel != null && unitLabel.isNotEmpty && assigned.contains(unitLabel))) return false;

      for (var h in history) {
        if (h is Map<String, dynamic>) {
          final hUnitId = h['unitId'] as String? ?? '';
          final hUnitLabel = h['unitLabel'] as String? ?? '';
          if (hUnitId == unitId || (unitLabel != null && unitLabel.isNotEmpty && (hUnitId == unitLabel || hUnitLabel == unitLabel))) {
            return false;
          }
        }
      }
    }
    return true;
  }

  // Delete a deal document permanently (only when zero payment records exist)
  Future<void> deleteDeal(String dealId) async {
    if (dealId.isNotEmpty) {
      final doc = await _db.collection('deals').doc(dealId).get();
      final propId = doc.data()?['propertyId'] as String? ?? '';
      await _db.collection('deals').doc(dealId).delete();
      if (propId.isNotEmpty) {
        await healPropertyUnitStatuses(propId);
      }
    }
  }

  // Delete a unit document permanently (only when zero deals reference it)
  Future<void> deleteUnit(String unitId) async {
    if (unitId.isNotEmpty) {
      await _db.collection('units').doc(unitId).delete();
    }
  }

  // Delete a user / renter document permanently (only when zero deals reference it)
  Future<void> deleteUser(String uid) async {
    if (uid.isNotEmpty) {
      await _db.collection('users').doc(uid).delete();
    }
  }

  Future<void> deleteRenterAccount(String renterId) async {
    if (renterId.isEmpty) return;
    final doc = await _db.collection('users').doc(renterId).get();
    if (doc.exists) {
      await doc.reference.delete();
    } else {
      final snap = await _db.collection('users').where('renterId', isEqualTo: renterId).get();
      for (var d in snap.docs) {
        await d.reference.delete();
      }
    }
  }

  // Section 4: Update Deal Amenities
  Future<void> updateDealAmenities({
    required String dealId,
    required List<AmenityItem> amenities,
  }) async {
    await _db.collection('deals').doc(dealId).update({
      'amenities': amenities.map((a) => a.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Waterfall Rebalancing & Sync for Deal Ledger with Auto-Repair
  Future<List<PaymentRecordModel>> rebalanceDealLedger(DealModel deal) async {
    final querySnap = await _db
        .collection('paymentRecords')
        .where('dealId', isEqualTo: deal.id)
        .get();

    final rawRecords = querySnap.docs.map((d) => PaymentRecordModel.fromMap(d.data(), d.id)).toList();

    // Auto-Repair: Check if any record has an oversized bulk installment from legacy settlement bug
    // (e.g. Month 17 had ₹42,500 while previous months had no installments)
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

      // Refetch healed records
      final healedSnap = await _db.collection('paymentRecords').where('dealId', isEqualTo: deal.id).get();
      rawRecords.clear();
      rawRecords.addAll(healedSnap.docs.map((d) => PaymentRecordModel.fromMap(d.data(), d.id)));
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

  // Lazy Month Generation & Overdue Check (Section 7.3 & 7.6)
  Future<void> checkAndLazyGenerateMonthRecord(DealModel deal) async {
    await rebalanceDealLedger(deal);
  }

  /// Settle all past rents up to a target periodMonth
  /// Distributes exact required monthly rent to EACH past month individually,
  /// so that each month's breakdown shows its own exact ₹2500 installment instead of an incorrect bulk sum.
  Future<void> settlePastRentsToDate({
    required DealModel deal,
    required String targetPeriodMonth,
    required String ownerUid,
    String? note,
  }) async {
    final rawRecordsSnap = await _db
        .collection('paymentRecords')
        .where('dealId', isEqualTo: deal.id)
        .get();

    final existingList = rawRecordsSnap.docs
        .map((d) => PaymentRecordModel.fromMap(d.data(), d.id))
        .toList();

    final rebalanced = RentEngine.rebalanceLedgerRecords(existingList, deal);

    final targetIndex = rebalanced.indexWhere((r) => r.periodMonth == targetPeriodMonth);
    final cutoffIndex = targetIndex != -1 ? targetIndex + 1 : rebalanced.length;

    WriteBatch batch = _db.batch();
    int batchCount = 0;
    final now = DateTime.now();

    for (int i = 0; i < cutoffIndex && i < rebalanced.length; i++) {
      final rec = rebalanced[i];
      if (rec.paymentSource == 'direct' && (rec.amountPending > 0 || rec.installments.isEmpty)) {
        final amountNeeded = rec.amountPending > 0 ? rec.amountPending : rec.effectiveRent;
        final installment = PaymentInstallment(
          amount: amountNeeded,
          date: now,
          method: 'cash',
          note: note ?? 'all paid',
          addedBy: 'owner',
        );

        final updatedInstallments = [...rec.installments, installment];
        final docRef = _db.collection('paymentRecords').doc(rec.id);

        final updatedRec = PaymentRecordModel(
          id: rec.id,
          dealId: deal.id,
          renterId: deal.renterId,
          propertyId: deal.propertyId,
          unitId: deal.currentUnitId.isNotEmpty ? deal.currentUnitId : deal.unitId,
          monthIndex: rec.monthIndex,
          periodMonth: rec.periodMonth,
          effectiveRent: rec.effectiveRent,
          dueDate: rec.dueDate,
          paymentSource: 'direct',
          dueFromRenter: rec.effectiveRent,
          carriedOverDue: 0.0,
          status: 'confirmed-paid',
          totalPaid: rec.effectiveRent,
          amountPending: 0.0,
          installments: updatedInstallments,
          adminConfirmedAt: now,
          adminConfirmedBy: ownerUid,
        );

        batch.set(docRef, updatedRec.toMap(), SetOptions(merge: true));
        batchCount++;

        if (batchCount >= 400) {
          await batch.commit();
          batch = _db.batch();
          batchCount = 0;
        }
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    await rebalanceDealLedger(deal);
  }

  /// Manage past rent advance consumption rules (deducting past rent from advance)
  Future<void> updateAdvanceConsumptionRules({
    required DealModel deal,
    required bool enableAdvanceConsumption,
    double? addAdvanceAmount,
    String? note,
  }) async {
    final updates = <String, dynamic>{
      'advanceConsumptionMode': enableAdvanceConsumption,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (addAdvanceAmount != null && addAdvanceAmount > 0) {
      final newTx = AdvanceTransactionItem(
        date: deal.dealStartDate,
        amount: addAdvanceAmount,
        note: note ?? 'Past Rent Advance Onboarding Top-up',
      );
      final updatedList = [...deal.advanceTransactions, newTx];
      updates['advanceTransactions'] = updatedList.map((t) => t.toMap()).toList();
      updates['advanceAmount'] = updatedList.fold<double>(0.0, (acc, item) => acc + item.amount);
    }

    await _db.collection('deals').doc(deal.id).update(updates);

    final updatedDealDoc = await _db.collection('deals').doc(deal.id).get();
    if (updatedDealDoc.exists) {
      final updatedDeal = DealModel.fromMap(updatedDealDoc.data()!, updatedDealDoc.id);
      await rebalanceDealLedger(updatedDeal);
    }
  }

  // Admin Direct "Mark Paid" (Section 7.5)
  Future<void> ownerMarkPaid({
    required PaymentRecordModel record,
    required double amount,
    required String method,
    String? note,
    required String ownerUid,
    required DealModel deal,
  }) async {
    final newInstallment = PaymentInstallment(
      amount: amount,
      date: DateTime.now(),
      method: method,
      note: note,
      addedBy: 'owner',
    );

    final updatedInstallments = [...record.installments, newInstallment];

    await _db.collection('paymentRecords').doc(record.id).update({
      'installments': updatedInstallments.map((i) => i.toMap()).toList(),
      'adminConfirmedAt': FieldValue.serverTimestamp(),
      'adminConfirmedBy': ownerUid,
    });

    await rebalanceDealLedger(deal);
  }

  // Owner Confirms Renter Submission (Section 7.4)
  Future<void> confirmPaymentRecord({
    required PaymentRecordModel record,
    required DealModel deal,
    required String adminUid,
    double? adjustedAmount,
  }) async {
    final updates = <String, dynamic>{
      'status': 'confirmed-paid',
      'adminConfirmedAt': FieldValue.serverTimestamp(),
      'adminConfirmedBy': adminUid,
    };

    if (adjustedAmount != null && record.installments.isNotEmpty) {
      final lastInst = record.installments.last;
      final updatedLast = PaymentInstallment(
        amount: adjustedAmount,
        date: lastInst.date,
        method: lastInst.method,
        note: lastInst.note,
        addedBy: lastInst.addedBy,
      );
      final updatedList = [...record.installments.sublist(0, record.installments.length - 1), updatedLast];
      updates['installments'] = updatedList.map((i) => i.toMap()).toList();
    }

    await _db.collection('paymentRecords').doc(record.id).update(updates);

    await rebalanceDealLedger(deal);

    final notifDocId = "${record.renterId}_payment-confirmed_${record.id}";
    await _db.collection('notifications').doc(notifDocId).set(NotificationModel(
      id: notifDocId,
      toUid: record.renterId,
      propertyId: record.propertyId,
      type: 'payment-confirmed',
      title: 'Payment Confirmed',
      message: "Payment for ${record.periodMonth} confirmed by owner.",
      priority: 'info',
      relatedRecordId: record.id,
      read: false,
      createdAt: DateTime.now(),
    ).toMap(), SetOptions(merge: true));
  }

  // Reset Renter Login (Section 8.5)
  Future<Map<String, String>> resetRenterLogin({
    required UserModel oldUserDoc,
    required String newPassword,
  }) async {
    final cleanPhone = PhoneUtils.sanitizeTenDigitPhone(oldUserDoc.phone);

    // 1. Ensure Auth account has the updated password via secondary auth
    final cred = await SecondaryAuthService.createOrUpdateRenterAccount(
      phone: oldUserDoc.phone,
      password: newPassword,
      oldPassword: oldUserDoc.renterPassword,
    );
    final authUid = cred.user!.uid;

    // 2. Write or update users/{authUid} keeping stable renterId
    final updatedUser = UserModel(
      uid: authUid,
      renterId: oldUserDoc.renterId,
      role: 'renter',
      name: oldUserDoc.name,
      phone: oldUserDoc.phone,
      pseudoEmail: PhoneUtils.toPseudoEmail(oldUserDoc.phone),
      renterPassword: newPassword,
      propertyIds: oldUserDoc.propertyIds,
      active: true,
      createdAt: oldUserDoc.createdAt,
      createdBy: oldUserDoc.createdBy,
    );

    await _db.collection('users').doc(authUid).set(updatedUser.toMap(), SetOptions(merge: true));

    // Remove legacy stale user document if authUid changed
    if (authUid != oldUserDoc.uid) {
      await _db.collection('users').doc(oldUserDoc.uid).delete();
    }

    await cleanupDuplicateUsers(oldUserDoc.phone);

    return {
      'phone': cleanPhone.isNotEmpty ? cleanPhone : oldUserDoc.phone,
      'password': newPassword,
    };
  }

  // Automatic cleanup helper for duplicate user documents by phone
  Future<void> cleanupDuplicateUsers(String phone) async {
    final cleanPhone = PhoneUtils.sanitizeTenDigitPhone(phone);
    if (cleanPhone.isEmpty) return;

    final formattedPhone = "+91$cleanPhone";
    final snap = await _db
        .collection('users')
        .where('phone', whereIn: [cleanPhone, formattedPhone])
        .get();

    if (snap.docs.length > 1) {
      final docs = snap.docs.toList();
      docs.sort((a, b) {
        final tA = (a.data()['createdAt'] as Timestamp?) ?? Timestamp.now();
        final tB = (b.data()['createdAt'] as Timestamp?) ?? Timestamp.now();
        return tB.compareTo(tA);
      });

      for (int i = 1; i < docs.length; i++) {
        await docs[i].reference.delete();
      }
    }
  }

  /// Verify that a renter's Firestore user document has a valid backing
  /// Firebase Auth account. If not (phantom UID), create the Auth account
  /// and migrate the Firestore doc + deal references to the real Auth UID.
  /// Returns the verified/repaired UserModel.
  Future<UserModel> verifyAndRepairRenterAuth(UserModel renterUser) async {
    final phone = renterUser.phone;
    final password = renterUser.renterPassword ?? '123456';

    // Attempt to create or sign into the Auth account
    final cred = await SecondaryAuthService.createOrUpdateRenterAccount(
      phone: phone,
      password: password,
      oldPassword: renterUser.renterPassword,
    );
    final realAuthUid = cred.user!.uid;

    // If the Auth UID matches the existing Firestore doc UID, no repair needed
    if (realAuthUid == renterUser.uid) {
      return renterUser;
    }

    // Auth UID differs from Firestore doc UID — the old UID was phantom/stale.
    // Migrate: write new doc at realAuthUid, delete old phantom doc.
    final repairedUser = UserModel(
      uid: realAuthUid,
      renterId: renterUser.renterId,
      role: 'renter',
      name: renterUser.name,
      phone: renterUser.phone,
      pseudoEmail: PhoneUtils.toPseudoEmail(phone),
      renterPassword: password,
      propertyIds: renterUser.propertyIds,
      active: renterUser.active,
      createdAt: renterUser.createdAt,
      createdBy: renterUser.createdBy,
    );

    await _db.collection('users').doc(realAuthUid).set(repairedUser.toMap(), SetOptions(merge: true));

    // Delete old phantom doc only if IDs differ
    if (renterUser.uid != realAuthUid) {
      await _db.collection('users').doc(renterUser.uid).delete();
    }

    // Update any deals that reference the old phantom UID as renterId
    final dealsWithOldUid = await _db
        .collection('deals')
        .where('renterId', isEqualTo: renterUser.uid)
        .get();
    for (var dealDoc in dealsWithOldUid.docs) {
      await dealDoc.reference.update({'renterId': renterUser.renterId});
    }

    await cleanupDuplicateUsers(phone);

    return repairedUser;
  }

  // Stream notifications for user
  Stream<List<NotificationModel>> streamNotifications(String uid) {
    return _db
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => NotificationModel.fromMap(d.data(), d.id))
            .toList());
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

  // Stream maintenance requests for property with fallback support
  Stream<List<MaintenanceRequestModel>> streamPropertyMaintenanceRequests(String propertyId) {
    final targetPropId = propertyId.isNotEmpty ? propertyId : AppConfig.defaultPropertyId;
    return _db.collection('maintenanceRequests').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => MaintenanceRequestModel.fromMap(d.data(), d.id))
          .where((m) {
            if (m.propertyId.isEmpty) return true;
            return m.propertyId == targetPropId ||
                targetPropId.contains(m.propertyId) ||
                m.propertyId.contains(targetPropId);
          })
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Update maintenance request status & send notification to tenant
  Future<void> updateMaintenanceStatus(String requestId, String status, String? adminNote, {MaintenanceRequestModel? ticket}) async {
    final updates = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (adminNote != null) updates['adminNote'] = adminNote;
    await _db.collection('maintenanceRequests').doc(requestId).update(updates);

    if (ticket != null) {
      final recipient = ticket.renterUid.isNotEmpty ? ticket.renterUid : ticket.renterId;
      if (recipient != null && recipient.isNotEmpty) {
        final noteText = (adminNote != null && adminNote.trim().isNotEmpty) ? " Note: $adminNote" : "";
        final notifDocId = "${recipient}_maint_${requestId}_$status";
        await _db.collection('notifications').doc(notifDocId).set(NotificationModel(
          id: notifDocId,
          toUid: recipient,
          propertyId: ticket.propertyId.isNotEmpty ? ticket.propertyId : AppConfig.defaultPropertyId,
          type: 'maintenance',
          title: 'Maintenance Status: ${status.toUpperCase()}',
          message: "Maintenance Complaint '${ticket.title}' status updated to ${status.toUpperCase()}.$noteText",
          priority: status == 'resolved' ? 'gentle' : 'info',
          relatedRecordId: requestId,
          read: false,
          createdAt: DateTime.now(),
        ).toMap(), SetOptions(merge: true));
      }
    }
  }

  // Create & broadcast property notice to tenant dashboards
  Future<void> createNotice(NoticeModel notice) async {
    final docRef = await _db.collection('notices').add(notice.toMap());

    try {
      final usersSnap = await _db.collection('users').get();
      for (var userDoc in usersSnap.docs) {
        final data = userDoc.data();
        final role = (data['role'] as String? ?? '').toLowerCase();
        if (role == 'renter') {
          final uid = userDoc.id;
          final notifDocId = "${uid}_notice_${docRef.id}";
          await _db.collection('notifications').doc(notifDocId).set(NotificationModel(
            id: notifDocId,
            toUid: uid,
            propertyId: notice.propertyId,
            type: 'notice',
            title: notice.title.isNotEmpty ? notice.title : 'Property Announcement',
            message: notice.message,
            priority: notice.type == 'warning' ? 'warning' : 'info',
            relatedRecordId: docRef.id,
            read: false,
            createdAt: DateTime.now(),
          ).toMap(), SetOptions(merge: true));
        }
      }
    } catch (_) {}
  }

  // Delete notice / retract broadcast
  Future<void> deleteNotice(String noticeId) async {
    if (noticeId.isNotEmpty) {
      await _db.collection('notices').doc(noticeId).delete();
    }
  }

  // Stream property notices for owner with fallback support
  Stream<List<NoticeModel>> streamPropertyNotices(String propertyId) {
    final targetPropId = propertyId.isNotEmpty ? propertyId : AppConfig.defaultPropertyId;
    return _db.collection('notices').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => NoticeModel.fromMap(d.data(), d.id))
          .where((n) {
            return n.propertyId == targetPropId ||
                n.propertyId.isEmpty ||
                targetPropId.contains(n.propertyId) ||
                n.propertyId.contains(targetPropId);
          })
          .toList();
      list.sort((a, b) => b.postedAt.compareTo(a.postedAt));
      return list;
    });
  }

  // Log utility sub-meter reading & create bill
  Future<void> createUtilityBill(Map<String, dynamic> data) async {
    await _db.collection('utilityBills').add(data);
  }

  // Stream utility bills for property
  Stream<List<Map<String, dynamic>>> streamUtilityBills(String propertyId) {
    return _db
        .collection('utilityBills')
        .where('propertyId', isEqualTo: propertyId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // Stream gate passes for PG / Hostel / Enclave
  Stream<List<Map<String, dynamic>>> streamGatePasses(String propertyId) {
    return _db
        .collection('gatePasses')
        .where('propertyId', isEqualTo: propertyId)
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

  // Update gate pass status (Approve / Reject)
  Future<void> updateGatePassStatus(String gatePassId, String status, String? adminComment) async {
    final updates = <String, dynamic>{'status': status};
    if (adminComment != null) updates['adminComment'] = adminComment;
    await _db.collection('gatePasses').doc(gatePassId).update(updates);
  }

  // Stream visitor pre-approvals / logs
  Stream<List<Map<String, dynamic>>> streamVisitorLogs(String propertyId) {
    return _db
        .collection('visitorLogs')
        .where('propertyId', isEqualTo: propertyId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // Set / Update mess menu for a day
  Future<void> saveMessMenu({
    required String propertyId,
    required String dayOfWeek,
    required String breakfast,
    required String lunch,
    required String snacks,
    required String dinner,
  }) async {
    final query = await _db
        .collection('messMenus')
        .where('propertyId', isEqualTo: propertyId)
        .where('dayOfWeek', isEqualTo: dayOfWeek)
        .limit(1)
        .get();

    final data = {
      'propertyId': propertyId,
      'dayOfWeek': dayOfWeek,
      'breakfast': breakfast,
      'lunch': lunch,
      'snacks': snacks,
      'dinner': dinner,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update(data);
    } else {
      await _db.collection('messMenus').add(data);
    }
  }

  // Stream mess menus for property
  Stream<List<Map<String, dynamic>>> streamMessMenus(String propertyId) {
    return _db
        .collection('messMenus')
        .where('propertyId', isEqualTo: propertyId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // Fresh Start: Purge all test deals, payment records, renter accounts, and reset units
  Future<void> wipeAllRenterDataAndDeals({bool wipeUnits = false}) async {
    final dealsSnap = await _db.collection('deals').get();
    for (var doc in dealsSnap.docs) {
      await doc.reference.delete();
    }

    final recsSnap = await _db.collection('paymentRecords').get();
    for (var doc in recsSnap.docs) {
      await doc.reference.delete();
    }

    final usersSnap = await _db.collection('users').get();
    for (var doc in usersSnap.docs) {
      final role = (doc.data()['role'] as String? ?? '').toLowerCase();
      final isOwner = doc.data()['isOwner'] == true;
      if (role != 'admin' && role != 'owner' && !isOwner) {
        await doc.reference.delete();
      }
    }

    final unitsSnap = await _db.collection('units').get();
    for (var doc in unitsSnap.docs) {
      if (wipeUnits) {
        await doc.reference.delete();
      } else {
        await doc.reference.update({
          'status': 'vacant',
          'currentRenterId': FieldValue.delete(),
        });
      }
    }

    final maintSnap = await _db.collection('maintenanceRequests').get();
    for (var doc in maintSnap.docs) {
      await doc.reference.delete();
    }

    final gpSnap = await _db.collection('gatePasses').get();
    for (var doc in gpSnap.docs) {
      await doc.reference.delete();
    }

    final noticesSnap = await _db.collection('notices').get();
    for (var doc in noticesSnap.docs) {
      await doc.reference.delete();
    }

    final notifSnap = await _db.collection('notifications').get();
    for (var doc in notifSnap.docs) {
      await doc.reference.delete();
    }

    final utilSnap = await _db.collection('utilityBills').get();
    for (var doc in utilSnap.docs) {
      await doc.reference.delete();
    }

    final messSnap = await _db.collection('messMenus').get();
    for (var doc in messSnap.docs) {
      await doc.reference.delete();
    }
  }
}
