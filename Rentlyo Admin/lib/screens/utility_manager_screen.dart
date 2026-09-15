import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import '../models/unit_model.dart';
import '../services/firestore_service.dart';

class UtilityManagerScreen extends StatefulWidget {
  final String propertyId;
  final List<UnitModel> units;

  const UtilityManagerScreen({
    super.key,
    required this.propertyId,
    required this.units,
  });

  @override
  State<UtilityManagerScreen> createState() => _UtilityManagerScreenState();
}

class _UtilityManagerScreenState extends State<UtilityManagerScreen> {
  final FirestoreService _firestore = FirestoreService();

  UnitModel? _selectedUnit;
  String _utilityType = 'electricity'; // 'electricity' | 'water' | 'maintenance'

  // Sub-meter fields (Electricity & Metered Water)
  final _prevReadingCtrl = TextEditingController(text: '0');
  final _currReadingCtrl = TextEditingController(text: '0');
  final _electricRateCtrl = TextEditingController(text: '9.0'); // ₹9/kWh

  // Water mode & fields
  String _waterMode = 'metered'; // 'metered' | 'flat'
  final _waterRateCtrl = TextEditingController(text: '25.0'); // ₹25/KL
  final _waterFlatAmountCtrl = TextEditingController(text: '300');

  // Maintenance / Society fees mode & fields
  String _maintenanceMode = 'fixed'; // 'fixed' | 'sqft'
  final _maintFixedAmountCtrl = TextEditingController(text: '1500');
  final _maintSqFtAreaCtrl = TextEditingController(text: '500');
  final _maintSqFtRateCtrl = TextEditingController(text: '3.0'); // ₹3/sqft

  final _notesCtrl = TextEditingController();
  bool _isSaving = false;

  void _calculateAndLogBill() async {
    if (_selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a unit/room first')),
      );
      return;
    }

    double calculatedAmount = 0.0;
    double prevReading = 0.0;
    double currReading = 0.0;
    double unitRate = 0.0;
    String summaryNote = '';

    if (_utilityType == 'electricity') {
      prevReading = double.tryParse(_prevReadingCtrl.text.trim()) ?? 0;
      currReading = double.tryParse(_currReadingCtrl.text.trim()) ?? 0;
      unitRate = double.tryParse(_electricRateCtrl.text.trim()) ?? 0;

      if (currReading < prevReading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current electric reading cannot be less than previous reading')),
        );
        return;
      }
      final unitsConsumed = currReading - prevReading;
      calculatedAmount = unitsConsumed * unitRate;
      summaryNote = '$unitsConsumed kWh @ ₹$unitRate/unit';
    } else if (_utilityType == 'water') {
      if (_waterMode == 'metered') {
        prevReading = double.tryParse(_prevReadingCtrl.text.trim()) ?? 0;
        currReading = double.tryParse(_currReadingCtrl.text.trim()) ?? 0;
        unitRate = double.tryParse(_waterRateCtrl.text.trim()) ?? 0;

        if (currReading < prevReading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Current water reading cannot be less than previous reading')),
          );
          return;
        }
        final unitsConsumed = currReading - prevReading;
        calculatedAmount = unitsConsumed * unitRate;
        summaryNote = '$unitsConsumed KL @ ₹$unitRate/KL';
      } else {
        calculatedAmount = double.tryParse(_waterFlatAmountCtrl.text.trim()) ?? 0;
        summaryNote = 'Flat Monthly Water Charge';
      }
    } else if (_utilityType == 'maintenance') {
      if (_maintenanceMode == 'fixed') {
        calculatedAmount = double.tryParse(_maintFixedAmountCtrl.text.trim()) ?? 0;
        summaryNote = 'Fixed Monthly Society Maintenance';
      } else {
        final area = double.tryParse(_maintSqFtAreaCtrl.text.trim()) ?? 0;
        final rate = double.tryParse(_maintSqFtRateCtrl.text.trim()) ?? 0;
        calculatedAmount = area * rate;
        summaryNote = '$area Sq.Ft. @ ₹$rate/Sq.Ft.';
      }
    }

    if (calculatedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid bill amounts or readings')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final periodMonth = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";

      String matchedDealId = '';
      String matchedRenterId = '';
      try {
        final dealsSnap = await FirebaseFirestore.instance
            .collection('deals')
            .where('propertyId', isEqualTo: widget.propertyId)
            .where('status', isEqualTo: 'active')
            .get();
        for (var doc in dealsSnap.docs) {
          final data = doc.data();
          final uId = data['currentUnitId'] ?? data['unitId'] ?? '';
          final assigned = List<String>.from(data['assignedUnitIds'] ?? []);
          if (uId == _selectedUnit!.id || assigned.contains(_selectedUnit!.id)) {
            matchedDealId = doc.id;
            matchedRenterId = (data['renterId'] ?? '').toString();
            break;
          }
        }
      } catch (_) {}

      final billData = <String, dynamic>{
        'propertyId': widget.propertyId,
        'unitId': _selectedUnit!.id,
        'unitLabel': _selectedUnit!.label,
        'dealId': matchedDealId,
        'renterId': matchedRenterId,
        'renterUid': matchedRenterId,
        'periodMonth': periodMonth,
        'utilityType': _utilityType,
        'calculationSummary': summaryNote,
        'previousReading': prevReading,
        'currentReading': currReading,
        'unitRate': unitRate,
        'netAmount': calculatedAmount,
        'notes': _notesCtrl.text.trim(),
        'createdAt': DateTime.now(),
      };

      await _firestore.createUtilityBill(billData);

      if (mounted) {
        _notesCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Utility Bill Logged: Unit ${_selectedUnit!.label} • ${_utilityType.toUpperCase()} = ₹${calculatedAmount.toStringAsFixed(0)} ($summaryNote)',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log bill: $e')),
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
        title: const Text('Utility Sub-Meter & Society Fees'),
      ),
      body: StreamBuilder<List<UnitModel>>(
        stream: _firestore.streamUnits(widget.propertyId),
        builder: (context, unitSnap) {
          final liveUnits = (unitSnap.data != null && unitSnap.data!.isNotEmpty)
              ? unitSnap.data!
              : widget.units;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.bolt, color: AppTheme.goldAccent, size: 36),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Utility & Maintenance Calculator',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Calculate electricity sub-meters, water charges, and society fees for residents.',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Step 1: Select Unit Dropdown (Dynamic Stream)
                const Text('1. Select Unit / Flat / Shop', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy)),
                const SizedBox(height: 8),
                DropdownButtonFormField<UnitModel>(
                  initialValue: _selectedUnit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Choose Unit',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.home_work_outlined, color: AppTheme.primaryNavy),
                  ),
                  items: liveUnits
                      .map((u) => DropdownMenuItem(
                            value: u,
                            child: Text(
                              'Unit ${u.label} (${u.floor} Floor • ${u.type.toUpperCase()})',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ))
                      .toList(),
                  onChanged: (u) => setState(() => _selectedUnit = u),
                ),
                const SizedBox(height: 20),

                // Step 2: Select Utility Type
                const Text('2. Select Utility Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.flash_on, size: 18),
                      label: const Text('Electricity'),
                      selected: _utilityType == 'electricity',
                      onSelected: (_) => setState(() => _utilityType = 'electricity'),
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.water_drop, size: 18),
                      label: const Text('Water'),
                      selected: _utilityType == 'water',
                      onSelected: (_) => setState(() => _utilityType = 'water'),
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.build, size: 18),
                      label: const Text('Society Fees'),
                      selected: _utilityType == 'maintenance',
                      onSelected: (_) => setState(() => _utilityType = 'maintenance'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Step 3: Specific Calculation Form Body per Utility Type
                if (_utilityType == 'electricity') ...[
                  _buildElectricityForm(),
                ] else if (_utilityType == 'water') ...[
                  _buildWaterForm(),
                ] else ...[
                  _buildMaintenanceForm(),
                ],

                const SizedBox(height: 16),
                const Text('Notes / Calculation Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. August 2026 sub-meter reading',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
                    onPressed: _isSaving ? null : _calculateAndLogBill,
                    icon: const Icon(Icons.calculate_outlined),
                    label: Text(_isSaving ? 'Logging Bill...' : 'Calculate & Issue Utility Bill'),
                  ),
                ),
                const SizedBox(height: 32),

                const Text('Recent Utility Bills Logged', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryNavy)),
                const SizedBox(height: 12),

                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _firestore.streamUtilityBills(widget.propertyId),
                  builder: (context, snapshot) {
                    final bills = snapshot.data ?? [];
                    if (bills.isEmpty) {
                      return const Text('No utility bills logged yet for this property.', style: TextStyle(color: Colors.grey));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: bills.length,
                      itemBuilder: (ctx, i) {
                        final b = bills[i];
                        final net = (b['netAmount'] as num?)?.toDouble() ?? 0.0;
                        final type = (b['utilityType'] as String? ?? 'utility').toUpperCase();
                        final unitLabel = b['unitLabel'] ?? 'Unit';
                        final summary = b['calculationSummary'] ?? '';

                        IconData icon;
                        Color iconColor;
                        if (type == 'ELECTRICITY') {
                          icon = Icons.flash_on;
                          iconColor = Colors.amber;
                        } else if (type == 'WATER') {
                          icon = Icons.water_drop;
                          iconColor = Colors.blue;
                        } else {
                          icon = Icons.build;
                          iconColor = AppTheme.primaryTeal;
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: iconColor.withAlpha(30),
                              child: Icon(icon, color: iconColor, size: 20),
                            ),
                            title: Text('Unit $unitLabel • ₹${net.toStringAsFixed(0)} ($type)'),
                            subtitle: Text('Period: ${b['periodMonth']} • $summary'),
                            trailing: Text('₹${net.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Electricity Calculation Form (Sub-meter kWh)
  Widget _buildElectricityForm() {
    final prev = double.tryParse(_prevReadingCtrl.text.trim()) ?? 0;
    final curr = double.tryParse(_currReadingCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_electricRateCtrl.text.trim()) ?? 0;
    final unitsConsumed = (curr - prev).clamp(0, double.infinity);
    final total = unitsConsumed * rate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Electric Sub-Meter Calculation (kWh)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 420) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _prevReadingCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Prev Reading (kWh)', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _currReadingCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Curr Reading (kWh)', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _electricRateCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Rate (₹/kWh)', border: OutlineInputBorder()),
                    ),
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _prevReadingCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Prev Reading (kWh)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _currReadingCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Curr Reading (kWh)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _electricRateCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Rate (₹/kWh)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Units Consumed: ${unitsConsumed.toStringAsFixed(1)} kWh', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Total: ₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy)),
            ],
          ),
        ],
      ),
    );
  }

  // Water Calculation Form (Metered KL vs Flat Monthly Fee)
  Widget _buildWaterForm() {
    double total = 0.0;
    if (_waterMode == 'metered') {
      final prev = double.tryParse(_prevReadingCtrl.text.trim()) ?? 0;
      final curr = double.tryParse(_currReadingCtrl.text.trim()) ?? 0;
      final rate = double.tryParse(_waterRateCtrl.text.trim()) ?? 0;
      final units = (curr - prev).clamp(0, double.infinity);
      total = units * rate;
    } else {
      total = double.tryParse(_waterFlatAmountCtrl.text.trim()) ?? 0;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Water Charge Calculation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Sub-Metered (KL / Liters)'),
                selected: _waterMode == 'metered',
                onSelected: (_) => setState(() => _waterMode = 'metered'),
              ),
              ChoiceChip(
                label: const Text('Flat Monthly Water Charge'),
                selected: _waterMode == 'flat',
                onSelected: (_) => setState(() => _waterMode = 'flat'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_waterMode == 'metered') ...[
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 420) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _prevReadingCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(labelText: 'Prev Reading (KL)', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _currReadingCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(labelText: 'Curr Reading (KL)', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _waterRateCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Rate (₹/KL)', border: OutlineInputBorder()),
                      ),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _prevReadingCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Prev Reading (KL)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _currReadingCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Curr Reading (KL)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _waterRateCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Rate (₹/KL)', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ] else ...[
            TextField(
              controller: _waterFlatAmountCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Fixed Monthly Water Charge (INR) *', border: OutlineInputBorder()),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Total Water Amount: ₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy)),
          ),
        ],
      ),
    );
  }

  // Maintenance & Society Fees Form (Fixed Fee vs Per Sq.Ft Charge)
  Widget _buildMaintenanceForm() {
    double total = 0.0;
    if (_maintenanceMode == 'fixed') {
      total = double.tryParse(_maintFixedAmountCtrl.text.trim()) ?? 0;
    } else {
      final area = double.tryParse(_maintSqFtAreaCtrl.text.trim()) ?? 0;
      final rate = double.tryParse(_maintSqFtRateCtrl.text.trim()) ?? 0;
      total = area * rate;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Society Maintenance & Fees', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Fixed Monthly Fee (INR)'),
                selected: _maintenanceMode == 'fixed',
                onSelected: (_) => setState(() => _maintenanceMode = 'fixed'),
              ),
              ChoiceChip(
                label: const Text('Per Sq. Ft. Charge'),
                selected: _maintenanceMode == 'sqft',
                onSelected: (_) => setState(() => _maintenanceMode = 'sqft'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_maintenanceMode == 'fixed') ...[
            TextField(
              controller: _maintFixedAmountCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Monthly Maintenance Fee (INR) *', border: OutlineInputBorder()),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _maintSqFtAreaCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Unit Area (Sq. Ft.)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maintSqFtRateCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Rate (₹ / Sq. Ft.)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Total Society Maintenance: ₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy)),
          ),
        ],
      ),
    );
  }
}
