import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import '../core/localization.dart';
import '../models/payment_record_model.dart';
import '../models/deal_model.dart';
import '../services/firestore_service.dart';

class ReportPaymentScreen extends StatefulWidget {
  final PaymentRecordModel record;
  final DealModel deal;

  const ReportPaymentScreen({super.key, required this.record, required this.deal});

  @override
  State<ReportPaymentScreen> createState() => _ReportPaymentScreenState();
}

class _ReportPaymentScreenState extends State<ReportPaymentScreen> {
  late TextEditingController _amountController;
  final _noteController = TextEditingController();
  final FirestoreService _firestore = FirestoreService();

  String _selectedMethod = 'upi'; // 'cash' | 'bank' | 'upi'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final remainingPending = widget.record.amountPending > 0
        ? widget.record.amountPending
        : widget.record.dueFromRenter;
    _amountController = TextEditingController(text: remainingPending.toStringAsFixed(0));
  }

  /// Dynamically resolve the ownerUid from the property document
  Future<String> _resolveOwnerUid() async {
    final propDoc = await FirebaseFirestore.instance
        .collection('properties')
        .doc(widget.deal.propertyId)
        .get();
    return propDoc.data()?['ownerUid'] ?? '';
  }

  Future<void> _submitPaymentReport() async {
    final enteredAmount = double.tryParse(_amountController.text.trim());
    if (enteredAmount == null || enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount')),
      );
      return;
    }

    // Confirm before submit (spec Section 10: confirm-before-submit on payment reporting)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment Report'),
        content: Text(
          'Are you sure you want to report a payment of ₹${enteredAmount.toStringAsFixed(0)} via ${_selectedMethod.toUpperCase()}?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalization.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalization.tr('yes')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final ownerUid = await _resolveOwnerUid();

      await _firestore.submitPayment(
        record: widget.record,
        deal: widget.deal,
        enteredAmount: enteredAmount,
        paymentMethod: _selectedMethod,
        note: _noteController.text.trim(),
        ownerUid: ownerUid,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.statusGreen, size: 28),
                const SizedBox(width: 8),
                Text(AppLocalization.tr('report_sent')),
              ],
            ),
            content: Text(
              AppLocalization.tr('report_sent_msg'),
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text(AppLocalization.tr('ok')),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalization.tr('report_payment'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy.withAlpha(15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Monthly Rent (${widget.record.periodMonth})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '₹${widget.record.dueFromRenter.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(AppLocalization.tr('amount_paid'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '• Partial payments supported. Any remaining balance will roll into next month.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),

            Text(AppLocalization.tr('payment_method'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
            const SizedBox(height: 12),
            Row(
              children: [
                _methodCard('upi', AppLocalization.tr('upi'), Icons.qr_code),
                const SizedBox(width: 8),
                _methodCard('bank', AppLocalization.tr('bank'), Icons.account_balance),
                const SizedBox(width: 8),
                _methodCard('cash', AppLocalization.tr('cash'), Icons.payments),
              ],
            ),
            const SizedBox(height: 24),

            Text(AppLocalization.tr('note_optional'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'e.g. Paid via PhonePe / GPay txn ID 12345...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitPaymentReport,
              icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send),
              label: Text(AppLocalization.tr('submit_report')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodCard(String val, String title, IconData icon) {
    final selected = _selectedMethod == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMethod = val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryBlue : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.primaryBlue : const Color(0xFFCBD5E1),
              width: 2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withAlpha(50),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? Colors.white : AppTheme.primaryNavy, size: 26),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          color: selected ? Colors.white : AppTheme.primaryNavy,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
