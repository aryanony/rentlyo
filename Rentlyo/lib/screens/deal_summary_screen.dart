import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/brand_config.dart';
import '../core/localization.dart';
import '../core/rent_engine.dart';
import '../core/facility_icon_helper.dart';
import '../models/deal_model.dart';
import '../services/firestore_service.dart';
import 'mess_menu_screen.dart';

class DealSummaryScreen extends StatelessWidget {
  final DealModel deal;

  const DealSummaryScreen({super.key, required this.deal});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DealModel?>(
      stream: FirestoreService().streamDealById(deal.id),
      builder: (context, snap) {
        final activeDeal = snap.data ?? deal;
        final baseRent = activeDeal.baseMonthlyRent.toStringAsFixed(0);
        final currentMonthIndex = RentEngine.getMonthIndex(activeDeal.dealStartDate, DateTime.now());
        final currentEffectiveRent = RentEngine.getEffectiveRent(activeDeal, currentMonthIndex);
        final remainingAdvance = RentEngine.getRunningAdvanceBalance(activeDeal, DateTime.now());
        final currentPeriodMonth = RentEngine.formatPeriodMonth(DateTime.now());

        // Deducted advance calculation
        final totalAdvance = activeDeal.totalAdvanceAmount;
        final advanceDeducted = (totalAdvance - remainingAdvance).clamp(0.0, totalAdvance);

    // Build plain-language structured summary items
    final summaryItems = <Map<String, dynamic>>[
      {
        'icon': Icons.home_work_rounded,
        'color': AppTheme.primaryNavy,
        'title': 'Unit Lease Details',
        'subtitle': 'Unit ${activeDeal.displayMultiUnitLabel} • ${activeDeal.renterType.toUpperCase()} Lease',
      },
      {
        'icon': activeDeal.advanceConsumptionMode && remainingAdvance > 0 ? Icons.autorenew_rounded : Icons.payments_rounded,
        'color': activeDeal.advanceConsumptionMode && remainingAdvance > 0 ? AppTheme.statusGreen : AppTheme.primaryNavy,
        'title': 'Monthly Rent: ₹${currentEffectiveRent.toStringAsFixed(0)} / mo',
        'subtitle': activeDeal.advanceConsumptionMode && remainingAdvance > 0
            ? 'Currently auto-deducted from advance for month $currentPeriodMonth. No manual monthly payment required.'
            : 'Due on the ${activeDeal.rentDueDayOfMonth}${_ordinalSuffix(activeDeal.rentDueDayOfMonth)} of every month via direct cash or UPI.',
      },
      if (totalAdvance > 0)
        {
          'icon': Icons.account_balance_wallet_rounded,
          'color': AppTheme.primaryTeal,
          'title': activeDeal.advanceConsumptionMode
              ? 'Advance Balance: ₹${remainingAdvance.toStringAsFixed(0)} Remaining'
              : 'Security Deposit: ₹${totalAdvance.toStringAsFixed(0)} Held',
          'subtitle': activeDeal.advanceConsumptionMode
              ? 'Total deposited: ₹${totalAdvance.toStringAsFixed(0)}. Total auto-deducted: ₹${advanceDeducted.toStringAsFixed(0)}.${activeDeal.advanceDeductStartMonth != null && activeDeal.advanceDeductEndMonth != null ? ' Deduction plan: ${activeDeal.advanceDeductStartMonth} to ${activeDeal.advanceDeductEndMonth}.' : ''}'
              : 'Refundable security deposit held for tenancy duration.',
        },
      if (activeDeal.rentSchedule.length > 1)
        {
          'icon': Icons.trending_up_rounded,
          'color': const Color(0xFFD97706),
          'title': 'Rent Schedule: ${activeDeal.rentSchedule.length} Step-Up Tiers',
          'subtitle': 'Starting rent was ₹$baseRent/mo. Rent steps increase over time as specified in your lease agreement.',
        },
      {
        'icon': Icons.shield_rounded,
        'color': const Color(0xFF2563EB),
        'title': 'Lease Terms & Refund Policy',
        'subtitle': activeDeal.carryForwardPendingBalance
            ? 'Pending balances carry forward to next month. Any remaining advance balance is fully refundable at lease completion.'
            : 'Strict monthly settlement. Remaining advance balance is refundable upon tenancy end.',
      },
    ];

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalization.tr('deal_summary'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header Badge if Deal is Ended (Section 3)
            if (activeDeal.status == 'ended') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.statusRed.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.statusRed),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_outlined, color: AppTheme.statusRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This lease agreement ended on ${_formatDate(activeDeal.dealEndDate ?? DateTime.now())}. Read-Only View.',
                        style: const TextStyle(color: AppTheme.statusRed, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Current rent header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your Current Monthly Rent', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          '₹${currentEffectiveRent.toStringAsFixed(0)} / month',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Unit ${activeDeal.displayMultiUnitLabel} • Month $currentMonthIndex of lease • ${activeDeal.renterType.toUpperCase()}',
                          style: const TextStyle(color: Colors.lightGreenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(6),
                    child: BrandConfig.buildLogoWidget(
                      defaultAsset: 'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Plain-Language Summary Card
            Card(
              color: const Color(0xFFF8FAFC),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.menu_book_rounded, color: AppTheme.primaryNavy, size: 22),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your Deal in Plain Language & Summary',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Column(
                      children: summaryItems.map((item) {
                        final IconData icon = item['icon'];
                        final Color color = item['color'];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withAlpha(20),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, size: 20, color: color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['subtitle'],
                                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Rented Units / Shop Rooms Card
            Card(
              color: const Color(0xFFF1F5F9),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.store_mall_directory, color: AppTheme.primaryNavy, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rented Units / Shop Rooms', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            'Unit ${activeDeal.displayMultiUnitLabel}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: Advance & Security Deposit Ledger Details (Infographic View)
            if (activeDeal.totalAdvanceAmount > 0) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 24, color: AppTheme.primaryNavy),
                          SizedBox(width: 10),
                          Text('Advance Security Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Deposited:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          Text('₹${activeDeal.totalAdvanceAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Remaining Balance:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          Text('₹${remainingAdvance.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryTeal)),
                        ],
                      ),
                      if (activeDeal.advanceConsumptionMode) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: activeDeal.totalAdvanceAmount > 0 ? (remainingAdvance / activeDeal.totalAdvanceAmount).clamp(0.0, 1.0) : 0.0,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          activeDeal.advanceDeductStartMonth != null && activeDeal.advanceDeductEndMonth != null
                              ? 'Status: Rent auto-deducted from advance for ${activeDeal.advanceDeductStartMonth} to ${activeDeal.advanceDeductEndMonth}'
                              : 'Status: Rent is being auto-deducted from advance running balance',
                          style: TextStyle(fontSize: 12, color: AppTheme.primaryTeal.withAlpha(220), fontWeight: FontWeight.bold),
                        ),
                      ],
                      if (activeDeal.advanceTransactions.isNotEmpty) ...[
                        const Divider(height: 20),
                        const Text('Advance Deposits & Remarks History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy)),
                        const SizedBox(height: 8),
                        ...activeDeal.advanceTransactions.map((tx) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryTeal.withAlpha(20),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.history, size: 16, color: AppTheme.primaryTeal),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                        ),
                                        Text(
                                          (tx.note != null && tx.note!.trim().isNotEmpty) ? tx.note! : 'Advance Deposit Top-Up',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${tx.amount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Section 1: Unit History Timeline
            if (activeDeal.unitHistory.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.timeline, color: AppTheme.primaryNavy, size: 24),
                          SizedBox(width: 10),
                          Text('Unit Transfer Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: activeDeal.unitHistory.map((item) {
                          final fromStr = _formatDate(item.fromDate);
                          final toStr = item.toDate != null ? _formatDate(item.toDate!) : 'present';
                          final isCurrent = item.toDate == null;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  isCurrent ? Icons.check_circle : Icons.history,
                                  size: 18,
                                  color: isCurrent ? AppTheme.statusGreen : Colors.grey,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Unit ${item.displayLabel}: $fromStr – $toStr',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    color: isCurrent ? AppTheme.primaryNavy : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Section 4: Dynamic Modular Amenities (Renders ONLY if array not empty)
            if (activeDeal.amenities.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.star_rounded, color: AppTheme.goldAccent, size: 24),
                          SizedBox(width: 10),
                          Text('Included Facilities & Extra Services', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Column(
                        children: activeDeal.amenities.map((amen) {
                          final icon = FacilityIconHelper.getIcon(amen.name);
                          final color = FacilityIconHelper.getColor(amen.name);
                          final isMess = amen.name.toLowerCase().contains('mess') || amen.name.toLowerCase().contains('food');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withAlpha(12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withAlpha(40), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(30),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, color: color, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        amen.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                                      ),
                                      if (amen.notes != null && amen.notes!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          amen.notes!,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isMess) ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: color,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => MessMenuScreen(deal: deal)),
                                      );
                                    },
                                    icon: const Icon(Icons.restaurant_menu, size: 14),
                                    label: const Text('Menu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Agreement Start Date
            _detailSection(
              Icons.event,
              'Agreement Start Date',
              _formatDate(activeDeal.dealStartDate),
            ),

            if (activeDeal.businessName != null && activeDeal.businessName!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _detailSection(Icons.store, 'Business / Shop Name', activeDeal.businessName!),
            ],
            if (activeDeal.occupantCount != null) ...[
              const SizedBox(height: 12),
              _detailSection(Icons.people_outline, 'Registered Occupants', '${activeDeal.occupantCount} occupants'),
            ],

            // Rent Due Day
            const SizedBox(height: 12),
            _detailSection(
              Icons.calendar_today,
              'Rent Due Day',
              'Your rent is due on the ${activeDeal.rentDueDayOfMonth}${_ordinalSuffix(activeDeal.rentDueDayOfMonth)} of every month.',
            ),

            // Google Drive Agreement Link
            if (activeDeal.agreementDriveLink != null && activeDeal.agreementDriveLink!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: AppTheme.goldAccent, size: 30),
                  title: const Text('Google Drive Agreement', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                  subtitle: const Text('Tap to view your agreement document'),
                  trailing: const Icon(Icons.open_in_new, color: AppTheme.primaryNavy),
                  onTap: () async {
                    final url = Uri.parse(activeDeal.agreementDriveLink!);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
            ],

            // Step-up schedule table (if multiple tiers)
            if (activeDeal.rentSchedule.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Rent Schedule Tiers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Table(
                    border: TableBorder.all(color: const Color(0xFFE2E8F0)),
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1.5),
                    },
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(10),
                            child: Text('Effective From', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(10),
                            child: Text('Monthly Rent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ],
                      ),
                      ...activeDeal.rentSchedule.map((item) => TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text('From ${item.effectiveFromDate.month}/${item.effectiveFromDate.year}', style: const TextStyle(fontSize: 14)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              '₹${item.monthlyRent.toStringAsFixed(0)}/month',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                            ),
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  },
);
  }

  Widget _detailSection(IconData icon, String title, String body) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: AppTheme.primaryNavy),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy)),
                  const SizedBox(height: 6),
                  Text(body, style: const TextStyle(fontSize: 15, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  String _ordinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }
}
