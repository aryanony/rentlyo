import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/deal_model.dart';
import '../services/firestore_service.dart';

class UtilityBillsScreen extends StatelessWidget {
  final DealModel deal;

  const UtilityBillsScreen({super.key, required this.deal});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sub-Meter Utility Bills'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestore.streamUtilityBills(deal),
        builder: (context, snapshot) {
          final bills = snapshot.data ?? [];

          if (bills.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No electricity or water sub-meter bills logged for your unit yet.\nBills logged by your property owner will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bills.length,
            itemBuilder: (ctx, i) {
              final b = bills[i];
              final net = (b['netAmount'] as num?)?.toDouble() ?? 0.0;
              final prev = (b['previousReading'] as num?)?.toDouble() ?? 0.0;
              final curr = (b['currentReading'] as num?)?.toDouble() ?? 0.0;
              final units = (curr - prev).clamp(0.0, double.infinity);
              final rate = (b['unitRate'] as num?)?.toDouble() ?? 0.0;

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
                          Row(
                            children: [
                              const Icon(Icons.bolt, color: AppTheme.goldAccent, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                '${(b['utilityType'] as String? ?? 'utility').toUpperCase()} BILL',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                              ),
                            ],
                          ),
                          Text(
                            '₹${net.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primaryNavy),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Billing Month Period: ${b['periodMonth']}'),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Previous Reading: $prev', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          Text('Current Reading: $curr', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Units Consumed: ${units.toStringAsFixed(1)} units', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Rate: ₹$rate / unit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      if (b['notes'] != null && (b['notes'] as String).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Note: ${b['notes']}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Color(0xFF64748B))),
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
