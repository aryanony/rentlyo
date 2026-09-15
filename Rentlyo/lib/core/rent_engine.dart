import 'dart:math' as math;
import '../models/deal_model.dart';
import '../models/payment_record_model.dart';

class MonthAdvanceState {
  final int monthIndex;
  final String periodMonth;
  final double topUpsDepositedInMonth;
  final double advanceBalanceBeforeRent;
  final double effectiveRent;
  final String paymentSource; // 'advance' | 'direct'
  final double advanceDeductedThisMonth;
  final double advanceBalanceAfterRent;

  MonthAdvanceState({
    required this.monthIndex,
    required this.periodMonth,
    required this.topUpsDepositedInMonth,
    required this.advanceBalanceBeforeRent,
    required this.effectiveRent,
    required this.paymentSource,
    required this.advanceDeductedThisMonth,
    required this.advanceBalanceAfterRent,
  });
}

class RentEngine {
  /// Pure business logic: Waterfall allocation of all cash collected for a deal across all months.
  /// Rebalances any list of raw PaymentRecordModels in memory for instant, 100% accurate display.
  static List<PaymentRecordModel> rebalanceLedgerRecords(
    List<PaymentRecordModel> rawRecords,
    DealModel deal,
  ) {
    final now = DateTime.now();
    final maxMonthIndex = getMonthIndex(deal.dealStartDate, now);

    final mapByPeriod = <String, PaymentRecordModel>{};
    for (var rec in rawRecords) {
      if (rec.dealId == deal.id) {
        final key = rec.periodMonth.isNotEmpty ? rec.periodMonth : 'm_${rec.monthIndex}';
        mapByPeriod[key] = rec;
      }
    }

    final periodMonths = <String>[];
    for (int m = 1; m <= maxMonthIndex; m++) {
      final mDate = DateTime(deal.dealStartDate.year, deal.dealStartDate.month + (m - 1), deal.dealStartDate.day);
      periodMonths.add(formatPeriodMonth(mDate));
    }

    double totalCashCollected = 0.0;
    for (var rec in mapByPeriod.values) {
      if (rec.paymentSource == 'direct') {
        double instSum = rec.installments.fold(0.0, (acc, item) => acc + item.amount);
        double recCash = math.max(rec.totalPaid, instSum);
        totalCashCollected += recCash;
      }
    }

    double remainingCash = totalCashCollected;
    double runningArrears = 0.0;
    final result = <PaymentRecordModel>[];

    for (int i = 0; i < maxMonthIndex; i++) {
      final mIndex = i + 1;
      final periodMonth = periodMonths[i];
      final dueDate = getDueDate(deal, periodMonth);
      final deterministicDocId = '${deal.id}_$periodMonth';

      final rent = getEffectiveRent(deal, mIndex);
      final source = getPaymentSource(deal, mIndex);

      final existingRec = mapByPeriod[periodMonth];

      double dueThisMonth;
      double thisMonthPaid;
      double amountPending;
      String status;
      final installments = existingRec?.installments ?? [];

      double carriedOverForThisMonth = runningArrears;

      if (source == 'advance') {
        dueThisMonth = 0.0;
        thisMonthPaid = rent;
        amountPending = 0.0;
        status = 'adjusted-against-advance';
      } else {
        dueThisMonth = rent;
        thisMonthPaid = math.min(remainingCash, dueThisMonth);
        remainingCash -= thisMonthPaid;
        amountPending = (dueThisMonth - thisMonthPaid).clamp(0.0, double.infinity);
        runningArrears += amountPending;

        final isOverdue = now.isAfter(dueDate) && amountPending > 0;
        final hasPendingConfirmation = existingRec?.status == 'pending-confirmation';

        if (hasPendingConfirmation && amountPending > 0) {
          status = 'pending-confirmation';
        } else if (amountPending == 0) {
          status = 'confirmed-paid';
        } else if (thisMonthPaid > 0) {
          status = 'confirmed-partial';
        } else if (isOverdue) {
          status = 'overdue';
        } else {
          status = 'pending';
        }
      }

      final record = PaymentRecordModel(
        id: existingRec?.id ?? deterministicDocId,
        dealId: deal.id,
        renterId: deal.renterId,
        propertyId: deal.propertyId,
        unitId: deal.currentUnitId.isNotEmpty ? deal.currentUnitId : deal.unitId,
        periodMonth: periodMonth,
        monthIndex: mIndex,
        effectiveRent: rent,
        dueDate: dueDate,
        paymentSource: source,
        dueFromRenter: dueThisMonth,
        carriedOverDue: carriedOverForThisMonth,
        installments: installments,
        totalPaid: thisMonthPaid,
        amountPending: amountPending,
        status: status,
      );

      result.add(record);
    }

    return result;
  }

  /// Calculate effective rent for a specific date based on rentSchedule v2.2 (calendar-date based)
  /// Finds the entry in deal.rentSchedule with the LATEST effectiveFromDate that is <= forDate
  static double getEffectiveRent(DealModel deal, int monthIndex) {
    final forDate = _monthIndexToDate(deal.dealStartDate, monthIndex);
    return getEffectiveRentForDate(deal, forDate);
  }

  /// Calendar-date-based effective rent lookup (the spec's actual algorithm)
  static double getEffectiveRentForDate(DealModel deal, DateTime forDate) {
    if (deal.rentSchedule.isEmpty) return deal.baseMonthlyRent;

    RentScheduleItem? applicable;
    for (var item in deal.rentSchedule) {
      if (!item.effectiveFromDate.isAfter(forDate)) {
        if (applicable == null || item.effectiveFromDate.isAfter(applicable.effectiveFromDate)) {
          applicable = item;
        }
      }
    }

    return applicable?.monthlyRent ?? deal.baseMonthlyRent;
  }

  /// Check if a periodMonth ("YYYY-MM") is within the configured advance deduction range
  static bool isMonthInAdvanceDeductionRange(DealModel deal, String periodMonth) {
    if (!deal.advanceConsumptionMode) return false;

    if (deal.advanceDeductStartMonth != null && deal.advanceDeductStartMonth!.trim().isNotEmpty) {
      if (periodMonth.compareTo(deal.advanceDeductStartMonth!.trim()) < 0) {
        return false;
      }
    }

    if (deal.advanceDeductEndMonth != null && deal.advanceDeductEndMonth!.trim().isNotEmpty) {
      if (periodMonth.compareTo(deal.advanceDeductEndMonth!.trim()) > 0) {
        return false;
      }
    }

    return true;
  }

  /// Chronologically simulates the month-by-month advance ledger timeline for a deal.
  /// Handles initial move-in advance, mid-cycle top-ups, step-up rent escalations,
  /// and consumption window restrictions without any calculation drift.
  static List<MonthAdvanceState> getAdvanceTimeline(DealModel deal, [int? maxMonthIndex]) {
    final maxMonths = maxMonthIndex ?? getMonthIndex(deal.dealStartDate, DateTime.now());
    final timeline = <MonthAdvanceState>[];

    if (deal.advanceTransactions.isEmpty && !deal.advanceConsumptionMode) {
      return timeline;
    }

    // Sort transactions chronologically
    final sortedTx = List<AdvanceTransactionItem>.from(deal.advanceTransactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    double runningAdvanceBalance = 0.0;

    for (int m = 1; m <= maxMonths; m++) {
      final monthStart = _monthIndexToDate(deal.dealStartDate, m);
      // End of this month period (e.g. last millisecond of the month)
      final nextMonthStart = _monthIndexToDate(deal.dealStartDate, m + 1);
      final periodStr = formatPeriodMonth(monthStart);

      // Accumulate all top-ups that landed in or prior to this month window
      double topUpsThisMonth = 0.0;
      if (m == 1) {
        // In month 1, capture initial advance and anything deposited before/during month 1
        for (var tx in sortedTx) {
          if (!tx.date.isAfter(nextMonthStart.subtract(const Duration(milliseconds: 1)))) {
            topUpsThisMonth += tx.amount;
          }
        }
      } else {
        // In month m > 1, capture any top-up deposited specifically within this month's window
        final prevMonthEnd = monthStart.subtract(const Duration(milliseconds: 1));
        final thisMonthEnd = nextMonthStart.subtract(const Duration(milliseconds: 1));
        for (var tx in sortedTx) {
          if (tx.date.isAfter(prevMonthEnd) && !tx.date.isAfter(thisMonthEnd)) {
            topUpsThisMonth += tx.amount;
          }
        }
      }

      runningAdvanceBalance += topUpsThisMonth;
      final balanceBeforeRent = runningAdvanceBalance;
      final rentForMonth = getEffectiveRent(deal, m);

      bool eligibleForAdvanceDeduction = deal.advanceConsumptionMode &&
          isMonthInAdvanceDeductionRange(deal, periodStr);

      String source = 'direct';
      double deducted = 0.0;

      if (eligibleForAdvanceDeduction && runningAdvanceBalance >= rentForMonth && rentForMonth > 0) {
        source = 'advance';
        deducted = rentForMonth;
        runningAdvanceBalance -= rentForMonth;
      }

      timeline.add(MonthAdvanceState(
        monthIndex: m,
        periodMonth: periodStr,
        topUpsDepositedInMonth: topUpsThisMonth,
        advanceBalanceBeforeRent: balanceBeforeRent,
        effectiveRent: rentForMonth,
        paymentSource: source,
        advanceDeductedThisMonth: deducted,
        advanceBalanceAfterRent: math.max(0.0, runningAdvanceBalance),
      ));
    }

    return timeline;
  }

  /// Get the available advance balance available to pay for month [monthIndex] (before that month's deduction).
  static double getAdvanceBalanceBeforeMonth(DealModel deal, int monthIndex) {
    if (!deal.advanceConsumptionMode) return deal.totalAdvanceAmount;
    if (deal.advanceTransactions.isEmpty) return 0.0;

    final timeline = getAdvanceTimeline(deal, math.max(1, monthIndex));
    if (monthIndex <= timeline.length) {
      return timeline[monthIndex - 1].advanceBalanceBeforeRent;
    }
    return timeline.isNotEmpty ? timeline.last.advanceBalanceAfterRent : 0.0;
  }

  /// Calculate running remaining advance balance based on advanceTransactions ledger.
  /// If a DateTime is passed (or omitted), computes remaining balance as of that date (after deductions).
  /// If an integer monthIndex is passed, computes balance available at the start of that month (backward compatibility).
  static double getRunningAdvanceBalance(DealModel deal, [dynamic monthIndexOrDate]) {
    if (!deal.advanceConsumptionMode) return deal.totalAdvanceAmount;
    if (deal.advanceTransactions.isEmpty) return 0.0;

    if (monthIndexOrDate is int) {
      // MonthIndex: Returns advance balance available at the start of that month
      return getAdvanceBalanceBeforeMonth(deal, monthIndexOrDate);
    }

    DateTime targetDate = monthIndexOrDate is DateTime ? monthIndexOrDate : DateTime.now();
    final targetMonthIndex = getMonthIndex(deal.dealStartDate, targetDate);
    final timeline = getAdvanceTimeline(deal, targetMonthIndex);

    if (timeline.isEmpty) return deal.totalAdvanceAmount;

    // Return remaining balance after the target month's deductions
    return timeline.last.advanceBalanceAfterRent;
  }

  /// Determine payment funding source ('advance' vs 'direct') based on running balance
  static String getPaymentSource(DealModel deal, int monthIndex) {
    if (!deal.advanceConsumptionMode) {
      return 'direct';
    }

    final monthDate = _monthIndexToDate(deal.dealStartDate, monthIndex);
    final periodStr = formatPeriodMonth(monthDate);

    if (!isMonthInAdvanceDeductionRange(deal, periodStr)) {
      return 'direct';
    }

    final balanceAtStart = getAdvanceBalanceBeforeMonth(deal, monthIndex);
    final rentDue = getEffectiveRent(deal, monthIndex);

    if (balanceAtStart >= rentDue && rentDue > 0) {
      return 'advance';
    }

    return 'direct';
  }

  /// Compute due date for a specific periodMonth ("YYYY-MM")
  static DateTime getDueDate(DealModel deal, String periodMonth) {
    try {
      final parts = periodMonth.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = deal.rentDueDayOfMonth.clamp(1, 28);
      return DateTime(year, month, day);
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Calculate month index relative to deal start date (1-indexed)
  static int getMonthIndex(DateTime dealStartDate, DateTime targetDate) {
    int yearDiff = targetDate.year - dealStartDate.year;
    int monthDiff = targetDate.month - dealStartDate.month;
    int total = (yearDiff * 12) + monthDiff + 1;
    return math.max(1, total);
  }

  /// Helper to convert DateTime to YYYY-MM period format
  static String formatPeriodMonth(DateTime date) {
    String monthStr = date.month.toString().padLeft(2, '0');
    return "${date.year}-$monthStr";
  }

  /// Convert month index back to a DateTime (for date-based rent lookups)
  static DateTime _monthIndexToDate(DateTime dealStartDate, int monthIndex) {
    int offset = monthIndex - 1;
    return DateTime(dealStartDate.year, dealStartDate.month + offset, 1);
  }
}

