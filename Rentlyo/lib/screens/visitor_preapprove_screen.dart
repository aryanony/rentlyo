import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import '../models/deal_model.dart';
import '../services/firestore_service.dart';

class VisitorPreapproveScreen extends StatefulWidget {
  final DealModel deal;

  const VisitorPreapproveScreen({super.key, required this.deal});

  @override
  State<VisitorPreapproveScreen> createState() => _VisitorPreapproveScreenState();
}

class _VisitorPreapproveScreenState extends State<VisitorPreapproveScreen> {
  final FirestoreService _firestore = FirestoreService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleController = TextEditingController();

  final DateTime _visitDate = DateTime.now();
  bool _isSubmitting = false;

  void _submitVisitor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter visitor name and phone number')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userDoc = await _firestore.streamUser(user.uid).first;
      final renterName = userDoc?.name ?? 'Resident';

      await _firestore.submitVisitorLog({
        'propertyId': widget.deal.propertyId,
        'unitId': widget.deal.unitId,
        'renterId': widget.deal.renterId,
        'renterUid': user.uid,
        'renterName': renterName,
        'visitorName': name,
        'visitorPhone': phone,
        'visitDate': Timestamp.fromDate(_visitDate),
        'vehicleNumber': _vehicleController.text.trim().isNotEmpty ? _vehicleController.text.trim() : null,
        'status': 'pre-approved',
        'createdAt': DateTime.now(),
      });

      if (mounted) {
        _nameController.clear();
        _phoneController.clear();
        _vehicleController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visitor pre-approved for gate entry!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
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
        title: const Text('Pre-Approve Visitor / Guest'),
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
                  Icon(Icons.sensor_door, color: AppTheme.goldAccent, size: 36),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pre-Approve Guest Entry',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Pre-approve expected visitors and family members for gate pass verification.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Visitor / Guest Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'e.g. Ramesh Kumar'),
            ),
            const SizedBox(height: 16),

            const Text('Visitor Phone Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'e.g. 9876543210'),
            ),
            const SizedBox(height: 16),

            const Text('Vehicle Number (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _vehicleController,
              decoration: const InputDecoration(hintText: 'e.g. BR-09-AB-1234'),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitVisitor,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(_isSubmitting ? 'Pre-approving...' : 'Pre-Approve Visitor Entry'),
              ),
            ),
            const SizedBox(height: 32),

            const Text('Pre-Approved Visitors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryNavy)),
            const SizedBox(height: 12),

            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestore.streamVisitorLogs(widget.deal.renterId),
              builder: (context, snapshot) {
                final visitors = snapshot.data ?? [];
                if (visitors.isEmpty) {
                  return const Text('No pre-approved visitors logged.', style: TextStyle(color: Colors.grey));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visitors.length,
                  itemBuilder: (ctx, i) {
                    final v = visitors[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.primaryNavy,
                          child: Icon(Icons.person, color: Colors.white, size: 20),
                        ),
                        title: Text(v['visitorName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Phone: ${v['visitorPhone']} ${v['vehicleNumber'] != null ? "• Vehicle: ${v['vehicleNumber']}" : ""}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.statusGreen, borderRadius: BorderRadius.circular(10)),
                          child: const Text('PRE-APPROVED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
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
