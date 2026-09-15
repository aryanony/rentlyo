import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme.dart';
import '../core/localization.dart';
import '../models/payment_record_model.dart';
import '../models/deal_model.dart';
import '../services/firestore_service.dart';

class PendingConfirmationsScreen extends StatelessWidget {
  final String propertyId;

  const PendingConfirmationsScreen({super.key, required this.propertyId});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalization.tr('pending_confirmations')),
      ),
      body: StreamBuilder<List<PaymentRecordModel>>(
        stream: firestore.streamPendingConfirmations(propertyId),
        builder: (context, snapshot) {
          final pendingRecords = snapshot.data ?? [];

          if (pendingRecords.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mark_email_read_outlined, size: 64, color: AppTheme.statusGreen),
                  SizedBox(height: 14),
                  Text(
                    'No pending payment confirmations!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                  ),
                  SizedBox(height: 6),
                  Text('All reported tenant payments have been verified.', style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            );
          }

          return StreamBuilder<List<DealModel>>(
            stream: firestore.streamDeals(propertyId),
            builder: (context, dealSnap) {
              final deals = dealSnap.data ?? [];

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pendingRecords.length,
                itemBuilder: (context, index) {
                  final rec = pendingRecords[index];
                  final deal = deals.firstWhere(
                    (d) => d.id == rec.dealId,
                    orElse: () => DealModel(
                      id: rec.dealId,
                      propertyId: propertyId,
                      currentUnitId: rec.unitId,
                      renterId: rec.renterId,
                      renterType: (rec.unitId.toLowerCase().contains('room') || rec.unitId.toLowerCase().contains('flat') || rec.unitId.toLowerCase().contains('res')) ? 'residential' : 'commercial',
                      dealStartDate: DateTime.now(),
                      rentSchedule: [],
                      rentDueDayOfMonth: 1,
                      advanceTransactions: [],
                      advanceConsumptionMode: false,
                      unitHistory: [],
                      amenities: [],
                      carryForwardPendingBalance: true,
                      status: 'active',
                      notes: '',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${deal.businessName ?? 'Tenant'} • ${rec.periodMonth}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.primaryNavy),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.statusYellow,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Awaiting Approval',
                                  style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Monthly Rent: ₹${rec.effectiveRent.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569)),
                              ),
                              if (rec.carriedOverDue > 0)
                                Text(
                                  'Past Arrears: ₹${rec.carriedOverDue.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.orange),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Reported Payment: ₹${(rec.installments.isNotEmpty ? rec.installments.last.amount : rec.totalPaid).toStringAsFixed(0)} via ${rec.paymentMethod?.toUpperCase() ?? 'N/A'}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.primaryNavy),
                          ),
                          if (rec.installments.length > 1) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Installment Part ${rec.installments.length} (Total month paid after this: ₹${rec.totalPaid.toStringAsFixed(0)})',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Builder(builder: (context) {
                            final pendingAfter = (rec.effectiveRent - rec.totalPaid).clamp(0.0, double.infinity);
                            return Text(
                              pendingAfter == 0
                                  ? 'This payment completes 100% of the rent for ${rec.periodMonth} (Marked PAID in Green)!'
                                  : 'Partial Payment: ₹${pendingAfter.toStringAsFixed(0)} will remain pending in yellow after approval.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: pendingAfter == 0 ? AppTheme.statusGreen : const Color(0xFFD97706),
                              ),
                            );
                          }),
                          if (rec.renterNote != null && rec.renterNote!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('Tenant Note: "${rec.renterNote}"', style: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF475569), fontSize: 12.5)),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.statusGreen,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  ),
                                  onPressed: () async {
                                    await firestore.confirmPaymentRecord(
                                      record: rec,
                                      deal: deal,
                                      adminUid: adminUid,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Payment approved for ${rec.periodMonth}!'),
                                          backgroundColor: AppTheme.statusGreen,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      AppLocalization.tr('approve'),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  ),
                                  onPressed: () {
                                    _showAdjustDialog(context, rec, deal, adminUid, firestore);
                                  },
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      AppLocalization.tr('adjust_amount'),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  void _showAdjustDialog(BuildContext context, PaymentRecordModel rec, DealModel deal, String adminUid, FirestoreService firestore) {
    final controller = TextEditingController(text: rec.totalPaid.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adjust Confirmed Amount'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(labelText: 'Actual Confirmed Amount (INR)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalization.tr('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final newAmt = double.tryParse(controller.text) ?? rec.totalPaid;
              Navigator.pop(ctx);
              await firestore.confirmPaymentRecord(
                record: rec,
                deal: deal,
                adminUid: adminUid,
                adjustedAmount: newAmt,
              );
            },
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    );
  }
}
