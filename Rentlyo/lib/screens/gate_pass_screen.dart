import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import '../models/deal_model.dart';
import '../services/firestore_service.dart';

class GatePassScreen extends StatefulWidget {
  final DealModel deal;

  const GatePassScreen({super.key, required this.deal});

  @override
  State<GatePassScreen> createState() => _GatePassScreenState();
}

class _GatePassScreenState extends State<GatePassScreen> {
  final FirestoreService _firestore = FirestoreService();
  final _reasonController = TextEditingController();

  DateTime _departureDate = DateTime.now();
  DateTime _returnDate = DateTime.now().add(const Duration(days: 1));
  bool _isSubmitting = false;

  void _submitGatePass() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter reason for leave / night-out')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userDoc = await _firestore.streamUser(user.uid).first;
      final renterName = userDoc?.name ?? 'Resident';

      await _firestore.submitGatePass({
        'propertyId': widget.deal.propertyId,
        'unitId': widget.deal.unitId,
        'renterId': widget.deal.renterId,
        'renterUid': user.uid,
        'renterName': renterName,
        'reason': reason,
        'departureDate': Timestamp.fromDate(_departureDate),
        'returnDate': Timestamp.fromDate(_returnDate),
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      if (mounted) {
        _reasonController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gate pass request submitted to Warden / Admin!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate Pass & Night-Out'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.badge_outlined, color: AppTheme.goldAccent, size: 36),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PG & Hostel Gate Pass Request',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Submit leave or night-out permission requests directly to your warden.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Reason for Leave / Night-Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(hintText: 'e.g. Going home for weekend / Family function'),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Departure Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _departureDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) setState(() => _departureDate = picked);
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('${_departureDate.day}/${_departureDate.month}/${_departureDate.year}'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Expected Return', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _returnDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) setState(() => _returnDate = picked);
                        },
                        icon: const Icon(Icons.event_repeat, size: 16),
                        label: Text('${_returnDate.day}/${_returnDate.month}/${_returnDate.year}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitGatePass,
                icon: const Icon(Icons.send),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit Gate Pass Request'),
              ),
            ),
            const SizedBox(height: 32),

            const Text('Your Gate Pass Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryNavy)),
            const SizedBox(height: 12),

            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestore.streamGatePasses(widget.deal.renterId),
              builder: (context, snapshot) {
                final passes = snapshot.data ?? [];
                if (passes.isEmpty) {
                  return const Text('No gate passes requested yet.', style: TextStyle(color: Colors.grey));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: passes.length,
                  itemBuilder: (ctx, i) {
                    final p = passes[i];
                    final status = p['status'] as String? ?? 'pending';

                    Color statusBg;
                    if (status == 'approved') {
                      statusBg = AppTheme.statusGreen;
                    } else if (status == 'rejected') {
                      statusBg = AppTheme.statusRed;
                    } else {
                      statusBg = AppTheme.statusYellow;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(p['reason'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'From: ${p['departureDate'] != null ? (p['departureDate'] as dynamic).toDate().toString().split(' ')[0] : ''} • To: ${p['returnDate'] != null ? (p['returnDate'] as dynamic).toDate().toString().split(' ')[0] : ''}',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                          child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
