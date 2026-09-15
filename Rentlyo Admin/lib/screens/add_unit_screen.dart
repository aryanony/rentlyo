import 'package:flutter/material.dart';
import '../models/unit_model.dart';
import '../services/firestore_service.dart';

class AddUnitScreen extends StatefulWidget {
  final String propertyId;
  final String initialType;

  const AddUnitScreen({super.key, required this.propertyId, this.initialType = 'commercial'});

  @override
  State<AddUnitScreen> createState() => _AddUnitScreenState();
}

class _AddUnitScreenState extends State<AddUnitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirestoreService();

  late String _label;
  late String _type;
  String _floor = 'Ground';
  double? _sizeSqft;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final unit = UnitModel(
        id: '',
        propertyId: widget.propertyId,
        label: _label,
        type: _type,
        category: _type == 'commercial' ? 'shop' : 'flat',
        floor: _floor,
        sizeSqft: _sizeSqft,
        status: 'vacant',
      );

      await _firestore.addUnit(unit);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add unit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Unit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Unit Label / Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'e.g. Shop 1 or Flat 101',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Please enter a label' : null,
                onSaved: (val) => _label = val!,
              ),
              const SizedBox(height: 20),

              const Text('Unit Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'commercial', label: Text('Commercial')),
                  ButtonSegment(value: 'residential', label: Text('Residential')),
                ],
                selected: {_type},
                onSelectionChanged: (set) => setState(() => _type = set.first),
              ),
              const SizedBox(height: 20),

              const Text('Floor Level', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _floor,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Ground', child: Text('Ground Floor')),
                  DropdownMenuItem(value: '1st', child: Text('1st Floor')),
                  DropdownMenuItem(value: '2nd', child: Text('2nd Floor')),
                  DropdownMenuItem(value: '3rd', child: Text('3rd Floor')),
                ],
                onChanged: (val) => setState(() => _floor = val ?? 'Ground'),
              ),
              const SizedBox(height: 20),

              const Text('Size (Sq. Ft.) - Optional', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'e.g. 450',
                  border: OutlineInputBorder(),
                ),
                onSaved: (val) => _sizeSqft = double.tryParse(val ?? ''),
              ),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check),
                label: const Text('Save Unit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
