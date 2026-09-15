import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/localization.dart';
import '../core/rent_engine.dart';
import '../models/payment_record_model.dart';
import '../models/unit_model.dart';
import '../models/deal_model.dart';
import '../services/firestore_service.dart';
import '../services/export_service.dart';
import '../core/brand_config.dart';

class _UnitReportItem {
  final DealModel deal;
  final String unitLabel;
  final String renterName;
  final PaymentRecordModel record;
  final double monthlyRent;
  final double dueThisMonth;
  final double paidThisMonth;
  final double pendingThisMonth;
  final double carriedOverDue;
  final double lifetimeCollected;
  final String status;

  _UnitReportItem({
    required this.deal,
    required this.unitLabel,
    required this.renterName,
    required this.record,
    required this.monthlyRent,
    required this.dueThisMonth,
    required this.paidThisMonth,
    required this.pendingThisMonth,
    required this.carriedOverDue,
    required this.lifetimeCollected,
    required this.status,
  });
}

class ReportsScreen extends StatefulWidget {
  final String propertyId;

  const ReportsScreen({super.key, required this.propertyId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FirestoreService _firestore = FirestoreService();
  late DateTime _selectedMonthDate;
  String _statusFilter = 'all'; // 'all' | 'paid' | 'overdue' | 'advance'

  @override
  void initState() {
    super.initState();
    _selectedMonthDate = DateTime.now();
  }

  void _previousMonth() {
    setState(() {
      _selectedMonthDate = DateTime(_selectedMonthDate.year, _selectedMonthDate.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonthDate = DateTime(_selectedMonthDate.year, _selectedMonthDate.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedPeriod = RentEngine.formatPeriodMonth(_selectedMonthDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalization.tr('reports')),
      ),
      body: StreamBuilder<List<UnitModel>>(
        stream: _firestore.streamUnits(widget.propertyId),
        builder: (context, unitSnap) {
          final units = unitSnap.data ?? [];
          final unitsMap = <String, UnitModel>{for (var u in units) u.id: u};

          return StreamBuilder<List<DealModel>>(
            stream: _firestore.streamDeals(widget.propertyId),
            builder: (context, dealSnap) {
              final deals = dealSnap.data ?? [];
              final activeDeals = deals.where((d) => d.status == 'active').toList();

              return StreamBuilder<List<PaymentRecordModel>>(
                stream: _firestore.streamPaymentRecords(widget.propertyId),
                builder: (context, snapshot) {
                  final allRecords = snapshot.data ?? [];

                  // Group raw records by dealId
                  final recordsByDeal = <String, List<PaymentRecordModel>>{};
                  for (var r in allRecords) {
                    recordsByDeal.putIfAbsent(r.dealId, () => []).add(r);
                  }

                  // Process waterfall rebalanced records for each active deal
                  final unitReportItems = <_UnitReportItem>[];
                  double totalExpectedMonthly = 0.0;
                  double totalCollectedMonthly = 0.0;
                  double totalPendingMonthly = 0.0;
                  double totalAdvanceHeld = 0.0;
                  int overdueCount = 0;

                  for (var deal in activeDeals) {
                    final rawDealRecords = recordsByDeal[deal.id] ?? [];
                    final rebalancedRecords = RentEngine.rebalanceLedgerRecords(rawDealRecords, deal);

                    totalAdvanceHeld += RentEngine.getRunningAdvanceBalance(deal, DateTime.now());

                    final targetRecord = rebalancedRecords.where((r) => r.periodMonth == selectedPeriod).firstOrNull;

                    double lifetimeCollected = 0.0;
                    for (var r in rebalancedRecords) {
                      for (var inst in r.installments) {
                        lifetimeCollected += inst.amount;
                      }
                    }

                    if (targetRecord != null) {
                      final unit = unitsMap[targetRecord.unitId] ?? unitsMap[deal.currentUnitId];
                      final unitLabel = unit?.label ?? deal.unitLabel ?? 'Unit';
                      final renterName = deal.businessName ?? 'Tenant';

                      double dueThisMonth = targetRecord.dueFromRenter;
                      double paidThisMonth = targetRecord.totalPaid;
                      double pendingThisMonth = targetRecord.amountPending;
                      double arrears = targetRecord.carriedOverDue;

                      // Full monthly demand accounts for agreed rent plus carried arrears
                      double dealDemand = targetRecord.effectiveRent + arrears;
                      double dealPending = pendingThisMonth + arrears;

                      totalExpectedMonthly += dealDemand;
                      totalCollectedMonthly += paidThisMonth;
                      totalPendingMonthly += dealPending;

                      if (targetRecord.status == 'overdue' || dealPending > 0) {
                        overdueCount++;
                      }

                      unitReportItems.add(_UnitReportItem(
                        deal: deal,
                        unitLabel: unitLabel,
                        renterName: renterName,
                        record: targetRecord,
                        monthlyRent: targetRecord.effectiveRent,
                        dueThisMonth: dueThisMonth,
                        paidThisMonth: paidThisMonth,
                        pendingThisMonth: pendingThisMonth,
                        carriedOverDue: arrears,
                        lifetimeCollected: lifetimeCollected,
                        status: targetRecord.status,
                      ));
                    } else {
                      final dealStartPeriod = RentEngine.formatPeriodMonth(deal.dealStartDate);
                      if (selectedPeriod.compareTo(dealStartPeriod) >= 0) {
                        final mIndex = RentEngine.getMonthIndex(deal.dealStartDate, _selectedMonthDate);
                        final effRent = RentEngine.getEffectiveRent(deal, mIndex);
                        totalExpectedMonthly += effRent;
                        totalPendingMonthly += effRent;
                        overdueCount++;
                      }
                    }
                  }

                  final collectionPercentage = totalExpectedMonthly > 0
                      ? ((totalCollectedMonthly / totalExpectedMonthly) * 100).clamp(0.0, 100.0)
                      : (totalCollectedMonthly > 0 ? 100.0 : 0.0);

                  // Filter units by selected status chip
                  final filteredItems = unitReportItems.where((item) {
                    if (_statusFilter == 'paid') return item.status == 'confirmed-paid';
                    if (_statusFilter == 'overdue') return item.status == 'overdue' || item.pendingThisMonth > 0;
                    if (_statusFilter == 'advance') return item.status == 'adjusted-against-advance';
                    return true;
                  }).toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month Navigator Bar
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios, size: 18),
                                onPressed: _previousMonth,
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month, color: AppTheme.primaryNavy, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    selectedPeriod,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios, size: 18),
                                onPressed: _nextMonth,
                              ),
                            ],
                          ),
                        ),

                        // Monthly Collection Efficiency Gauge Card
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryNavy, Color(0xFF0F2942)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(30),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Monthly Collection Efficiency',
                                    style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      selectedPeriod,
                                      style: const TextStyle(color: AppTheme.goldAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '${collectionPercentage.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: AppTheme.goldAccent,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: collectionPercentage / 100.0,
                                  backgroundColor: Colors.white24,
                                  color: AppTheme.goldAccent,
                                  minHeight: 10,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          const Text(
                                            'Expected',
                                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 2),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '₹${totalExpectedMonthly.toStringAsFixed(0)}',
                                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF86EFAC).withAlpha(20),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          const Text(
                                            'Collected',
                                            style: TextStyle(color: Color(0xFF86EFAC), fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 2),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '₹${totalCollectedMonthly.toStringAsFixed(0)}',
                                              style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 14, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: (totalPendingMonthly > 0 ? Colors.amberAccent : Colors.white24).withAlpha(20),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Pending',
                                            style: TextStyle(
                                              color: totalPendingMonthly > 0 ? Colors.amberAccent : Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '₹${totalPendingMonthly.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                color: totalPendingMonthly > 0 ? Colors.amberAccent : Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Property Financial Summary Grid
                        Row(
                          children: [
                            Expanded(
                              child: _summaryCard('Occupancy', '${activeDeals.length} / ${units.length}', Icons.home_work, AppTheme.primaryTeal),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _summaryCard('Advance Held', '₹${totalAdvanceHeld.toStringAsFixed(0)}', Icons.account_balance_wallet, AppTheme.primaryNavy),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _summaryCard('Overdue Units', '$overdueCount', Icons.warning_amber_rounded, overdueCount > 0 ? AppTheme.statusRed : AppTheme.statusGreen),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Text('Data Export & Financial Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                        const SizedBox(height: 12),

                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            minimumSize: const Size(double.infinity, 46),
                          ),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Export Monthly Property PDF Statement', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            final rows = unitReportItems.map((u) => {
                              'unit': u.unitLabel,
                              'renter': u.renterName,
                              'rent': u.monthlyRent.toStringAsFixed(0),
                              'paid': u.paidThisMonth.toStringAsFixed(0),
                              'pending': u.pendingThisMonth.toStringAsFixed(0),
                              'status': u.status.toUpperCase(),
                            }).toList();

                            ExportService.generatePropertySummaryPDF(
                              propertyName: BrandConfig.brandName,
                              periodMonth: selectedPeriod,
                              expected: totalExpectedMonthly,
                              collected: totalCollectedMonthly,
                              pending: totalPendingMonthly,
                              unitRows: rows,
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryNavy,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  final bytes = ExportService.exportLedgerToExcel(allRecords, {});
                                  if (bytes != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Excel Report Generated Successfully!')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.table_view),
                                label: Text(AppLocalization.tr('export_excel'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  final csv = ExportService.exportLedgerToCSV(allRecords);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('CSV Data Generated (${csv.length} bytes)')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.file_present),
                                label: Text(AppLocalization.tr('export_csv'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                          onPressed: () {
                            final jsonList = allRecords.map((r) => r.toMap()).toList();
                            final jsonStr = jsonEncode(jsonList);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Full Database Backup Exported (${jsonStr.length} bytes)')),
                            );
                          },
                          icon: const Icon(Icons.backup_outlined),
                          label: Text(AppLocalization.tr('backup_db'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),

                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$selectedPeriod Unit Ledger', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryNavy.withAlpha(15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${filteredItems.length} Unit${filteredItems.length == 1 ? "" : "s"}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Status Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _filterChip('All (${unitReportItems.length})', 'all'),
                              const SizedBox(width: 8),
                              _filterChip('Paid (${unitReportItems.where((i) => i.status == "confirmed-paid").length})', 'paid'),
                              const SizedBox(width: 8),
                              _filterChip('Overdue (${unitReportItems.where((i) => i.status == "overdue" || i.pendingThisMonth > 0).length})', 'overdue'),
                              const SizedBox(width: 8),
                              _filterChip('Advance (${unitReportItems.where((i) => i.status == "adjusted-against-advance").length})', 'advance'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        if (filteredItems.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(28),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text('No units match "$_statusFilter" status for $selectedPeriod.', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              final totalDue = item.dueThisMonth + item.carriedOverDue;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header Row: Unit Label & Renter Name + Status Chip
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryNavy.withAlpha(15),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.home_work_outlined, color: AppTheme.primaryNavy, size: 20),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Unit ${item.unitLabel}',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      Text(
                                                        item.renterName,
                                                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildStatusBadge(item.status),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      const Divider(height: 1),
                                      const SizedBox(height: 14),

                                      // Financial Grid (Due / Paid / Pending)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _financialStatBox('Monthly Rent', '₹${item.monthlyRent.toStringAsFixed(0)}', AppTheme.primaryNavy),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _financialStatBox('Paid', '₹${item.paidThisMonth.toStringAsFixed(0)}', const Color(0xFF15803D)),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _financialStatBox(
                                              'Pending',
                                              '₹${item.pendingThisMonth.toStringAsFixed(0)}',
                                              item.pendingThisMonth > 0 ? const Color(0xFFB45309) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item.carriedOverDue > 0) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Past Arrears (Prior Months): ₹${item.carriedOverDue.toStringAsFixed(0)} | Total Due: ₹${totalDue.toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Lifetime Revenue Collected: ₹${item.lifetimeCollected.toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _summaryCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppTheme.primaryTeal.withAlpha(50),
      onSelected: (_) {
        setState(() => _statusFilter = value);
      },
    );
  }

  Widget _kpiSubText(String text, Color color) {
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
    );
  }

  Widget _financialStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(40), width: 1),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    String label;

    switch (status) {
      case 'confirmed-paid':
        bg = const Color(0xFF15803D); // Green
        label = 'PAID';
        break;
      case 'pending-confirmation':
        bg = const Color(0xFFD97706); // Gold
        label = 'CONFIRM';
        break;
      case 'confirmed-partial':
        bg = const Color(0xFFEA580C); // Orange
        label = 'PARTIAL';
        break;
      case 'overdue':
        bg = const Color(0xFFDC2626); // Red
        label = 'OVERDUE';
        break;
      case 'adjusted-against-advance':
        bg = const Color(0xFF0284C7); // Royal Blue
        label = 'ADVANCE';
        break;
      default:
        bg = Colors.grey;
        label = status.toUpperCase();
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
