import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/deal_model.dart';
import '../services/firestore_service.dart';

class MessMenuScreen extends StatelessWidget {
  final DealModel deal;

  const MessMenuScreen({super.key, required this.deal});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('PG / Hostel Mess Food Menu'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestore.streamMessMenus(deal.propertyId),
        builder: (context, snapshot) {
          final menus = snapshot.data ?? [];

          if (menus.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No mess menu published yet.\nYour PG/Hostel warden will update the weekly menu soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: menus.length,
            itemBuilder: (ctx, i) {
              final m = menus[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const Icon(Icons.restaurant, color: AppTheme.goldAccent, size: 28),
                  title: Text(
                    m['dayOfWeek'] ?? 'Day',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.primaryNavy),
                  ),
                  subtitle: Text('Breakfast: ${m['breakfast']}'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _mealRow('Breakfast', m['breakfast'], Icons.free_breakfast),
                          const SizedBox(height: 8),
                          _mealRow('Lunch', m['lunch'], Icons.lunch_dining),
                          const SizedBox(height: 8),
                          _mealRow('Snacks', m['snacks'], Icons.bakery_dining),
                          const SizedBox(height: 8),
                          _mealRow('Dinner', m['dinner'], Icons.dinner_dining),
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

  Widget _mealRow(String mealName, String menuText, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryNavy),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mealName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(
                menuText.isNotEmpty ? menuText : 'Not Specified',
                style: const TextStyle(fontSize: 14, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
