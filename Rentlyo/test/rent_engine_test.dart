import 'package:flutter_test/flutter_test.dart';
import 'package:rentlyo_renter/core/rent_engine.dart';
import 'package:rentlyo_renter/models/deal_model.dart';
import 'package:rentlyo_renter/models/payment_record_model.dart';

void main() {
  group('RentEngine Unit Tests v2.2', () {
    final DateTime startDate = DateTime(2026, 1, 1);

    final dealWithSchedule = DealModel(
      id: 'deal_1',
      propertyId: 'prop_1',
      currentUnitId: 'unit_1',
      renterId: 'renter_1',
      renterType: 'commercial',
      dealStartDate: startDate,
      rentSchedule: [
        RentScheduleItem(effectiveFromDate: DateTime(2026, 1, 1), monthlyRent: 8000.0),
        RentScheduleItem(effectiveFromDate: DateTime(2027, 1, 1), monthlyRent: 10000.0),
        RentScheduleItem(effectiveFromDate: DateTime(2028, 1, 1), monthlyRent: 12000.0),
      ],
      rentDueDayOfMonth: 5,
      advanceTransactions: [
        AdvanceTransactionItem(date: startDate, amount: 96000.0, note: 'Initial Advance'),
      ],
      advanceConsumptionMode: true,
      unitHistory: [
        UnitHistoryItem(unitId: 'unit_1', fromDate: startDate, toDate: null),
      ],
      amenities: [
        AmenityItem(name: 'Water Supply', applicable: true),
      ],
      carryForwardPendingBalance: true,
      status: 'active',
      notes: 'Test commercial deal v2.2',
      createdAt: startDate,
      updatedAt: startDate,
    );

    test('Month 1 to 12 effective rent matches base rent', () {
      expect(RentEngine.getEffectiveRent(dealWithSchedule, 1), 8000.0);
      expect(RentEngine.getEffectiveRent(dealWithSchedule, 6), 8000.0);
      expect(RentEngine.getEffectiveRent(dealWithSchedule, 12), 8000.0);
    });

    test('Month 13 to 24 effective rent matches month 13 step-up', () {
      expect(RentEngine.getEffectiveRent(dealWithSchedule, 13), 10000.0);
      expect(RentEngine.getEffectiveRent(dealWithSchedule, 24), 10000.0);
    });

    test('Month 25 effective rent matches month 25 step-up', () {
      expect(RentEngine.getEffectiveRent(dealWithSchedule, 25), 12000.0);
    });

    test('Payment source is advance for months 1..12 and direct thereafter', () {
      expect(RentEngine.getPaymentSource(dealWithSchedule, 1), 'advance');
      expect(RentEngine.getPaymentSource(dealWithSchedule, 12), 'advance');
      expect(RentEngine.getPaymentSource(dealWithSchedule, 13), 'direct');
    });

    test('Running advance balance decrements correctly', () {
      // Month 1: 96000 - 0 deducted = 96000
      expect(RentEngine.getRunningAdvanceBalance(dealWithSchedule, 1), 96000.0);
      // Month 13: 96000 - (12 * 8000) = 0
      expect(RentEngine.getRunningAdvanceBalance(dealWithSchedule, 13), 0.0);
    });

    test('Month index calculation', () {
      expect(RentEngine.getMonthIndex(startDate, DateTime(2026, 1, 15)), 1);
      expect(RentEngine.getMonthIndex(startDate, DateTime(2026, 8, 1)), 8);
      expect(RentEngine.getMonthIndex(startDate, DateTime(2027, 1, 1)), 13);
    });

    test('DueDate calculation', () {
      final dueDate = RentEngine.getDueDate(dealWithSchedule, '2026-08');
      expect(dueDate.year, equals(2026));
      expect(dueDate.month, equals(8));
      expect(dueDate.day, equals(5));
    });
    test('Mid-cycle advance top-up enables advance payment source for subsequent months', () {
      final dealWithTopUp = DealModel(
        id: 'deal_topup',
        propertyId: 'prop_1',
        currentUnitId: 'unit_1',
        renterId: 'renter_1',
        renterType: 'commercial',
        dealStartDate: startDate,
        rentSchedule: [
          RentScheduleItem(effectiveFromDate: DateTime(2026, 1, 1), monthlyRent: 8000.0),
          RentScheduleItem(effectiveFromDate: DateTime(2027, 1, 1), monthlyRent: 10000.0),
        ],
        rentDueDayOfMonth: 5,
        advanceTransactions: [
          AdvanceTransactionItem(date: startDate, amount: 96000.0, note: 'Initial Advance'),
          // Top-up deposited in Month 13 (January 2027) of ₹20,000
          AdvanceTransactionItem(date: DateTime(2027, 1, 15), amount: 20000.0, note: 'Mid-term Top-up'),
        ],
        advanceConsumptionMode: true,
        unitHistory: [
          UnitHistoryItem(unitId: 'unit_1', fromDate: startDate, toDate: null),
        ],
        amenities: [],
        carryForwardPendingBalance: true,
        status: 'active',
        notes: 'Deal with top-up test',
        createdAt: startDate,
        updatedAt: startDate,
      );

      // Months 1..12 covered by 96,000 (8000 * 12)
      expect(RentEngine.getPaymentSource(dealWithTopUp, 1), 'advance');
      expect(RentEngine.getPaymentSource(dealWithTopUp, 12), 'advance');

      // Month 13 rent is 10,000. Balance before month 13 = 0 + 20,000 = 20,000 >= 10,000.
      expect(RentEngine.getPaymentSource(dealWithTopUp, 13), 'advance');

      // Month 14 rent is 10,000. Balance before month 14 = 20,000 - 10,000 = 10,000 >= 10,000.
      expect(RentEngine.getPaymentSource(dealWithTopUp, 14), 'advance');

      // Month 15 rent is 10,000. Balance before month 15 = 10,000 - 10,000 = 0 < 10,000.
      expect(RentEngine.getPaymentSource(dealWithTopUp, 15), 'direct');

      // Check balance as of Month 14
      expect(RentEngine.getRunningAdvanceBalance(dealWithTopUp, DateTime(2027, 2, 20)), 0.0);
    });

    test('Non-consumption mode holds entire advance as refundable security', () {
      final refundableDeal = DealModel(
        id: 'deal_refund',
        propertyId: 'prop_1',
        currentUnitId: 'unit_1',
        renterId: 'renter_1',
        renterType: 'commercial',
        dealStartDate: startDate,
        rentSchedule: [
          RentScheduleItem(effectiveFromDate: DateTime(2026, 1, 1), monthlyRent: 8000.0),
        ],
        rentDueDayOfMonth: 5,
        advanceTransactions: [
          AdvanceTransactionItem(date: startDate, amount: 50000.0, note: 'Security Deposit'),
        ],
        advanceConsumptionMode: false,
        unitHistory: [
          UnitHistoryItem(unitId: 'unit_1', fromDate: startDate, toDate: null),
        ],
        amenities: [],
        carryForwardPendingBalance: true,
        status: 'active',
        notes: 'Pure deposit deal',
        createdAt: startDate,
        updatedAt: startDate,
      );

      // In non-consumption mode, all months are direct payments
      expect(RentEngine.getPaymentSource(refundableDeal, 1), 'direct');
      expect(RentEngine.getPaymentSource(refundableDeal, 6), 'direct');
      expect(RentEngine.getPaymentSource(refundableDeal, 12), 'direct');

      // Running advance balance remains intact (50,000)
      expect(RentEngine.getRunningAdvanceBalance(refundableDeal, 1), 50000.0);
      expect(RentEngine.getRunningAdvanceBalance(refundableDeal, DateTime(2026, 6, 1)), 50000.0);
    });

    test('Custom advance deduction range restricts advance consumption to specific months', () {
      final windowedDeal = DealModel(
        id: 'deal_window',
        propertyId: 'prop_1',
        currentUnitId: 'unit_1',
        renterId: 'renter_1',
        renterType: 'commercial',
        dealStartDate: startDate,
        rentSchedule: [
          RentScheduleItem(effectiveFromDate: DateTime(2026, 1, 1), monthlyRent: 8000.0),
        ],
        rentDueDayOfMonth: 5,
        advanceTransactions: [
          AdvanceTransactionItem(date: startDate, amount: 96000.0, note: 'Initial Advance'),
        ],
        advanceConsumptionMode: true,
        advanceDeductStartMonth: '2026-03',
        advanceDeductEndMonth: '2026-06',
        unitHistory: [
          UnitHistoryItem(unitId: 'unit_1', fromDate: startDate, toDate: null),
        ],
        amenities: [],
        carryForwardPendingBalance: true,
        status: 'active',
        notes: 'Windowed deal',
        createdAt: startDate,
        updatedAt: startDate,
      );

      // Months 1 & 2 (Jan & Feb) are outside deduction range -> direct
      expect(RentEngine.getPaymentSource(windowedDeal, 1), 'direct');
      expect(RentEngine.getPaymentSource(windowedDeal, 2), 'direct');

      // Months 3 to 6 (March to June) are inside range -> advance
      expect(RentEngine.getPaymentSource(windowedDeal, 3), 'advance');
      expect(RentEngine.getPaymentSource(windowedDeal, 4), 'advance');
      expect(RentEngine.getPaymentSource(windowedDeal, 5), 'advance');
      expect(RentEngine.getPaymentSource(windowedDeal, 6), 'advance');

      // Month 7 (July) is outside range -> direct
      expect(RentEngine.getPaymentSource(windowedDeal, 7), 'direct');
    });

    test('Part-by-part installment payments update status from confirmed-partial to confirmed-paid', () {
      final directDeal = DealModel(
        id: 'deal_part_test',
        propertyId: 'prop_1',
        currentUnitId: 'unit_1',
        renterId: 'renter_1',
        renterType: 'residential',
        dealStartDate: startDate,
        rentSchedule: [
          RentScheduleItem(effectiveFromDate: DateTime(2026, 1, 1), monthlyRent: 10000.0),
        ],
        rentDueDayOfMonth: 5,
        advanceTransactions: [],
        advanceConsumptionMode: false,
        unitHistory: [
          UnitHistoryItem(unitId: 'unit_1', fromDate: startDate, toDate: null),
        ],
        amenities: [],
        carryForwardPendingBalance: true,
        status: 'active',
        notes: 'Installment test',
        createdAt: startDate,
        updatedAt: startDate,
      );

      // Part 1: Tenant pays ₹5,000 (Half of ₹10,000 rent)
      final recordPart1 = PaymentRecordModel(
        id: 'deal_part_test_2026-01',
        dealId: 'deal_part_test',
        renterId: 'renter_1',
        propertyId: 'prop_1',
        unitId: 'unit_1',
        periodMonth: '2026-01',
        monthIndex: 1,
        effectiveRent: 10000.0,
        paymentSource: 'direct',
        dueFromRenter: 10000.0,
        carriedOverDue: 0.0,
        installments: [
          PaymentInstallment(
            amount: 5000.0,
            date: DateTime(2026, 1, 5),
            method: 'upi',
            note: 'Half rent part 1',
            addedBy: 'renter',
          ),
        ],
        totalPaid: 5000.0,
        amountPending: 5000.0,
        status: 'confirmed-partial',
      );

      final rebalancedPart1 = RentEngine.rebalanceLedgerRecords([recordPart1], directDeal);
      final janRecPart1 = rebalancedPart1.firstWhere((r) => r.periodMonth == '2026-01');
      expect(janRecPart1.totalPaid, 5000.0);
      expect(janRecPart1.amountPending, 5000.0);
      expect(janRecPart1.status, 'confirmed-partial');
      expect(janRecPart1.installments.length, 1);
      expect(janRecPart1.installments[0].amount, 5000.0);

      // Part 2: Tenant pays remaining ₹5,000
      final recordPart2 = PaymentRecordModel(
        id: 'deal_part_test_2026-01',
        dealId: 'deal_part_test',
        renterId: 'renter_1',
        propertyId: 'prop_1',
        unitId: 'unit_1',
        periodMonth: '2026-01',
        monthIndex: 1,
        effectiveRent: 10000.0,
        paymentSource: 'direct',
        dueFromRenter: 10000.0,
        carriedOverDue: 0.0,
        installments: [
          PaymentInstallment(
            amount: 5000.0,
            date: DateTime(2026, 1, 5),
            method: 'upi',
            note: 'Half rent part 1',
            addedBy: 'renter',
          ),
          PaymentInstallment(
            amount: 5000.0,
            date: DateTime(2026, 1, 18),
            method: 'cash',
            note: 'Remaining half rent part 2',
            addedBy: 'owner',
          ),
        ],
        totalPaid: 10000.0,
        amountPending: 0.0,
        status: 'confirmed-paid',
      );

      final rebalancedPart2 = RentEngine.rebalanceLedgerRecords([recordPart2], directDeal);
      final janRecPart2 = rebalancedPart2.firstWhere((r) => r.periodMonth == '2026-01');
      expect(janRecPart2.totalPaid, 10000.0);
      expect(janRecPart2.amountPending, 0.0);
      expect(janRecPart2.status, 'confirmed-paid');
      expect(janRecPart2.installments.length, 2);
      expect(janRecPart2.installments[0].amount, 5000.0);
      expect(janRecPart2.installments[1].amount, 5000.0);
      expect(janRecPart2.installments[1].method, 'cash');
    });
  });
}
