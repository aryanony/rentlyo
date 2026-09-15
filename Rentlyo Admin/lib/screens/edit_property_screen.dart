import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/localization.dart';
import '../models/property_model.dart';
import '../services/firestore_service.dart';

class EditPropertyScreen extends StatefulWidget {
  final PropertyModel property;

  const EditPropertyScreen({super.key, required this.property});

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestore = FirestoreService();

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _contactController;
  late TextEditingController _currencyController;
  late TextEditingController _primaryColorController;
  late TextEditingController _accentColorController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.property.name);
    _addressController = TextEditingController(text: widget.property.address);
    _contactController = TextEditingController(text: widget.property.contactPhone ?? '');
    _currencyController = TextEditingController(text: widget.property.defaultCurrency);
    _primaryColorController = TextEditingController(text: widget.property.primaryColorHex ?? '123642');
    _accentColorController = TextEditingController(text: widget.property.accentColorHex ?? 'C6A24D');
  }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedProperty = PropertyModel(
        id: widget.property.id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        ownerUid: widget.property.ownerUid,
        defaultCurrency: _currencyController.text.trim().toUpperCase(),
        contactPhone: _contactController.text.trim(),
        primaryColorHex: _primaryColorController.text.trim(),
        accentColorHex: _accentColorController.text.trim(),
        logoAssetRef: widget.property.logoAssetRef,
        createdAt: widget.property.createdAt,
        updatedAt: DateTime.now(),
      );

      await _firestore.updateProperty(updatedProperty);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property details updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update property: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalization.tr('edit_property')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.business, color: AppTheme.primaryNavy, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Update your property name, address, and white-label theme settings anytime.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Property / Complex Name *',
                  prefixIcon: Icon(Icons.location_city),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Property name is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Property Address *',
                  prefixIcon: Icon(Icons.place),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Address is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Management Contact Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _currencyController,
                decoration: const InputDecoration(
                  labelText: 'Default Currency Code (e.g. INR)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 24),

              const Text('Branding & White-Label Hex Colors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy)),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _primaryColorController,
                      decoration: const InputDecoration(
                        labelText: 'Primary Color Hex (e.g. 123642)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _accentColorController,
                      decoration: const InputDecoration(
                        labelText: 'Accent Color Hex (e.g. C6A24D)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveProperty,
                icon: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.save),
                label: const Text('Save Property Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
