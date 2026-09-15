import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
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
  final Set<String> _processingKeys = {};

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

      // Request Android 13+ permission
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

  // Automatic Rent Cycle & Overdue Warning Checker Engine
  Future<void> checkAndGenerateRentNotifications({
    required String userUid,
    required String propertyId,
    required DealModel deal,
    required List<PaymentRecordModel> payments,
  }) async {
    final now = DateTime.now();
    final periodMonth = RentEngine.formatPeriodMonth(now);

    final lockKey = "${userUid}_$periodMonth";
    if (_processingKeys.contains(lockKey)) return;
    _processingKeys.add(lockKey);

    try {
      List<PaymentRecordModel> effectivePayments = payments;
      if (effectivePayments.isEmpty) {
        final snap = await _db
            .collection('paymentRecords')
            .where('dealId', isEqualTo: deal.id)
            .get();
        if (snap.docs.isNotEmpty) {
          effectivePayments = snap.docs.map((d) => PaymentRecordModel.fromMap(d.data(), d.id)).toList();
        }
      }

      // Rebalance payments ledger to obtain 100% accurate current status
      final rebalanced = RentEngine.rebalanceLedgerRecords(effectivePayments, deal);
      PaymentRecordModel? currentRec;
      for (var r in rebalanced) {
        if (r.periodMonth == periodMonth) {
          currentRec = r;
          break;
        }
      }

      // Check advance cover and payment status
      final isAdvanceCovered = currentRec?.paymentSource == 'advance' ||
          currentRec?.status == 'adjusted-against-advance';

      final isPaidOrSettled = isAdvanceCovered ||
          (currentRec != null && currentRec.amountPending <= 0) ||
          (currentRec?.status == 'paid' ||
              currentRec?.status == 'submitted' ||
              currentRec?.status == 'confirmed-paid' ||
              currentRec?.status == 'pending-confirmation');

      // Determine due date for current month
      final startDay = deal.startDate.day > 28 ? 28 : deal.startDate.day;
      final dueDate = RentEngine.getDueDate(deal, periodMonth);

      // 1. Month Rent Start Date Notification
      if (now.isAfter(dueDate) || now.day >= startDay) {
        final startDocId = "${userUid}_rent-cycle-start_$periodMonth";
        final startDocRef = _db.collection('notifications').doc(startDocId);
        final startSnap = await startDocRef.get();

        final String notificationTitle;
        final String notificationBody;
        final String notificationPriority;

        if (isAdvanceCovered) {
          notificationTitle = "Rent Covered (Advance)";
          notificationBody = "Rent for $periodMonth (₹${deal.startingRent.toInt()}) is fully covered from your advance balance.";
          notificationPriority = "gentle";
        } else if (isPaidOrSettled) {
          notificationTitle = "Rent Settled";
          notificationBody = "Rent for $periodMonth (₹${deal.startingRent.toInt()}) has been fully paid & confirmed.";
          notificationPriority = "gentle";
        } else if (currentRec != null && currentRec.amountPending < currentRec.effectiveRent && currentRec.amountPending > 0) {
          notificationTitle = "Rent Partial Payment";
          notificationBody = "Rent for $periodMonth: ₹${currentRec.totalPaid.toInt()} paid, ₹${currentRec.amountPending.toInt()} remaining balance.";
          notificationPriority = "info";
        } else {
          notificationTitle = "Rent Cycle Started";
          notificationBody = "Rent for $periodMonth (₹${deal.startingRent.toInt()}) is due on ${DateFormat('dd MMM yyyy').format(dueDate)}.";
          notificationPriority = "info";
        }

        if (!startSnap.exists) {
          final notif = NotificationModel(
            id: startDocId,
            toUid: userUid,
            propertyId: propertyId,
            type: 'rent-cycle-start',
            title: notificationTitle,
            message: notificationBody,
            priority: notificationPriority,
            read: false,
            createdAt: DateTime.now(),
          );

          await startDocRef.set(notif.toMap(), SetOptions(merge: true));
          await showPhonePanelNotification(
            id: startDocId.hashCode,
            title: notificationTitle,
            body: notificationBody,
            priority: notificationPriority,
          );
        } else {
          // If notification already exists, sync title & message to current live ledger state
          final existingData = startSnap.data();
          final existingMsg = existingData?['message'] as String? ?? '';
          final existingTitle = existingData?['title'] as String? ?? '';
          if (existingMsg != notificationBody || existingTitle != notificationTitle) {
            await startDocRef.update({
              'title': notificationTitle,
              'message': notificationBody,
              'priority': notificationPriority,
            });
          }
        }
      }

      // 2. 5+ Days Overdue Payment Warning Notification (ONLY if unpaid and not covered by advance)
      final daysPastDue = now.difference(dueDate).inDays;
      final overdueDocId = "${userUid}_rent-overdue-warning_$periodMonth";
      final overdueDocRef = _db.collection('notifications').doc(overdueDocId);

      if (!isPaidOrSettled && daysPastDue >= 5) {
        final overdueSnap = await overdueDocRef.get();

        if (!overdueSnap.exists) {
          const title = "Rent Overdue";
          final body = "Rent for $periodMonth (₹${deal.startingRent.toInt()}) is unpaid by $daysPastDue days. Please clear dues.";

          final notif = NotificationModel(
            id: overdueDocId,
            toUid: userUid,
            propertyId: propertyId,
            type: 'rent-overdue-warning',
            title: title,
            message: body,
            priority: 'warning',
            read: false,
            createdAt: DateTime.now(),
          );

          await overdueDocRef.set(notif.toMap(), SetOptions(merge: true));
          await showPhonePanelNotification(
            id: overdueDocId.hashCode,
            title: title,
            body: body,
            priority: 'warning',
          );
        }
      } else if (isPaidOrSettled) {
        // Purge overdue warning notification if rent has been settled or covered by advance
        final overdueSnap = await overdueDocRef.get();
        if (overdueSnap.exists) {
          await overdueDocRef.delete();
        }

        // Also purge any legacy or custom overdue warning notifications for this user & period
        try {
          final querySnap = await _db
              .collection('notifications')
              .where('toUid', isEqualTo: userUid)
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
    } catch (e) {
      debugPrint("Error in checkAndGenerateRentNotifications: $e");
    } finally {
      _processingKeys.remove(lockKey);
    }
  }
}

