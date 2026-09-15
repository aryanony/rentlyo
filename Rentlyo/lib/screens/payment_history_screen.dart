import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/localization.dart';
import '../models/deal_model.dart';
import '../models/payment_record_model.dart';
import '../services/firestore_service.dart';
import '../core/rent_engine.dart';
import 'report_payment_screen.dart';

class PaymentHistoryScreen extends StatelessWidget {
  final DealModel deal;

  const PaymentHistoryScreen({super.key, required this.deal});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalization.tr('payment_history'))),
      body: StreamBuilder<List<PaymentRecordModel>>(
        stream: firestore.streamRenterLedger(deal.id, deal.renterId),
        builder: (context, snapshot) {
          final rawRecords = snapshot.data ?? [];
          final records = RentEngine.rebalanceLedgerRecords(rawRecords, deal);
          records.sort((a, b) => b.periodMonth.compareTo(a.periodMonth));

          if (records.isEmpty) {
            return const Center(child: Text('No payment records logged yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final rec = records[index];
              final isAdvance = rec.status == 'adjusted-against-advance';
              final isFullyPaid = rec.status == 'confirmed-paid' || (rec.amountPending == 0 && !isAdvance);
              final isPartial = rec.status == 'confirmed-partial' || (rec.totalPaid > 0 && rec.amountPending > 0);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isPartial
                      ? const BorderSide(color: Color(0xFFFBBF24), width: 1.5)
                      : (isFullyPaid ? const BorderSide(color: Color(0xFF86EFAC), width: 1) : BorderSide.none),
                ),
                elevation: isPartial ? 3 : 2,
                child: ExpansionTile(
                  title: Text(
                    '${rec.periodMonth} • Month ${rec.monthIndex}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: isAdvance
                        ? Text(
                            'Monthly Rent: ₹${rec.effectiveRent.toStringAsFixed(0)} | Covered from Advance (₹0 Due)',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                          )
                        : (isFullyPaid
                            ? Text(
                                'Monthly Rent: ₹${rec.effectiveRent.toStringAsFixed(0)} | Fully Paid: ₹${rec.totalPaid.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 13, color: AppTheme.statusGreen, fontWeight: FontWeight.w600),
                              )
                            : Text(
                                'Monthly Rent: ₹${rec.effectiveRent.toStringAsFixed(0)} | Paid: ₹${rec.totalPaid.toStringAsFixed(0)} | Rest Due: ₹${rec.amountPending.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isPartial ? const Color(0xFFD97706) : AppTheme.statusRed,
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                  ),
                  trailing: _buildStatusChip(rec),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _rowDetail('Monthly Rent Due:', '₹${rec.effectiveRent.toStringAsFixed(0)}'),
                          _rowDetail('Total Paid for this Month:', '₹${rec.totalPaid.toStringAsFixed(0)}'),
                          _rowDetail('Amount Pending for this Month:', '₹${rec.amountPending.toStringAsFixed(0)}'),
                          if (rec.carriedOverDue > 0)
                            _rowDetail('Past Arrears (Prior Months):', '₹${rec.carriedOverDue.toStringAsFixed(0)}'),
                          if (rec.carriedOverDue > 0)
                            _rowDetail('Total Outstanding (Rent + Arrears):', '₹${(rec.amountPending + rec.carriedOverDue).toStringAsFixed(0)}'),
                          const Divider(height: 24),
                          if (isPartial) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Partially Paid: ₹${rec.totalPaid.toStringAsFixed(0)} paid across ${rec.installments.length} installment(s). Remaining ₹${rec.amountPending.toStringAsFixed(0)} pending.',
                                      style: TextStyle(color: Colors.amber.shade900, fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Text(
                            'Payment Installments Breakdown (${rec.installments.length} Part${rec.installments.length == 1 ? '' : 's'}):',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                          ),
                          const SizedBox(height: 8),
                          if (rec.installments.isEmpty)
                            const Text('No installments recorded yet.', style: TextStyle(color: Colors.grey, fontSize: 13))
                          else
                            ...rec.installments.asMap().entries.map((entry) {
                              final instIndex = entry.key + 1;
                              final inst = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryNavy.withAlpha(20),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Part $instIndex',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '₹${inst.amount.toStringAsFixed(0)}',
                                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.statusGreen),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'via ${inst.method.toUpperCase()}',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Date: ${inst.date.day.toString().padLeft(2, '0')}/${inst.date.month.toString().padLeft(2, '0')}/${inst.date.year} • (${inst.addedBy == 'owner' ? 'Owner / Admin Added' : 'Tenant Reported'})',
                                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                          ),
                                          if (inst.note != null && inst.note!.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text('Note: "${inst.note}"', style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF334155))),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.check_circle, color: AppTheme.statusGreen, size: 20),
                                  ],
                                ),
                              );
                            }),
                          if (rec.amountPending > 0 && !isAdvance) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isPartial ? const Color(0xFFD97706) : AppTheme.primaryNavy,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ReportPaymentScreen(record: rec, deal: deal),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.payment),
                                label: Text(
                                  isPartial
                                      ? 'Pay Remaining Due (₹${rec.amountPending.toStringAsFixed(0)})'
                                      : 'Pay / Report Rent (₹${rec.dueFromRenter.toStringAsFixed(0)})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _rowDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(PaymentRecordModel rec) {
    final isAdvance = rec.status == 'adjusted-against-advance';
    final isFullyPaid = rec.status == 'confirmed-paid' || (rec.amountPending == 0 && !isAdvance);
    final isPartial = rec.status == 'confirmed-partial' || (rec.totalPaid > 0 && rec.amountPending > 0);

    Color bg;
    String label;

    if (isAdvance) {
      bg = const Color(0xFF0284C7);
      label = 'Advance';
    } else if (isFullyPaid) {
      bg = AppTheme.statusGreen;
      label = 'Paid';
    } else if (isPartial) {
      bg = const Color(0xFFD97706);
      label = 'Partial (₹${rec.totalPaid.toStringAsFixed(0)}/₹${rec.effectiveRent.toStringAsFixed(0)})';
    } else if (rec.status == 'pending-confirmation') {
      bg = const Color(0xFFEAB308);
      label = 'Pending Approval';
    } else if (rec.status == 'overdue') {
      bg = AppTheme.statusRed;
      label = 'Overdue';
    } else {
      bg = AppTheme.statusRed;
      label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
    );
  }
}
