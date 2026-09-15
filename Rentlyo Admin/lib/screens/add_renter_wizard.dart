import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../core/secondary_auth.dart';
import '../core/phone_utils.dart';
import '../models/unit_model.dart';
import '../models/user_model.dart';
import '../models/deal_model.dart';
import '../services/firestore_service.dart';
import '../core/rent_engine.dart';

class AddRenterWizard extends StatefulWidget {
  final UnitModel unit;

  const AddRenterWizard({super.key, required this.unit});

  @override
  State<AddRenterWizard> createState() => _AddRenterWizardState();
}

class _AddRenterWizardState extends State<AddRenterWizard> {
  int _currentStep = 0;
  final FirestoreService _firestore = FirestoreService();
  bool _isLoading = false;

  // Step 2: Renter info
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController(text: '123456');
  final _businessNameController = TextEditingController();
  final _businessCatController = TextEditingController();
  final _occupantsController = TextEditingController(text: '1');

  bool _maintenanceIncluded = false;
  UserModel? _existingUserFound;
  bool _isCheckingPhone = false;

  // Step 3: Deal info & Rent Schedule
  final _rentController = TextEditingController(text: '8000');
  final _advanceController = TextEditingController(text: '96000');
  final _advanceMonthsController = TextEditingController(text: '12');
  final _agreementDriveLinkController = TextEditingController();
  final _notesController = TextEditingController();

  bool _advanceConsumptionMode = true;
  bool _stepUpEnabled = false;
  final _stepUpMonthController = TextEditingController(text: '13');
  final _stepUpAmountController = TextEditingController(text: '10000');
  DateTime _startDate = DateTime.now();

  bool get _isPastDeal {
    final now = DateTime.now();
    return _startDate.year < now.year || (_startDate.year == now.year && _startDate.month < now.month);
  }
  bool _settlePastRentsOnboarding = true;
  bool _enablePastRentHistory = false;
  bool _alreadyHasThisUnit = false;
  final List<RentScheduleItem> _historicalSchedule = [];
  DateTime? _histDate;
  final _histRentController = TextEditingController(text: '5000');

  // Step 4: Agreement document
  String _agreementType = 'upload'; // 'upload' | 'drive-link'
  String? _agreementBase64;

  Set<String> _selectedUnitIds = {};
  Set<String> _selectedUnitLabels = {};

  @override
  void initState() {
    super.initState();
    _selectedUnitIds = {widget.unit.id};
    _selectedUnitLabels = {widget.unit.label};
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _businessNameController.dispose();
    _businessCatController.dispose();
    _occupantsController.dispose();
    _rentController.dispose();
    _advanceController.dispose();
    _advanceMonthsController.dispose();
    _agreementDriveLinkController.dispose();
    _notesController.dispose();
    _stepUpMonthController.dispose();
    _stepUpAmountController.dispose();
    _histRentController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() async {
    final phone = _phoneController.text.trim();
    if (phone.length >= 10) {
      if (!_isCheckingPhone) {
        setState(() => _isCheckingPhone = true);
        final found = await _firestore.findUserByPhone(phone);
        final hasUnit = await _firestore.checkIfRenterHasUnit(
          phone: phone,
          unitId: widget.unit.id,
          unitLabel: widget.unit.label,
        );
        if (mounted) {
          setState(() {
            _existingUserFound = found;
            _alreadyHasThisUnit = hasUnit;
            if (found != null && _nameController.text.isEmpty) {
              _nameController.text = found.name;
            }
            _isCheckingPhone = false;
          });
        }
      }
    } else if (_existingUserFound != null || _alreadyHasThisUnit) {
      setState(() {
        _existingUserFound = null;
        _alreadyHasThisUnit = false;
      });
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  void _addHistoricalScheduleEntry() {
    final rent = double.tryParse(_histRentController.text);

    if (_histDate == null || rent == null || rent <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date and enter a valid rent amount.')),
      );
      return;
    }

    setState(() {
      _historicalSchedule.removeWhere((item) =>
          item.effectiveFromDate.year == _histDate!.year &&
          item.effectiveFromDate.month == _histDate!.month);
      _historicalSchedule.add(RentScheduleItem(effectiveFromDate: _histDate!, monthlyRent: rent));
      _historicalSchedule.sort((a, b) => a.effectiveFromDate.compareTo(b.effectiveFromDate));
      _histRentController.clear();
      _histDate = null;
    });
  }

  Future<void> _pickAgreementPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _agreementBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _submitWizard() async {
    final name = _nameController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final phone = PhoneUtils.sanitizeTenDigitPhone(rawPhone);
    final password = _passwordController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all required tenant details.')),
      );
      return;
    }

    if (_existingUserFound == null && password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Security Requirement: Password must be at least 6 characters long.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentOwnerUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // Section 1: Check existing user or create clean user
      String authUid;
      String renterId;
      UserModel renterUser;

      final existingUser = _existingUserFound ?? await _firestore.findUserByPhone(phone);

      if (existingUser != null) {
        // Same person, new deal — Reuse Auth UID & stable renterId cleanly!
        try {
          await SecondaryAuthService.createOrUpdateRenterAccount(
            phone: phone,
            password: password,
            oldPassword: existingUser.renterPassword,
          );
        } catch (_) {}
        authUid = existingUser.uid;
        renterId = existingUser.renterId;
        renterUser = UserModel(
          uid: existingUser.uid,
          renterId: existingUser.renterId,
          role: existingUser.role,
          name: name.isNotEmpty ? name : existingUser.name,
          phone: existingUser.phone,
          pseudoEmail: existingUser.pseudoEmail,
          renterPassword: password,
          propertyIds: existingUser.propertyIds,
          active: true,
          createdAt: existingUser.createdAt,
          createdBy: existingUser.createdBy,
        );
      } else {
        // Fresh person — Create Auth account via Secondary Auth Instance
        try {
          final cred = await SecondaryAuthService.createOrUpdateRenterAccount(
            phone: phone,
            password: password,
          );
          authUid = cred.user!.uid;
          final cleanUnitLabel = widget.unit.label.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
          final cleanName = name.split(' ').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
          renterId = "$cleanUnitLabel-$cleanName";

          renterUser = UserModel(
            uid: authUid,
            renterId: renterId,
            role: 'renter',
            name: name,
            phone: phone,
            pseudoEmail: PhoneUtils.toPseudoEmail(phone),
            renterPassword: password,
            propertyIds: [widget.unit.propertyId],
            active: true,
            createdAt: DateTime.now(),
            createdBy: currentOwnerUid,
          );
        } catch (e) {
          // Auth creation failed — try to find an existing Firestore user as fallback
          final retryUser = await _firestore.findUserByPhone(phone);
          if (retryUser != null) {
            // User doc exists — verify and repair the Auth account
            try {
              final repairedUser = await _firestore.verifyAndRepairRenterAuth(retryUser);
              authUid = repairedUser.uid;
              renterId = repairedUser.renterId;
              renterUser = repairedUser;
            } catch (_) {
              authUid = retryUser.uid;
              renterId = retryUser.renterId;
              renterUser = retryUser;
            }
          } else {
            // No existing user and Auth failed — surface the error clearly
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not create login account: $e\nThe deal will be created, but the tenant login must be set up separately from the Renter Detail screen.'),
                  duration: const Duration(seconds: 6),
                  backgroundColor: Colors.orange.shade700,
                ),
              );
            }
            // Create user doc WITHOUT a phantom UID — use a temp doc ID that Firestore generates
            final pseudoEmail = PhoneUtils.toPseudoEmail(phone);
            final cleanUnitLabel = widget.unit.label.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
            final cleanName = name.split(' ').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
            renterId = "$cleanUnitLabel-$cleanName";
            // Use a Firestore-generated doc ID — the admin can "Create Tenant Login Account" later
            authUid = 'pending_auth_${DateTime.now().millisecondsSinceEpoch}';

            renterUser = UserModel(
              uid: authUid,
              renterId: renterId,
              role: 'renter',
              name: name,
              phone: phone,
              pseudoEmail: pseudoEmail,
              renterPassword: password,
              propertyIds: [widget.unit.propertyId],
              active: true,
              createdAt: DateTime.now(),
              createdBy: currentOwnerUid,
            );
          }
        }
      }

      // Build Rent Schedule List (Section 6: Onboarding Long-Standing Renters)
      List<RentScheduleItem> schedule = [];
      if (_isPastDeal && _enablePastRentHistory && _historicalSchedule.isNotEmpty) {
        schedule = List.from(_historicalSchedule);
      } else {
        final startingRent = double.tryParse(_rentController.text) ?? 8000.0;
        schedule = [
          RentScheduleItem(effectiveFromDate: _startDate, monthlyRent: startingRent),
        ];

        if (_stepUpEnabled) {
          final stepMonths = int.tryParse(_stepUpMonthController.text) ?? 12;
          final stepRent = double.tryParse(_stepUpAmountController.text) ?? 10000.0;
          final stepDate = DateTime(_startDate.year, _startDate.month + stepMonths, _startDate.day);
          schedule.add(RentScheduleItem(effectiveFromDate: stepDate, monthlyRent: stepRent));
        }
      }

      schedule.sort((a, b) => a.effectiveFromDate.compareTo(b.effectiveFromDate));

      final advanceAmt = double.tryParse(_advanceController.text) ?? 0.0;
      final advTx = advanceAmt > 0
          ? [AdvanceTransactionItem(date: _startDate, amount: advanceAmt, note: 'Move-in Advance Deposit')]
          : <AdvanceTransactionItem>[];

      final unitHist = [UnitHistoryItem(unitId: widget.unit.id, unitLabel: widget.unit.label, fromDate: _startDate, toDate: null)];
      final autoDueDay = _startDate.day > 28 ? 28 : _startDate.day;

      final sortedUnitLabels = _selectedUnitLabels.toList()..sort();
      final combinedUnitLabel = sortedUnitLabels.join(' + ');

      // Build Deal Model
      final deal = DealModel(
        id: '',
        propertyId: widget.unit.propertyId,
        currentUnitId: widget.unit.id,
        renterId: renterId,
        renterType: widget.unit.type.trim().isNotEmpty
            ? widget.unit.type
            : (widget.unit.category == 'shop' || widget.unit.label.toLowerCase().contains('shop') ? 'commercial' : 'residential'),
        dealStartDate: _startDate,
        rentSchedule: schedule,
        rentDueDayOfMonth: autoDueDay,
        advanceTransactions: advTx,
        advanceConsumptionMode: _advanceConsumptionMode,
        unitHistory: unitHist,
        amenities: [],
        carryForwardPendingBalance: true,
        agreementType: _agreementType,
        agreementFileBase64: _agreementType == 'upload' ? _agreementBase64 : null,
        agreementDriveLink: _agreementType == 'drive-link' && _agreementDriveLinkController.text.trim().isNotEmpty
            ? _agreementDriveLinkController.text.trim()
            : null,
        status: 'active',
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        businessName: _businessNameController.text.trim().isNotEmpty ? _businessNameController.text.trim() : name,
        businessCategory: _businessCatController.text.trim(),
        occupantCount: int.tryParse(_occupantsController.text),
        maintenanceIncluded: _maintenanceIncluded,
        unitLabel: combinedUnitLabel,
        unitCode: "AP-$combinedUnitLabel",
        assignedUnitIds: _selectedUnitIds.toList(),
        assignedUnitLabels: sortedUnitLabels,
      );

      // Write to Firestore & flip unit status to 'occupied'
      final createdDeal = await _firestore.createRenterAndDeal(renterUser: renterUser, deal: deal);

      if (_isPastDeal && _settlePastRentsOnboarding) {
        final currentPeriod = RentEngine.formatPeriodMonth(DateTime.now());
        await _firestore.settlePastRentsToDate(
          deal: createdDeal,
          targetPeriodMonth: currentPeriod,
          ownerUid: currentOwnerUid,
          note: 'Initial Onboarding — All Past Rents Settled to $currentPeriod',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Renter deal created successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete onboarding: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rent ${widget.unit.label} • Add Renter')),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepTapped: (step) => setState(() => _currentStep = step),
        onStepContinue: () {
          if (_currentStep < 4) {
            setState(() => _currentStep += 1);
          } else {
            _submitWizard();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        steps: [
          Step(
            title: const Text('1. Unit Confirmation & Multi-Unit Selection'),
            content: StreamBuilder<List<UnitModel>>(
              stream: _firestore.streamUnits(widget.unit.propertyId),
              builder: (context, snap) {
                final allUnits = snap.data ?? [];
                final primaryIsComm = widget.unit.isCommercial;
                final availableUnits = allUnits.where((u) {
                  final isVacantOrSelf = u.status == 'vacant' || u.id == widget.unit.id || u.label == widget.unit.label;
                  if (!isVacantOrSelf) return false;
                  return u.isCommercial == primaryIsComm;
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 0,
                      color: AppTheme.primaryNavy.withAlpha(10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.primaryNavy),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.star, color: AppTheme.goldAccent),
                        title: Text('${widget.unit.label} (Primary Unit)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text('Type: ${widget.unit.type.toUpperCase()} • Floor: ${widget.unit.floor}'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Select Additional Vacant Units (Optional):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'If this tenant is leasing multiple units (e.g. G7 + G8), select them below to combine into 1 single lease agreement.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10),
                    if (availableUnits.length <= 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No other vacant units currently available in this property.',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableUnits.map((u) {
                          final isPrimary = u.id == widget.unit.id || u.label == widget.unit.label;
                          final isSelected = _selectedUnitIds.contains(u.id) || _selectedUnitLabels.contains(u.label);

                          return FilterChip(
                            selected: isSelected,
                            label: Text(
                              isPrimary ? '${u.label} (Primary)' : u.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppTheme.primaryNavy,
                              ),
                            ),
                            selectedColor: AppTheme.primaryNavy,
                            checkmarkColor: Colors.white,
                            backgroundColor: Colors.grey.shade100,
                            onSelected: isPrimary
                                ? null
                                : (val) {
                                    setState(() {
                                      if (val) {
                                        _selectedUnitIds.add(u.id);
                                        _selectedUnitLabels.add(u.label);
                                      } else {
                                        _selectedUnitIds.remove(u.id);
                                        _selectedUnitLabels.remove(u.label);
                                      }
                                    });
                                  },
                          );
                        }).toList(),
                      ),
                    if (_selectedUnitLabels.length > 1) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF93C5FD)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.domain_add, color: AppTheme.primaryNavy, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Combined Multi-Unit Deal: ${_selectedUnitLabels.join(" + ")} (${_selectedUnitLabels.length} Units)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text('2. Tenant Info & Login Account'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_alreadyHasThisUnit)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Unit Already Assigned!\n'
                            '${_existingUserFound?.name ?? "This tenant"} already has an active lease for ${widget.unit.label}.',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_existingUserFound != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_pin, color: Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Existing Tenant Account Found for ${_existingUserFound!.name}.\n'
                            'Login account already exists. Password is disabled and ${widget.unit.label} will be added to their existing login account.',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number (Used for Tenant Login) *',
                    suffixIcon: _isCheckingPhone ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Tenant Full Name *'),
                ),
                if (_existingUserFound == null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Initial Account Password *',
                      helperText: 'Minimum 6 characters for security',
                    ),
                  ),
                ],
                if (widget.unit.type == 'commercial') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _businessNameController,
                    decoration: const InputDecoration(labelText: 'Shop / Business Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _businessCatController,
                    decoration: const InputDecoration(labelText: 'Business Category (Optional)'),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _occupantsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Number of Occupants'),
                  ),
                  SwitchListTile(
                    title: const Text('Maintenance Included in Rent'),
                    value: _maintenanceIncluded,
                    onChanged: (val) => setState(() => _maintenanceIncluded = val),
                  ),
                ],
              ],
            ),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: const Text('3. Deal Start & Rent Schedule'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Deal Start Date Picker (Section 6)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Deal Start Date: ${_startDate.day}/${_startDate.month}/${_startDate.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Tap to set past or current date'),
                  trailing: OutlinedButton.icon(
                    onPressed: _pickStartDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('Change Date'),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(top: 4, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withAlpha(12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryNavy.withAlpha(30)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_repeat_rounded, color: AppTheme.primaryNavy, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Rent Due Day: ${(_startDate.day > 28 ? 28 : _startDate.day)}th of every month (Fixed automatically from Start Date)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                TextField(
                  controller: _rentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Starting Monthly Rent (INR) *', prefixText: '₹ '),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Add Scheduled Rent Increase Step'),
                  subtitle: const Text('Auto-increases rent after specific months (e.g., Month 13)'),
                  value: _stepUpEnabled,
                  onChanged: (val) => setState(() => _stepUpEnabled = val),
                ),
                if (_stepUpEnabled) ...[
                  TextField(
                    controller: _stepUpMonthController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Effective From Month # (e.g. 13)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _stepUpAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'New Monthly Rent (e.g. 10000)', prefixText: '₹ '),
                  ),
                ],

                // Smart Past Deal Auto-Detection
                if (_isPastDeal) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFF166534), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Past Deal Auto-Detected (Started ${_startDate.day}/${_startDate.month}/${_startDate.year}). Past months will show settled automatically.',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mark all past monthly rents as PAID up to today'),
                    subtitle: const Text('Automatically settles past months so tenant shows PAID up to current date'),
                    value: _settlePastRentsOnboarding,
                    onChanged: (val) => setState(() => _settlePastRentsOnboarding = val),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Add past rent changes in previous years (Optional)'),
                    subtitle: const Text('Turn ON only if rent was increased over time (e.g. ₹8,000 in 2023 ➔ ₹10,000 in 2024)'),
                    value: _enablePastRentHistory,
                    onChanged: (val) => setState(() => _enablePastRentHistory = val),
                  ),

                  if (_enablePastRentHistory) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rent History Entry Builder',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Text(
                            'Pick a date and enter the rent amount for each historical rent change.',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _histDate ?? _startDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setState(() => _histDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month, size: 20, color: Color(0xFF0F172A)),
                                      const SizedBox(width: 10),
                                      Text(
                                        _histDate != null
                                            ? 'Effective Date: ${_histDate!.day}/${_histDate!.month}/${_histDate!.year}'
                                            : 'Tap to Select Effective Date',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _histRentController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Monthly Rent (INR)',
                                        prefixText: '₹ ',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: _addHistoricalScheduleEntry,
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add Step'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (_historicalSchedule.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _historicalSchedule.map((item) {
                                final d = item.effectiveFromDate;
                                return Chip(
                                  label: Text('${d.day}/${d.month}/${d.year}: ₹${item.monthlyRent.toStringAsFixed(0)}'),
                                  onDeleted: () {
                                    setState(() {
                                      _historicalSchedule.remove(item);
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryNavy.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available, color: Color(0xFF0F172A)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Monthly Rent Due Day: Every ${_startDate.day > 28 ? 28 : _startDate.day}${_getDaySuffix(_startDate.day > 28 ? 28 : _startDate.day)} of the month\n(Auto-matched with Deal Start Date)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _advanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Security Advance Received (INR) *'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Deduct rent from advance balance'),
                  subtitle: const Text('Auto-sets payment status to "adjusted-against-advance"'),
                  value: _advanceConsumptionMode,
                  onChanged: (val) => setState(() => _advanceConsumptionMode = val),
                ),
                if (_advanceConsumptionMode)
                  TextField(
                    controller: _advanceMonthsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Advance Consumption Period (Months)'),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'History Notes / Paper Ledger Reference (Optional)',
                    hintText: 'e.g. Original physical agreement signed Apr 2018 in Box #4',
                  ),
                ),
              ],
            ),
            isActive: _currentStep >= 2,
          ),
          Step(
            title: const Text('4. Rent Agreement Document'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioGroup<String>(
                  groupValue: _agreementType,
                  onChanged: (val) => setState(() => _agreementType = val!),
                  child: const Column(
                    children: [
                      RadioListTile<String>(
                        title: Text('Upload Scanned Document (Base64)'),
                        value: 'upload',
                      ),
                      RadioListTile<String>(
                        title: Text('Paste Google Drive Document URL'),
                        value: 'drive-link',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_agreementType == 'upload') ...[
                  if (_agreementBase64 != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(base64Decode(_agreementBase64!), height: 160),
                    )
                  else
                    const Text('No agreement photo attached yet.'),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _pickAgreementPhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Scan / Select Agreement Photo'),
                  ),
                ] else ...[
                  TextField(
                    controller: _agreementDriveLinkController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Google Drive Document Link',
                      hintText: 'https://drive.google.com/file/d/...',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                ],
              ],
            ),
            isActive: _currentStep >= 3,
          ),
          Step(
            title: const Text('5. Summary & Onboard'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 0,
                  color: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tenant & Login Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy)),
                            TextButton.icon(
                              onPressed: () => setState(() => _currentStep = 1),
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Edit Step 2'),
                            ),
                          ],
                        ),
                        Text('Tenant Name: ${_nameController.text.isNotEmpty ? _nameController.text : "Not provided"}', style: const TextStyle(fontSize: 13)),
                        Text('Phone Number: ${_phoneController.text.isNotEmpty ? _phoneController.text : "Not provided"}', style: const TextStyle(fontSize: 13)),
                        if (widget.unit.type == 'commercial' && _businessNameController.text.isNotEmpty)
                          Text('Business Name: ${_businessNameController.text}', style: const TextStyle(fontSize: 13)),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Deal & Rent Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy)),
                            TextButton.icon(
                              onPressed: () => setState(() => _currentStep = 2),
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Edit Step 3'),
                            ),
                          ],
                        ),
                        Text('Deal Start Date: ${_startDate.day}/${_startDate.month}/${_startDate.year}', style: const TextStyle(fontSize: 13)),
                        Text('Monthly Rent: ₹${_rentController.text}', style: const TextStyle(fontSize: 13)),
                        Text('Advance Received: ₹${_advanceController.text}', style: const TextStyle(fontSize: 13)),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Rent Agreement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy)),
                            TextButton.icon(
                              onPressed: () => setState(() => _currentStep = 3),
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Edit Step 4'),
                            ),
                          ],
                        ),
                        Text('Document: ${_agreementType == "upload" ? (_agreementBase64 != null ? "Scanned Photo Uploaded" : "No photo attached") : (_agreementDriveLinkController.text.isNotEmpty ? "Google Drive Link" : "No link entered")}', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                      onPressed: _submitWizard,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Finalize & Create Renter Account'),
                    ),
                  ),
              ],
            ),
            isActive: _currentStep >= 4,
          ),
        ],
      ),
    );
  }
}
