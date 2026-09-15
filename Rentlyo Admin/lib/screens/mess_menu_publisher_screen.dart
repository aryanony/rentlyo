import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/firestore_service.dart';

class MessMenuPublisherScreen extends StatefulWidget {
  final String propertyId;

  const MessMenuPublisherScreen({super.key, required this.propertyId});

  @override
  State<MessMenuPublisherScreen> createState() => _MessMenuPublisherScreenState();
}

class _MessMenuPublisherScreenState extends State<MessMenuPublisherScreen> {
  final FirestoreService _firestore = FirestoreService();

  String _selectedDay = 'Monday';
  final _breakfastCtrl = TextEditingController();
  final _lunchCtrl = TextEditingController();
  final _snacksCtrl = TextEditingController();
  final _dinnerCtrl = TextEditingController();
  bool _isSaving = false;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  void _saveMenu() async {
    setState(() => _isSaving = true);
    try {
      await _firestore.saveMessMenu(
        propertyId: widget.propertyId,
        dayOfWeek: _selectedDay,
        breakfast: _breakfastCtrl.text.trim(),
        lunch: _lunchCtrl.text.trim(),
        snacks: _snacksCtrl.text.trim(),
        dinner: _dinnerCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mess Menu for $_selectedDay published successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving menu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PG / Hostel Mess Menu Publisher'),
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
                  Icon(Icons.restaurant_menu, color: AppTheme.goldAccent, size: 36),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Mess & Food Menu',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Publish daily breakfast, lunch, snacks, and dinner for PG & Hostel residents.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Select Day of Week', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedDay,
              decoration: const InputDecoration(),
              items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (d) => setState(() => _selectedDay = d!),
            ),
            const SizedBox(height: 16),

            const Text('Breakfast (Morning)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _breakfastCtrl,
              decoration: const InputDecoration(hintText: 'e.g. Aloo Paratha, Curd, Tea / Coffee'),
            ),
            const SizedBox(height: 14),

            const Text('Lunch (Afternoon)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _lunchCtrl,
              decoration: const InputDecoration(hintText: 'e.g. Rice, Dal Tadka, Paneer Butter Masala, Roti, Salad'),
            ),
            const SizedBox(height: 14),

            const Text('Snacks (Evening)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _snacksCtrl,
              decoration: const InputDecoration(hintText: 'e.g. Samosa / Tea / Biscuits'),
            ),
            const SizedBox(height: 14),

            const Text('Dinner (Night)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _dinnerCtrl,
              decoration: const InputDecoration(hintText: 'e.g. Mix Veg, Dal Fry, Phulka Roti, Gulab Jamun'),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveMenu,
                icon: const Icon(Icons.publish),
                label: Text(_isSaving ? 'Publishing...' : 'Publish Menu for $_selectedDay'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
