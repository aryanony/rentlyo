import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_model.dart';
import '../models/deal_model.dart';
import '../models/payment_record_model.dart';
import '../core/rent_engine.dart';

class SmartNotificationService {
  static final SmartNotificationService _instance = SmartNotificationService._internal();
  factory SmartNotificationService() => _instance;
  SmartNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotificationsPlugin.initialize(initSettings);

      final androidPlatform = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.requestNotificationsPermission();
      }

      _initialized = true;
    } catch (e) {
      debugPrint("Local Notification init warning: $e");
    }
  }

  // Show status bar popup notification in phone's notification panel
  Future<void> showPhonePanelNotification({
    required int id,
    required String title,
    required String body,
    String priority = 'info',
  }) async {
    await init();
    try {
      final isWarning = priority == 'warning' || priority == 'urgent';

      final androidDetails = AndroidNotificationDetails(
        isWarning ? 'rent_warnings_channel' : 'rent_reminders_channel',
        isWarning ? 'Rent Overdue & Urgent Warnings' : 'Rent Cycle & Payment Updates',
        channelDescription: 'Notifications for rent payment reminders and dues status',
        importance: isWarning ? Importance.max : Importance.high,
        priority: isWarning ? Priority.max : Priority.high,
        color: isWarning ? const Color(0xFFC53030) : const Color(0xFF0D9488),
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      await _localNotificationsPlugin.show(id, title, body, details);
    } catch (e) {
      debugPrint("Error showing phone panel notification: $e");
    }
  }

  // Admin trigger to send priority notification to a renter
  Future<void> sendPriorityNotificationToRenter({
    required String toUid,
    required String propertyId,
    required String title,
    required String message,
    required String priority,
    required String type,
    String? docId,
  }) async {
    final notif = NotificationModel(
      id: docId ?? '',
      toUid: toUid,
      propertyId: propertyId,
      type: type,
      title: title,
      message: message,
      priority: priority,
      read: false,
      createdAt: DateTime.now(),
    );

    if (docId != null && docId.isNotEmpty) {
      await _db.collection('notifications').doc(docId).set(notif.toMap(), SetOptions(merge: true));
    } else {
      await _db.collection('notifications').add(notif.toMap());
    }

    await showPhonePanelNotification(
      id: docId != null ? docId.hashCode : DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: message,
      priority: priority,
    );
  }

  // Run automated overdue audit across all active deals
  Future<void> runAutomatedRentRemindersAudit(String propertyId) async {
    final now = DateTime.now();
    final periodMonth = RentEngine.formatPeriodMonth(now);

    final dealsSnap = await _db
        .collection('deals')
        .where('propertyId', isEqualTo: propertyId)
        .where('status', isEqualTo: 'active')
        .get();

    for (var doc in dealsSnap.docs) {
      final deal = DealModel.fromMap(doc.data(), doc.id);
      final dueDate = RentEngine.getDueDate(deal, periodMonth);
      final daysPastDue = now.difference(dueDate).inDays;

      // Check payment status for current period using RentEngine ledger rebalancing
      final recSnap = await _db
          .collection('paymentRecords')
          .where('dealId', isEqualTo: deal.id)
          .get();

      final rawRecords = recSnap.docs
          .map((d) => PaymentRecordModel.fromMap(d.data(), d.id))
          .toList();

      final rebalanced = RentEngine.rebalanceLedgerRecords(rawRecords, deal);
      PaymentRecordModel? currentRec;
      for (var r in rebalanced) {
        if (r.periodMonth == periodMonth) {
          currentRec = r;
          break;
        }
      }

      final isAdvanceCovered = currentRec?.paymentSource == 'advance' ||
          currentRec?.status == 'adjusted-against-advance';

      final isPaidOrSettled = isAdvanceCovered ||
          (currentRec != null && currentRec.amountPending <= 0) ||
          (currentRec?.status == 'paid' ||
              currentRec?.status == 'submitted' ||
              currentRec?.status == 'confirmed-paid' ||
              currentRec?.status == 'pending-confirmation');

      final overdueDocId = "${deal.renterUserId}_rent-overdue-warning_$periodMonth";
      final overdueDocRef = _db.collection('notifications').doc(overdueDocId);

      if (!isPaidOrSettled && daysPastDue >= 5) {
        final overdueSnap = await overdueDocRef.get();

        if (!overdueSnap.exists) {
          await sendPriorityNotificationToRenter(
            toUid: deal.renterUserId,
            propertyId: propertyId,
            title: "Rent Overdue",
            message: "Rent for $periodMonth (₹${deal.startingRent.toInt()}) is unpaid by $daysPastDue days. Please clear dues.",
            priority: "warning",
            type: "rent-overdue-warning",
            docId: overdueDocId,
          );
        }
      } else if (isPaidOrSettled) {
        final overdueSnap = await overdueDocRef.get();
        if (overdueSnap.exists) {
          await overdueDocRef.delete();
        }

        // Also purge any custom/legacy overdue warning notifications for this user & period
        try {
          final querySnap = await _db
              .collection('notifications')
              .where('toUid', isEqualTo: deal.renterUserId)
              .get();
          for (var doc in querySnap.docs) {
            final data = doc.data();
            final type = data['type'] as String? ?? '';
            final msg = (data['message'] as String? ?? '').toLowerCase();
            final title = (data['title'] as String? ?? '').toLowerCase();
            final priority = data['priority'] as String? ?? '';

            bool isOverdueNotif = type == 'rent-overdue-warning' ||
                title.contains('overdue') ||
                priority == 'warning' ||
                msg.contains('unpaid by');

            if (isOverdueNotif) {
              await doc.reference.delete();
            }
          }
        } catch (_) {}
      }
    }
  }
}

