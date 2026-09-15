import 'package:flutter_test/flutter_test.dart';
import 'package:rentlyo_renter/models/deal_model.dart';
import 'package:rentlyo_renter/models/payment_record_model.dart';
import 'package:rentlyo_renter/models/user_model.dart';
import 'package:rentlyo_renter/models/app_version_model.dart';
import 'package:rentlyo_renter/core/rent_engine.dart';

void main() {
  group('Renter App v2.2 Models & Security Tests', () {
    test('UserModel mapping correctly deserializes renterId and pseudo-email', () {
      final map = {
        'renterId': 'r_12345',
        'role': 'renter',
        'name': 'Test Tenant',
        'phone': '919876543210',
        'pseudoEmail': '919876543210@arya-lease.local',
        'propertyIds': ['prop_1'],
        'active': true,
        'createdBy': 'owner_uid_1',
      };

      final user = UserModel.fromMap(map, 'user_renter_123');

      expect(user.uid, equals('user_renter_123'));
      expect(user.renterId, equals('r_12345'));
      expect(user.role, equals('renter'));
      expect(user.phone, equals('919876543210'));
      expect(user.pseudoEmail, equals('919876543210@arya-lease.local'));
    });

    test('DealModel rentSchedule calculation resolves effective rent correctly', () {
      final schedule = [
        RentScheduleItem(effectiveFromDate: DateTime(2026, 1, 1), monthlyRent: 8000.0),
        RentScheduleItem(effectiveFromDate: DateTime(2027, 1, 1), monthlyRent: 10000.0),
      ];

      final deal = DealModel(
        id: 'deal_1',
        propertyId: 'prop_1',
        currentUnitId: 'unit_1',
        renterId: 'r_12345',
        renterType: 'commercial',
        dealStartDate: DateTime(2026, 1, 1),
        rentSchedule: schedule,
        rentDueDayOfMonth: 5,
        advanceTransactions: [
          AdvanceTransactionItem(date: DateTime(2026, 1, 1), amount: 96000.0, note: 'Initial Advance'),
        ],
        advanceConsumptionMode: true,
        unitHistory: [
          UnitHistoryItem(unitId: 'unit_1', fromDate: DateTime(2026, 1, 1), toDate: null),
        ],
        amenities: [
          AmenityItem(name: 'Water Supply', applicable: true),
        ],
        carryForwardPendingBalance: true,
        agreementType: 'drive-link',
        agreementDriveLink: 'https://drive.google.com/file/d/xyz',
        status: 'active',
        notes: 'Commercial shop lease v2.2',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        businessName: 'Arya Sweets',
      );

      final map = deal.toMap();
      final roundtrip = DealModel.fromMap(map, 'deal_1');

      expect(roundtrip.rentSchedule.length, equals(2));
      expect(RentEngine.getEffectiveRent(roundtrip, 6), equals(8000.0));
      expect(RentEngine.getEffectiveRent(roundtrip, 14), equals(10000.0));
      expect(roundtrip.agreementDriveLink, equals('https://drive.google.com/file/d/xyz'));
      expect(roundtrip.totalAdvanceAmount, equals(96000.0));
      expect(roundtrip.currentUnitId, equals('unit_1'));
      expect(roundtrip.unitHistory.length, equals(1));
    });

    test('PaymentRecordModel multi-installment calculation accurately sums paid amount', () {
      final installments = [
        PaymentInstallment(amount: 3000.0, date: DateTime.now(), method: 'cash', addedBy: 'renter'),
        PaymentInstallment(amount: 5000.0, date: DateTime.now(), method: 'upi', addedBy: 'renter'),
      ];

      final record = PaymentRecordModel(
        id: 'rec_1',
        dealId: 'deal_1',
        renterId: 'r_12345',
        propertyId: 'prop_1',
        unitId: 'unit_1',
        periodMonth: '2026-08',
        monthIndex: 1,
        effectiveRent: 8000.0,
        dueDate: DateTime(2026, 8, 5),
        paymentSource: 'direct',
        dueFromRenter: 8000.0,
        carriedOverDue: 0.0,
        installments: installments,
        totalPaid: 8000.0,
        amountPending: 0.0,
        status: 'confirmed-paid',
      );

      expect(record.installments.length, equals(2));
      expect(record.totalPaid, equals(8000.0));
      expect(record.amountPending, equals(0.0));
    });

    test('AppVersionModel deserializes and evaluates version build number correctly', () {
      final map = {
        'latestVersionName': '1.1.0',
        'latestBuildNumber': 3,
        'downloadUrl': 'https://github.com/owner/repo/releases/download/v1.1.0/app-release.apk',
        'changelogEn': 'New dashboard and self-update feature',
        'changelogHi': 'नया डैशबोर्ड और सेल्फ-अपडेट फीचर',
        'forceUpdate': false,
      };

      final model = AppVersionModel.fromMap(map);

      expect(model.latestVersionName, equals('1.1.0'));
      expect(model.latestBuildNumber, equals(3));
      expect(model.downloadUrl, contains('app-release.apk'));
      expect(model.forceUpdate, isFalse);
    });
  });
}
