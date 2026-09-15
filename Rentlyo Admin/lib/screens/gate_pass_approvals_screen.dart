import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/firestore_service.dart';

class GatePassApprovalsScreen extends StatefulWidget {
  final String propertyId;

  const GatePassApprovalsScreen({super.key, required this.propertyId});

  @override
  State<GatePassApprovalsScreen> createState() => _GatePassApprovalsScreenState();
}

class _GatePassApprovalsScreenState extends State<GatePassApprovalsScreen> {
  final FirestoreService _firestore = FirestoreService();

  void _updateStatus(String gatePassId, String status) async {
    final commentCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'approved' ? 'Approve Gate Pass' : 'Reject Gate Pass'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to mark this request as ${status.toUpperCase()}?'),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(labelText: 'Warden / Guard Comment (Optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(status == 'approved' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _firestore.updateGatePassStatus(gatePassId, status, commentCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gate pass ${status.toUpperCase()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate Pass & Night-Out Approvals'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestore.streamGatePasses(widget.propertyId),
        builder: (context, snapshot) {
          final passes = snapshot.data ?? [];

          if (passes.isEmpty) {
            return const Center(
              child: Text('No leave or night-out gate passes requested yet.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            p['renterName'] ?? 'Resident',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              status.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Reason: ${p['reason']}', style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 6),
                      Text(
                        'Departure: ${p['departureDate'] != null ? (p['departureDate'] as dynamic).toDate().toString().split('.')[0] : ''}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      Text(
                        'Return: ${p['returnDate'] != null ? (p['returnDate'] as dynamic).toDate().toString().split('.')[0] : ''}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),

                      if (status == 'pending') ...[
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _updateStatus(p['id'], 'rejected'),
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              label: const Text('Reject', style: TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () => _updateStatus(p['id'], 'approved'),
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Approve Pass'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
