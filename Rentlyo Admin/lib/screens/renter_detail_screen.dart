import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../core/localization.dart';
import '../core/local_security.dart';
import '../core/phone_utils.dart';
import '../core/secondary_auth.dart';
import '../core/brand_config.dart';
import '../models/unit_model.dart';
import '../models/deal_model.dart';
import '../models/payment_record_model.dart';
import '../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/export_service.dart';
import '../services/smart_notification_service.dart';
import '../core/rent_engine.dart';
import '../core/facility_icon_helper.dart';

class RenterDetailScreen extends StatefulWidget {
  final UnitModel unit;
  final DealModel deal;

  const RenterDetailScreen({super.key, required this.unit, required this.deal});

  @override
  State<RenterDetailScreen> createState() => _RenterDetailScreenState();
}

class _RenterDetailScreenState extends State<RenterDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestore = FirestoreService();

  // Live deal state — updated by Firestore stream so advance top-ups, amenity
  // changes, and other mutations are reflected instantly.
  late DealModel _liveDeal;
  StreamSubscription<DealModel?>? _dealSub;

  late TextEditingController _advanceAmountController;
  late TextEditingController _agreementDriveLinkController;

  late bool _advanceConsumptionMode;
  late bool _carryForward;
  late String _agreementType;
  String? _agreementBase64;
  bool _isTermsUnlocked = false;
  bool _showRenterPassword = false;
  bool _authRepairAttempted = false;

  // Rent Schedule List for v2.0
  late List<RentScheduleItem> _rentSchedule;
  String? _advanceDeductStartMonth;
  String? _advanceDeductEndMonth;
  bool _useCustomDeductionRange = false;

  List<String> get _availableMonths {
    final start = _liveDeal.dealStartDate;
    final months = <String>[];
    final baseYear = start.year - 1;
    for (int y = baseYear; y <= baseYear + 4; y++) {
      for (int m = 1; m <= 12; m++) {
        months.add("$y-${m.toString().padLeft(2, '0')}");
      }
    }
    return months;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _liveDeal = widget.deal;
    _firestore.checkAndLazyGenerateMonthRecord(_liveDeal);

    // Subscribe to live deal updates from Firestore
    _dealSub = _firestore.streamDealById(widget.deal.id).listen((updatedDeal) {
      if (updatedDeal != null && mounted) {
        setState(() {
          _liveDeal = updatedDeal;
        });
      }
    });

    _rentSchedule = List<RentScheduleItem>.from(_liveDeal.rentSchedule);
    if (_rentSchedule.isEmpty) {
      _rentSchedule.add(RentScheduleItem(effectiveFromDate: _liveDeal.dealStartDate, monthlyRent: _liveDeal.baseMonthlyRent));
    }

    _advanceAmountController = TextEditingController(text: _liveDeal.advanceAmount.toStringAsFixed(0));
    _agreementDriveLinkController = TextEditingController(text: _liveDeal.agreementDriveLink ?? '');

    _advanceConsumptionMode = _liveDeal.advanceConsumptionMode;
    _advanceDeductStartMonth = _liveDeal.advanceDeductStartMonth;
    _advanceDeductEndMonth = _liveDeal.advanceDeductEndMonth;
    _useCustomDeductionRange = (_advanceDeductStartMonth != null && _advanceDeductStartMonth!.trim().isNotEmpty) ||
        (_advanceDeductEndMonth != null && _advanceDeductEndMonth!.trim().isNotEmpty);
    _carryForward = _liveDeal.carryForwardPendingBalance;
    _agreementType = _liveDeal.agreementType;
    _agreementBase64 = _liveDeal.agreementFileBase64;
  }

  @override
  void dispose() {
    _dealSub?.cancel();
    _tabController.dispose();
    _advanceAmountController.dispose();
    _agreementDriveLinkController.dispose();
    super.dispose();
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

  Future<void> _handleUnlockTermsWithPin() async {
    final pinController = TextEditingController();
    bool obscure = true;

    final verified = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.lock_person_outlined, color: AppTheme.goldAccent, size: 28),
                SizedBox(width: 10),
                Text('Security PIN Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deal terms contain sensitive financial and legal data.\nPlease enter your 6-digit Security PIN to unlock editing.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: obscure,
                  maxLength: 6,
                  autofocus: true,
                  style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '••••••',
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDlgState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalization.tr('cancel')),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.key),
                label: const Text('Verify & Unlock'),
                onPressed: () async {
                  final enteredPin = pinController.text.trim();
                  if (enteredPin.length != 6) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please enter your full 6-digit PIN.')),
                    );
                    return;
                  }

                  final isOk = await LocalSecurity.verifyPin(enteredPin);
                  if (isOk) {
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } else {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Incorrect Security PIN. Access denied.')),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );

    if (verified == true && mounted) {
      setState(() {
        _isTermsUnlocked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.statusGreen,
          content: Text('Deal Terms unlocked for editing!'),
        ),
      );
    }
  }

  void _addRentScheduleStep() {
    final lastDate = _rentSchedule.isNotEmpty ? _rentSchedule.last.effectiveFromDate : _liveDeal.dealStartDate;
    final lastRent = _rentSchedule.isNotEmpty ? _rentSchedule.last.monthlyRent : 8000.0;

    DateTime selectedDate = DateTime(lastDate.year + 1, lastDate.month, 1);
    final rentCtrl = TextEditingController(text: (lastRent + 2000).toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add Rent Change Step'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: _liveDeal.dealStartDate,
                    lastDate: DateTime(2050),
                  );
                  if (picked != null) {
                    setDlgState(() => selectedDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Effective From Date'),
                  child: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rentCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'New Monthly Rent (INR)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final r = double.tryParse(rentCtrl.text.trim()) ?? 10000.0;
                setState(() {
                  _rentSchedule.add(RentScheduleItem(effectiveFromDate: selectedDate, monthlyRent: r));
                  _rentSchedule.sort((a, b) => a.effectiveFromDate.compareTo(b.effectiveFromDate));
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add Step'),
            )
          ],
        ),
      ),
    );
  }

  // Section 1: Transfer Unit Dialog
  void _showTransferUnitDialog() async {
    if (!_isTermsUnlocked) {
      await _handleUnlockTermsWithPin();
      if (!_isTermsUnlocked) return;
    }

    final unitsSnap = await _firestore.streamUnits(_liveDeal.propertyId).first;
    final isDealComm = _liveDeal.renterType == 'commercial';
    final vacantUnits = unitsSnap.where((u) => u.status == 'vacant' && u.isCommercial == isDealComm).toList();

    if (!mounted) return;
    if (vacantUnits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vacant units available in this property to transfer into.')),
      );
      return;
    }

    String selectedUnitId = vacantUnits.first.id;
    DateTime transferDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Transfer Deal to New Unit'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Unit: Unit ${_liveDeal.currentUnitId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Select Target Vacant Unit:'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedUnitId,
                    items: vacantUnits.map((u) {
                      return DropdownMenuItem(value: u.id, child: Text('Unit ${u.label} (${u.type.toUpperCase()})'));
                    }).toList(),
                    onChanged: (val) => setDlgState(() => selectedUnitId = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton.icon(
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Confirm Transfer'),
                  onPressed: () async {
                    await _firestore.transferUnit(
                      deal: _liveDeal,
                      newUnitId: selectedUnitId,
                      transferDate: transferDate,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Unit transfer completed successfully!')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Section 1B: Add Additional Rented Unit Dialog (Business Expansion)
  void _showAddUnitDialog() async {
    if (!_isTermsUnlocked) {
      await _handleUnlockTermsWithPin();
      if (!_isTermsUnlocked) return;
    }

    final unitsSnap = await _firestore.streamUnits(_liveDeal.propertyId).first;
    final isDealComm = _liveDeal.renterType == 'commercial';
    final vacantUnits = unitsSnap.where((u) => u.status == 'vacant' && u.isCommercial == isDealComm).toList();

    if (!mounted) return;
    if (vacantUnits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vacant units available in this property to add.')),
      );
      return;
    }

    UnitModel selectedUnit = vacantUnits.first;
    final extraRentCtrl = TextEditingController(text: '0');
    final extraAdvanceCtrl = TextEditingController(text: '0');
    DateTime effectiveDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Add Additional Rented Unit'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Rented Units: ${_liveDeal.displayMultiUnitLabel}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const Text('Select Vacant Unit to Add:'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<UnitModel>(
                      initialValue: selectedUnit,
                      items: vacantUnits.map((u) {
                        return DropdownMenuItem(value: u, child: Text('Unit ${u.label} (${u.type.toUpperCase()})'));
                      }).toList(),
                      onChanged: (val) => setDlgState(() => selectedUnit = val!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: extraRentCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Additional Monthly Rent for this Unit (INR) *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: extraAdvanceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Additional Advance Security Deposit (INR) *'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_home_work),
                  label: const Text('Add Unit to Deal'),
                  onPressed: () async {
                    final extraRent = double.tryParse(extraRentCtrl.text.trim()) ?? 0.0;
                    final extraAdvance = double.tryParse(extraAdvanceCtrl.text.trim()) ?? 0.0;
                    await _firestore.addUnitToDeal(
                      deal: _liveDeal,
                      newUnit: selectedUnit,
                      effectiveDate: effectiveDate,
                      additionalRent: extraRent,
                      additionalAdvance: extraAdvance,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Unit ${selectedUnit.label} added to deal successfully!')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Section 1C: Vacate / Remove Unit from Deal Dialog
  void _showVacateUnitDialog() async {
    if (!_isTermsUnlocked) {
      await _handleUnlockTermsWithPin();
      if (!mounted) return;
      if (!_isTermsUnlocked) return;
    }

    final activeLabels = _liveDeal.assignedUnitLabels.isNotEmpty
        ? _liveDeal.assignedUnitLabels
        : [_liveDeal.unitLabel ?? _liveDeal.currentUnitId];

    if (activeLabels.isEmpty) return;

    String selectedUnitLabel = activeLabels.first;
    final newRentCtrl = TextEditingController(text: _liveDeal.baseMonthlyRent.toStringAsFixed(0));
    DateTime vacateDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Vacate / Remove Rented Unit'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Rented Unit to Vacate:'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedUnitLabel,
                      items: activeLabels.map((l) {
                        return DropdownMenuItem(value: l, child: Text('Unit $l'));
                      }).toList(),
                      onChanged: (val) => setDlgState(() => selectedUnitLabel = val!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newRentCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'New Total Monthly Rent after Vacate (INR) *',
                        helperText: 'Reduced rent for remaining unit(s)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRed, foregroundColor: Colors.white),
                  icon: const Icon(Icons.domain_disabled, size: 18),
                  label: const Text('Vacate Unit'),
                  onPressed: () async {
                    final newRent = double.tryParse(newRentCtrl.text.trim()) ?? 0.0;
                    await _firestore.vacateUnitFromDeal(
                      deal: _liveDeal,
                      vacateUnitId: selectedUnitLabel,
                      vacateUnitLabel: selectedUnitLabel,
                      vacateDate: vacateDate,
                      newTotalRent: newRent,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Unit $selectedUnitLabel has been vacated from this deal.')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Section 2: Add Advance Deposit Top-up Dialog
  void _showAddAdvanceDialog() async {
    if (!_isTermsUnlocked) {
      await _handleUnlockTermsWithPin();
      if (!mounted) return;
      if (!_isTermsUnlocked) return;
    }
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add Advance Deposit Top-Up'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setDlgState(() {
                      selectedDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryNavy),
                          const SizedBox(width: 8),
                          Text(
                            'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                      const Text('Change', style: TextStyle(color: AppTheme.primaryNavy, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Advance Amount (INR) *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Reason / Note / Payment Reference (Optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_card),
              label: const Text('Add Advance'),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;

                await _firestore.addAdvanceTransaction(
                  deal: _liveDeal,
                  amount: amount,
                  note: noteCtrl.text.trim(),
                  date: selectedDate,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Advance deposit top-up added successfully!')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Section 3: End Deal Dialog with Advance Deposit Settlement & Checklist
  void _showEndDealDialog() async {
    if (!_isTermsUnlocked) {
      await _handleUnlockTermsWithPin();
      if (!mounted) return;
      if (!_isTermsUnlocked) return;
    }

    final refundCtrl = TextEditingController(text: _liveDeal.totalAdvanceAmount.toStringAsFixed(0));
    final noteCtrl = TextEditingController(
      text: 'Full advance deposit of ₹${_liveDeal.totalAdvanceAmount.toStringAsFixed(0)} returned via Cash/UPI on deal closing',
    );

    bool rentsCleared = true;
    bool advanceSettled = false;
    bool unitVacated = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isReadyToEnd = rentsCleared && advanceSettled && unitVacated;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.do_not_disturb_on_outlined, color: AppTheme.statusRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'End Lease Deal: ${_liveDeal.displayMultiUnitLabel}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'To terminate this deal, confirm all 3 settlement steps below. Unit will be marked vacant.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),

                  // 1. Advance Summary & Refund Control
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Security Deposit Received:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(
                          '₹${_liveDeal.totalAdvanceAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: refundCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Returned Advance Amount (INR) *',
                      helperText: 'Amount refunded or returned to renter',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Refund Note / Settlement Details *',
                      helperText: 'Mode of payment (Cash, UPI, Cheque, etc.)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(),

                  // 2. Settlement Checkboxes
                  const Text('Required Admin Confirmations:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy)),
                  const SizedBox(height: 4),

                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('1. All monthly rents collected / settled', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    subtitle: const Text('No pending rent dues remain for this unit', style: TextStyle(fontSize: 10)),
                    value: rentsCleared,
                    onChanged: (val) => setDlgState(() => rentsCleared = val ?? false),
                  ),

                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('2. Advance deposit refunded / settled', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Security advance has been returned or adjusted', style: TextStyle(fontSize: 10)),
                    value: advanceSettled,
                    onChanged: (val) => setDlgState(() => advanceSettled = val ?? false),
                  ),

                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('3. Renter has vacated unit & returned keys', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    subtitle: Text('Unit ${_liveDeal.displayMultiUnitLabel} is empty & ready for next tenant', style: const TextStyle(fontSize: 10)),
                    value: unitVacated,
                    onChanged: (val) => setDlgState(() => unitVacated = val ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReadyToEnd ? AppTheme.statusRed : Colors.grey,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirm End Deal & Vacate Unit'),
                onPressed: isReadyToEnd
                    ? () async {
                        final refundAmount = double.tryParse(refundCtrl.text.trim()) ?? _liveDeal.totalAdvanceAmount;
                        final refundNote = noteCtrl.text.trim();
                        await _firestore.endDeal(_liveDeal, refundAmount: refundAmount, refundNote: refundNote);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Lease deal closed successfully! Unit is now vacant.')),
                          );
                        }
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      }
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  // Section 3B: Safe Delete Test Deal (v2.3)
  Future<void> _showDeleteDealDialog() async {
    final canDel = await _firestore.canDeleteDeal(_liveDeal.id);
    if (!mounted) return;
    if (!canDel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This deal has payment history — cannot be deleted. Only "End Deal" is offered.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Test Deal'),
        content: const Text('This will permanently remove this test entry — continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.deleteDeal(_liveDeal.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test deal deleted permanently.')),
        );
      }
    }
  }

  // Section 3C: Safe Delete Test Renter Account (v2.3)
  Future<void> _handleDeleteRenterAccount(UserModel renterUser) async {
    final canDel = await _firestore.canDeleteRenter(renterUser.renterId);
    if (!mounted) return;
    if (!canDel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This renter has deal history — nothing to delete')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Renter Account'),
        content: const Text('This will permanently remove this test entry — continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.deleteRenterAccount(renterUser.renterId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test renter account deleted successfully.')),
        );
      }
    }
  }

  // Section 4: Add Amenity / Facility Dialog
  void _showAddAmenityDialog() async {
    if (!_isTermsUnlocked) {
      await _handleUnlockTermsWithPin();
      if (!mounted) return;
      if (!_isTermsUnlocked) return;
    }

    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String inclusionType = 'Included Free in Rent';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.star_rounded, color: AppTheme.goldAccent, size: 26),
                  SizedBox(width: 8),
                  Text('Add Facility or Service', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select a preset facility or enter custom service details for this unit.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.3),
                    ),
                    const SizedBox(height: 14),
                    const Text('Tap to Choose Preset:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: FacilityIconHelper.presets.map((preset) {
                        final isSelected = nameCtrl.text == preset.name;
                        return ChoiceChip(
                          avatar: Icon(preset.icon, size: 18, color: isSelected ? Colors.white : preset.color),
                          label: Text(
                            preset.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.primaryNavy,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: preset.color,
                          backgroundColor: preset.color.withAlpha(20),
                          onSelected: (_) {
                            setDlgState(() {
                              nameCtrl.text = preset.name;
                              if (noteCtrl.text.isEmpty) {
                                noteCtrl.text = preset.defaultNote;
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Facility / Service Name *',
                        hintText: 'e.g. Mess Food Plan, Parking Slot #4',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: inclusionType,
                      decoration: const InputDecoration(
                        labelText: 'Inclusion / Charge Condition',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Included Free in Rent', child: Text('Included Free in Rent')),
                        DropdownMenuItem(value: 'Fixed Monthly Extra Fee', child: Text('Fixed Monthly Extra Fee')),
                        DropdownMenuItem(value: 'Sub-metered / Usage Based', child: Text('Sub-metered / Usage Based')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() => inclusionType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Details / Remark / Terms (Optional)',
                        hintText: 'e.g. 3 meals daily Mon-Sat OR ₹500/month',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalization.tr('cancel')),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Save Facility'),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;

                    final fullNote = noteCtrl.text.trim().isNotEmpty
                        ? '[$inclusionType] ${noteCtrl.text.trim()}'
                        : '[$inclusionType]';

                    await _firestore.addAmenity(
                      deal: _liveDeal,
                      name: name,
                      note: fullNote,
                    );

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Facility "$name" saved to deal!')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAndSaveDealTerms() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalization.tr('confirm_action')),
        content: Text(AppLocalization.tr('confirm_save_deal')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalization.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalization.tr('yes')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final autoDueDay = (_rentSchedule.isNotEmpty ? _rentSchedule.first.effectiveFromDate.day : _liveDeal.dealStartDate.day).clamp(1, 28);

    final updatedDeal = DealModel(
      id: _liveDeal.id,
      propertyId: _liveDeal.propertyId,
      currentUnitId: _liveDeal.currentUnitId,
      renterId: _liveDeal.renterId,
      renterType: _liveDeal.renterType,
      dealStartDate: _liveDeal.dealStartDate,
      rentSchedule: _rentSchedule,
      rentDueDayOfMonth: autoDueDay,
      advanceTransactions: _liveDeal.advanceTransactions,
      advanceConsumptionMode: _advanceConsumptionMode,
      advanceDeductStartMonth: _advanceConsumptionMode && _useCustomDeductionRange ? _advanceDeductStartMonth : null,
      advanceDeductEndMonth: _advanceConsumptionMode && _useCustomDeductionRange ? _advanceDeductEndMonth : null,
      unitHistory: _liveDeal.unitHistory,
      amenities: _liveDeal.amenities,
      carryForwardPendingBalance: _carryForward,
      agreementType: _agreementType,
      agreementFileBase64: _agreementBase64,
      agreementDriveLink: _agreementDriveLinkController.text.trim().isNotEmpty ? _agreementDriveLinkController.text.trim() : null,
      status: _liveDeal.status,
      notes: _liveDeal.notes,
      createdAt: _liveDeal.createdAt,
      updatedAt: DateTime.now(),
      businessName: _liveDeal.businessName,
      businessCategory: _liveDeal.businessCategory,
      occupantCount: _liveDeal.occupantCount,
      maintenanceIncluded: _liveDeal.maintenanceIncluded,
      unitLabel: _liveDeal.unitLabel,
      unitCode: _liveDeal.unitCode,
      assignedUnitIds: _liveDeal.assignedUnitIds,
      assignedUnitLabels: _liveDeal.assignedUnitLabels,
      advanceRefundAmount: _liveDeal.advanceRefundAmount,
      advanceRefundDate: _liveDeal.advanceRefundDate,
      advanceRefundNote: _liveDeal.advanceRefundNote,
    );

    await _firestore.updateDeal(updatedDeal);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deal terms updated successfully!')),
      );
    }
  }

  // Past Rent & Onboarding Fast-Settle Dialog
  void _showPastRentSettleDialog(List<PaymentRecordModel> records) {
    String selectedCutoffPeriod = RentEngine.formatPeriodMonth(DateTime.now());
    if (records.isNotEmpty) {
      selectedCutoffPeriod = records.first.periodMonth;
    }

    bool advanceMode = _liveDeal.advanceConsumptionMode;
    final advanceTopUpController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final targetIndex = records.indexWhere((r) => r.periodMonth == selectedCutoffPeriod);
            final cutoffIndex = targetIndex != -1 ? targetIndex + 1 : records.length;

            double pendingShortfall = 0.0;
            for (int i = 0; i < cutoffIndex && i < records.length; i++) {
              if (records[i].paymentSource == 'direct') {
                pendingShortfall += records[i].amountPending;
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.bolt, color: AppTheme.primaryTeal, size: 26),
                  SizedBox(width: 8),
                  Text('Onboarding & Past Rent Tools', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manage past rents at once for long-standing renters whose deal started before today.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('1. Settle Past Direct Rent as PAID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 6),
                          const Text('Select period month up to which all past rent is paid:'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: selectedCutoffPeriod,
                            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            items: records.map((r) => DropdownMenuItem(
                              value: r.periodMonth,
                              child: Text('${r.periodMonth} (Month ${r.monthIndex})'),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) setDlgState(() => selectedCutoffPeriod = val);
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Shortfall to Settle:', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text('₹${pendingShortfall.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.statusGreen, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusGreen),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Mark Past Rents Paid'),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final ownerUid = FirebaseAuth.instance.currentUser?.uid ?? 'owner';
                                Navigator.pop(ctx);
                                await _firestore.settlePastRentsToDate(
                                  deal: _liveDeal,
                                  targetPeriodMonth: selectedCutoffPeriod,
                                  ownerUid: ownerUid,
                                );
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('All past rents up to $selectedCutoffPeriod settled as PAID!')),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('2. Deduct Past Rents from Advance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 6),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Deduct monthly rent from Advance balance'),
                            value: advanceMode,
                            onChanged: (val) => setDlgState(() => advanceMode = val),
                          ),
                          const SizedBox(height: 6),
                          const Text('Top-up Advance Deposit (Optional INR):'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: advanceTopUpController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: 'e.g. 50000', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
                              icon: const Icon(Icons.account_balance_wallet),
                              label: const Text('Save Advance Rules & Rebalance'),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final topUp = double.tryParse(advanceTopUpController.text.trim());
                                Navigator.pop(ctx);
                                await _firestore.updateAdvanceConsumptionRules(
                                  deal: _liveDeal,
                                  enableAdvanceConsumption: advanceMode,
                                  addAdvanceAmount: topUp,
                                );
                                if (mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Advance consumption rules updated & ledger rebalanced!')),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalization.tr('cancel')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Priority Notification Sender Dialog
  Future<void> _showSendNotificationDialog(UserModel renterUser, DealModel deal) async {
    bool isCurrentMonthPaidOrSettled = false;
    bool isAdvanceCovered = false;
    final periodMonth = RentEngine.formatPeriodMonth(DateTime.now());

    try {
      final allRecs = await _firestore.streamPaymentRecords(deal.propertyId).first;
      final dealRecs = allRecs.where((r) => r.dealId == deal.id).toList();
      final rebalanced = RentEngine.rebalanceLedgerRecords(dealRecs, deal);
      for (var r in rebalanced) {
        if (r.periodMonth == periodMonth) {
          isAdvanceCovered = r.paymentSource == 'advance' || r.status == 'adjusted-against-advance';
          isCurrentMonthPaidOrSettled = isAdvanceCovered ||
              r.amountPending <= 0 ||
              r.status == 'paid' ||
              r.status == 'submitted' ||
              r.status == 'confirmed-paid' ||
              r.status == 'pending-confirmation';
          break;
        }
      }
    } catch (_) {}

    if (!mounted) return;

    String selectedPreset = isCurrentMonthPaidOrSettled ? 'gentle' : 'overdue';
    final titleCtrl = TextEditingController(text: isCurrentMonthPaidOrSettled ? "Rent Cycle Started" : "Rent Overdue");
    final msgCtrl = TextEditingController(
      text: isCurrentMonthPaidOrSettled
          ? (isAdvanceCovered
              ? "Rent for ${widget.unit.label} (₹${deal.startingRent.toInt()}) covered from advance balance."
              : "Rent for ${widget.unit.label} (₹${deal.startingRent.toInt()}) has been fully paid & settled.")
          : "Rent for ${widget.unit.label} (₹${deal.startingRent.toInt()}) is unpaid by 5+ days. Please clear dues.",
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications_active, color: AppTheme.primaryNavy),
              SizedBox(width: 8),
              Text('Send Priority Notification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recipient: ${renterUser.name} (${widget.unit.label})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (isCurrentMonthPaidOrSettled) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        isAdvanceCovered ? 'Rent covered by advance for $periodMonth' : 'Rent fully settled for $periodMonth',
                        style: TextStyle(color: Colors.green.shade900, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedPreset,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Notification Type & Priority', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                    value: 'gentle',
                    child: Text('Gentle Rent Start (Priority: Gentle)'),
                  ),
                  DropdownMenuItem(
                    value: 'overdue',
                    child: Text('5-7 Days Overdue Warning (Priority: Warning)'),
                  ),
                  DropdownMenuItem(
                    value: 'urgent',
                    child: Text('Urgent Dues Notice (Priority: Urgent)'),
                  ),
                  DropdownMenuItem(
                    value: 'info',
                    child: Text('Property Notice (Priority: Info)'),
                  ),
                ],
                onChanged: (val) {
                  setDlgState(() {
                    selectedPreset = val!;
                    if (val == 'gentle') {
                      titleCtrl.text = "Rent Cycle Started";
                      msgCtrl.text = isCurrentMonthPaidOrSettled
                          ? (isAdvanceCovered
                              ? "Rent for ${widget.unit.label} (₹${deal.startingRent.toInt()}) covered from advance balance."
                              : "Rent for ${widget.unit.label} (₹${deal.startingRent.toInt()}) has been fully paid & settled.")
                          : "Rent for ${widget.unit.label} (₹${deal.startingRent.toInt()}) is due.";
                    } else if (val == 'overdue') {
                      titleCtrl.text = "Rent Overdue";
                      msgCtrl.text = "Rent for ${widget.unit.label} (₹${deal.startingRent.toInt()}) is unpaid by 5+ days. Please clear dues.";
                    } else if (val == 'urgent') {
                      titleCtrl.text = "Urgent Rent Settlement";
                      msgCtrl.text = "Please settle outstanding rent dues for ${widget.unit.label} immediately.";
                    } else {
                      titleCtrl.text = "Property Notice";
                      msgCtrl.text = "Notice for ${widget.unit.label}: Please check your app dashboard for updates.";
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Notification Title *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: msgCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message Body *', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
              onPressed: () async {
                Navigator.pop(ctx);
                final priority = selectedPreset == 'gentle'
                    ? 'gentle'
                    : (selectedPreset == 'overdue' ? 'warning' : (selectedPreset == 'urgent' ? 'urgent' : 'info'));
                final type = selectedPreset == 'gentle'
                    ? 'rent-cycle-start'
                    : (selectedPreset == 'overdue' ? 'rent-overdue-warning' : 'notice');

                await SmartNotificationService().sendPriorityNotificationToRenter(
                  toUid: renterUser.uid,
                  propertyId: deal.propertyId,
                  title: titleCtrl.text.trim(),
                  message: msgCtrl.text.trim(),
                  priority: priority,
                  type: type,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Priority notification sent to tenant phone & app!'),
                      backgroundColor: AppTheme.statusGreen,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.send),
              label: const Text('Send Alert'),
            ),
          ],
        ),
      ),
    );
  }

  // Reset Renter Login Dialog (Section 8.5)
  Future<void> _handleResetRenterLogin(UserModel oldUser) async {
    final passwordCtrl = TextEditingController(text: '123456');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Renter Login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tenant: ${oldUser.name} (${oldUser.phone})'),
            const SizedBox(height: 10),
            const Text(
              'Issuing a new login creates a fresh password while preserving 100% of their payment history and deal records.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passwordCtrl,
              decoration: const InputDecoration(labelText: 'New Account Password *'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate New Login')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final credentials = await _firestore.resetRenterLogin(
        oldUserDoc: oldUser,
        newPassword: passwordCtrl.text.trim(),
      );

      final phone = credentials['phone']!;
      final newPass = credentials['password']!;
      final textToShare = "Hello ${oldUser.name}, your ${BrandConfig.brandName} LeaseSync login credentials have been reset:\nPhone: $phone\nPassword: $newPass";

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.key, color: AppTheme.goldAccent),
                SizedBox(width: 8),
                Text('New Credentials Issued'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  'Phone Number: $phone\n'
                  'New Password: $newPass',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.6),
                ),
                const SizedBox(height: 14),
                const Text('Tap below to copy or send credentials directly on WhatsApp.'),
              ],
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy Credentials'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: textToShare));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard!')),
                  );
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusGreen),
                icon: const Icon(Icons.chat),
                label: const Text('Send on WhatsApp'),
                onPressed: () async {
                  final clean = phone.replaceAll(RegExp(r'\D'), '');
                  final Uri url = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(textToShare)}');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset login: $e')),
        );
      }
    }
  }

  Future<void> _handleCreateRenterAccount(DealModel deal) async {
    final nameCtrl = TextEditingController(text: deal.businessName ?? 'Tenant');
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: '123456');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1, color: AppTheme.primaryNavy),
            SizedBox(width: 8),
            Text('Create Tenant Login Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a login account for this tenant so they can access the ${BrandConfig.brandName} Tenant App.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Tenant / Business Name *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Number (Login ID) *', border: OutlineInputBorder(), prefixText: '+91 '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: 'Login Password *', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create Account'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;
    final phone = phoneCtrl.text.trim();
    final name = nameCtrl.text.trim();
    final password = passCtrl.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number and password are required.')),
      );
      return;
    }

    try {
      final currentOwnerUid = FirebaseAuth.instance.currentUser?.uid ?? 'owner';
      final cred = await SecondaryAuthService.createOrUpdateRenterAccount(
        phone: phone,
        password: password,
      );
      final authUid = cred.user!.uid;
      final renterIdToUse = deal.renterId.isNotEmpty ? deal.renterId : authUid;

      final newUser = UserModel(
        uid: authUid,
        renterId: renterIdToUse,
        role: 'renter',
        name: name,
        phone: phone,
        pseudoEmail: PhoneUtils.toPseudoEmail(phone),
        renterPassword: password,
        propertyIds: [deal.propertyId],
        active: true,
        createdAt: DateTime.now(),
        createdBy: currentOwnerUid,
      );

      await _firestore.saveUser(newUser);
      await _firestore.cleanupDuplicateUsers(phone);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login account created for $name ($phone)!')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create login account: $e')),
        );
      }
    }
  }

  Future<void> _makeCall(String phone) async {
    final clean = PhoneUtils.sanitizeTenDigitPhone(phone);
    final Uri url = Uri.parse('tel:$clean');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _openWhatsApp(String phone, [String? text]) async {
    final clean = PhoneUtils.sanitizeTenDigitPhone(phone);
    final textParam = text != null ? Uri.encodeComponent(text) : '';
    final Uri url = Uri.parse('https://wa.me/91$clean${textParam.isNotEmpty ? "?text=$textParam" : ""}');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<UserModel?>(
          stream: _firestore.streamRenterUser(_liveDeal.renterId),
          builder: (context, userSnap) {
            final name = userSnap.data?.name ?? '';
            final unitTitle = _liveDeal.displayMultiUnitLabel.isNotEmpty ? _liveDeal.displayMultiUnitLabel : widget.unit.label;
            return Text(
              name.isNotEmpty ? '$unitTitle • $name' : unitTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            );
          },
        ),
        actions: [
          StreamBuilder<UserModel?>(
            stream: _firestore.streamRenterUser(_liveDeal.renterId),
            builder: (context, userSnap) {
              final phone = userSnap.data?.phone ?? '';
              if (phone.isEmpty) return const SizedBox.shrink();
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.phone),
                    onPressed: () => _makeCall(phone),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () => _openWhatsApp(phone),
                  ),
                ],
              );
            },
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Container(
            color: const Color(0xFF0F2942), // High contrast dark navy
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.goldAccent,
              indicatorWeight: 4.0,
              labelColor: AppTheme.goldAccent,
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(
                  icon: Icon(Icons.description_rounded, size: 22),
                  text: 'Deal Terms',
                ),
                Tab(
                  icon: Icon(Icons.assessment_rounded, size: 22),
                  text: 'Ledger',
                ),
                Tab(
                  icon: Icon(Icons.picture_as_pdf_rounded, size: 22),
                  text: 'Agreement',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDealTermsTab(),
          _buildLedgerTab(),
          _buildAgreementTab(),
        ],
      ),
    );
  }

  Widget _buildDealTermsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.primaryNavy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unit ${_liveDeal.displayMultiUnitLabel.isNotEmpty ? _liveDeal.displayMultiUnitLabel : widget.unit.label}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${BrandConfig.brandName} • Lease Agreement Terms',
                        style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(200)),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: BrandConfig.buildLogoWidget(
                    defaultAsset: 'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),

          // Security Status & Lock Control Banner
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isTermsUnlocked ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isTermsUnlocked ? AppTheme.statusGreen : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            _isTermsUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                            color: _isTermsUnlocked ? AppTheme.statusGreen : AppTheme.primaryNavy,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isTermsUnlocked ? 'Deal Terms Unlocked for Editing' : 'Deal Terms Locked • View Mode',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _isTermsUnlocked ? AppTheme.statusGreen : AppTheme.primaryNavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isTermsUnlocked) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: AppTheme.goldAccent,
                          minimumSize: const Size(90, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _handleUnlockTermsWithPin,
                        icon: const Icon(Icons.key, size: 16),
                        label: const Text('Unlock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isTermsUnlocked
                      ? 'You can now modify rent schedule, advance deposit, and attach agreement docs.'
                      : 'Sensitive financial terms are protected. Tap unlock button to edit after 6-digit PIN.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),

          // Renter Account & Reset Login Card (Section 8.5)
          StreamBuilder<UserModel?>(
            stream: _firestore.streamRenterUser(_liveDeal.renterId),
            builder: (context, userSnap) {
              final renterUser = userSnap.data;

              // Auto-repair: silently verify/create Auth account on first load
              // Catches ALL cases — phantom UIDs, missing Auth accounts, password mismatches
              if (renterUser != null && !_authRepairAttempted) {
                _authRepairAttempted = true;
                // Fire-and-forget repair — the StreamBuilder will auto-update when Firestore changes
                _firestore.verifyAndRepairRenterAuth(renterUser).then((_) {
                  if (mounted) setState(() {});
                }).catchError((_) {});
              }

              if (renterUser == null) {
                return Card(
                  color: const Color(0xFFFFFBEB),
                  margin: const EdgeInsets.only(bottom: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFFCD34D)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.vpn_key_outlined, color: Colors.orange, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Tenant App Login Credentials',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No active tenant login account linked for ${_liveDeal.businessName ?? "this deal"}.',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
                            icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 16),
                            label: const Text('Create Tenant Login Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: () => _handleCreateRenterAccount(_liveDeal),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final passText = renterUser.renterPassword ?? '123456';
              final shareText = "Hello ${renterUser.name},\nHere are your ${BrandConfig.brandName} App Login details:\nPhone / Login ID: ${renterUser.phone}\nPassword: $passText";

              return Card(
                color: const Color(0xFFF8FAFC),
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.vpn_key_outlined, color: AppTheme.primaryNavy, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Tenant Credentials',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _handleResetRenterLogin(renterUser),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh_rounded, size: 13, color: AppTheme.primaryNavy),
                                  SizedBox(width: 3),
                                  Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryNavy,
                              foregroundColor: AppTheme.goldAccent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showSendNotificationDialog(renterUser, _liveDeal),
                            icon: const Icon(Icons.notifications_active, size: 13),
                            label: const Text('Send Alert', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.phone_android, size: 18, color: AppTheme.primaryNavy),
                                const SizedBox(width: 8),
                                const Text('Login Phone ID: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                SelectableText(renterUser.phone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy)),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.lock_outline, size: 18, color: AppTheme.primaryNavy),
                                    const SizedBox(width: 8),
                                    const Text('App Password: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    SelectableText(
                                      _showRenterPassword ? passText : '••••••••',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy, letterSpacing: 1.0),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(_showRenterPassword ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.grey.shade700),
                                  onPressed: () => setState(() => _showRenterPassword = !_showRenterPassword),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy Credentials', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: shareText));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Copied login credentials to clipboard!')),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.chat, size: 16),
                              label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              onPressed: () => _openWhatsApp(renterUser.phone, shareText),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<bool>(
                        future: _firestore.canDeleteRenter(renterUser.renterId),
                        builder: (context, snap) {
                          final canDel = snap.data == true;
                          if (canDel) {
                            return Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                icon: const Icon(Icons.delete_outline, size: 16),
                                label: const Text('Delete Renter Account', style: TextStyle(fontSize: 12)),
                                onPressed: () => _handleDeleteRenterAccount(renterUser),
                              ),
                            );
                          }
                          return const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'This renter has deal history — nothing to delete',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          if (!_isTermsUnlocked) ...[
            // Read-Only Summary of Deal Terms
            _sectionTitle('Current Rent Schedule'),
            const SizedBox(height: 8),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rentSchedule.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final step = _rentSchedule[index];
                  final isFirst = index == 0;
                  final dateStr = '${step.effectiveFromDate.day}/${step.effectiveFromDate.month}/${step.effectiveFromDate.year}';
                  return ListTile(
                    title: Text(
                      isFirst
                          ? '$dateStr onward (Starting Rent)'
                          : '$dateStr onward',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    trailing: Text(
                      '₹${step.monthlyRent.toStringAsFixed(0)} / mo',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Financial Terms & Document Summary'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Builder(
                  builder: (context) {
                    final remainingAdvance = RentEngine.getRunningAdvanceBalance(_liveDeal, DateTime.now());
                    final totalDeposited = _liveDeal.totalAdvanceAmount;
                    final autoDeducted = (totalDeposited - remainingAdvance).clamp(0.0, totalDeposited);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _readOnlyRow(
                          'Rent Due Day',
                          'Every ${_liveDeal.rentDueDayOfMonth}${_getDaySuffix(_liveDeal.rentDueDayOfMonth)} of the month',
                        ),
                        const Divider(height: 20),
                        _readOnlyRow(
                          'Advance Deduction Policy',
                          _liveDeal.advanceConsumptionMode ? 'Auto-Deduct Monthly Rent' : 'Refundable Security Deposit Held',
                        ),
                        if (_liveDeal.advanceConsumptionMode && (_liveDeal.advanceDeductStartMonth != null || _liveDeal.advanceDeductEndMonth != null)) ...[
                          const SizedBox(height: 6),
                          _readOnlyRow(
                            'Deduction Window',
                            '${_liveDeal.advanceDeductStartMonth ?? "Start"} to ${_liveDeal.advanceDeductEndMonth ?? "Ongoing"}',
                          ),
                        ],
                        const Divider(height: 20),
                        _readOnlyRow('Total Advance Deposited', '₹${totalDeposited.toStringAsFixed(0)}'),
                        if (_liveDeal.advanceConsumptionMode) ...[
                          const SizedBox(height: 6),
                          _readOnlyRow('Auto-Deducted to Date', '₹${autoDeducted.toStringAsFixed(0)}'),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                flex: 5,
                                child: Text(
                                  'Live Remaining Advance',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: Text(
                                  '₹${remainingAdvance.toStringAsFixed(0)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.statusGreen),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_liveDeal.advanceTransactions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Advance Transactions Breakdown:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                          ),
                          const SizedBox(height: 6),
                          ..._liveDeal.advanceTransactions.asMap().entries.map((entry) {
                            final index = entry.key;
                            final tx = entry.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${tx.date.day}/${tx.date.month}/${tx.date.year}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                        ),
                                        Text(
                                          tx.note ?? "Advance Deposit Top-Up",
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${tx.amount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                                  ),
                                  if (_isTermsUnlocked) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Advance Top-Up'),
                                            content: Text('Remove top-up of ₹${tx.amount.toStringAsFixed(0)} dated ${tx.date.day}/${tx.date.month}/${tx.date.year}?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await _firestore.deleteAdvanceTransaction(deal: _liveDeal, index: index);
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                        if (_liveDeal.amenities.isNotEmpty) ...[
                          const Divider(height: 20),
                          const Text(
                            'Included Facilities & Additional Services:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                          ),
                          const SizedBox(height: 8),
                          ..._liveDeal.amenities.asMap().entries.map((entry) {
                            final index = entry.key;
                            final amen = entry.value;
                            final icon = FacilityIconHelper.getIcon(amen.name);
                            final color = FacilityIconHelper.getColor(amen.name);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Icon(icon, color: color, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(amen.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        if (amen.notes != null && amen.notes!.isNotEmpty)
                                          Text(amen.notes!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  if (_isTermsUnlocked)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Facility'),
                                            content: Text('Remove "${amen.name}" from this deal?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await _firestore.deleteAmenity(deal: _liveDeal, index: index);
                                        }
                                      },
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: AppTheme.goldAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: _handleUnlockTermsWithPin,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Unlock & Edit Deal Terms (PIN Required)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ] else ...[
            // Editable Form Fields (Unlocked Mode)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _sectionTitle(AppLocalization.tr('rent_schedule')),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: AppTheme.goldAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _addRentScheduleStep,
                  icon: const Icon(Icons.add_circle_outline, size: 14),
                  label: const Text(
                    '+ Add Step',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rentSchedule.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final step = _rentSchedule[index];
                  final isFirst = index == 0;
                  final dateStr = '${step.effectiveFromDate.day}/${step.effectiveFromDate.month}/${step.effectiveFromDate.year}';
                  return ListTile(
                    title: Text(
                      isFirst
                          ? '$dateStr onward (Starting Rent)'
                          : '$dateStr onward',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${step.monthlyRent.toStringAsFixed(0)} / mo',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                        ),
                        if (!isFirst)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.statusRed, size: 20),
                            onPressed: () {
                              setState(() => _rentSchedule.removeAt(index));
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),
            _sectionTitle(AppLocalization.tr('rent_due_day')),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final startDay = (_rentSchedule.isNotEmpty ? _rentSchedule.first.effectiveFromDate.day : _liveDeal.dealStartDate.day).clamp(1, 28);
                final startDateObj = _rentSchedule.isNotEmpty ? _rentSchedule.first.effectiveFromDate : _liveDeal.dealStartDate;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withAlpha(12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryNavy.withAlpha(35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_repeat_rounded, color: AppTheme.primaryNavy, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rent Due on the $startDay${_getDaySuffix(startDay)} of Every Month',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Auto-derived from Deal Start Date (${startDateObj.day}/${startDateObj.month}/${startDateObj.year})',
                              style: TextStyle(fontSize: 12.5, color: Colors.grey[700], fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.goldAccent.withAlpha(45),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.goldAccent),
                        ),
                        child: const Text(
                          'FIXED',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            _sectionTitle('Advance & Security Deposit'),
            const SizedBox(height: 8),
            TextField(
              controller: _advanceAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: AppLocalization.tr('advance_received')),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: Text(AppLocalization.tr('advance_mode')),
              subtitle: const Text('Auto-deducts monthly rent from advance balance (v2.2)'),
              value: _advanceConsumptionMode,
              onChanged: (val) => setState(() => _advanceConsumptionMode = val),
            ),
            if (_advanceConsumptionMode) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deduction Month Range Control:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('All Months', style: TextStyle(fontSize: 12)),
                            selected: !_useCustomDeductionRange,
                            onSelected: (sel) {
                              if (sel) {
                                setState(() {
                                  _useCustomDeductionRange = false;
                                  _advanceDeductStartMonth = null;
                                  _advanceDeductEndMonth = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Specific Months Range', style: TextStyle(fontSize: 12)),
                            selected: _useCustomDeductionRange,
                            onSelected: (sel) {
                              if (sel) {
                                setState(() {
                                  _useCustomDeductionRange = true;
                                  _advanceDeductStartMonth ??= RentEngine.formatPeriodMonth(_liveDeal.dealStartDate);
                                  _advanceDeductEndMonth ??= RentEngine.formatPeriodMonth(DateTime.now());
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_useCustomDeductionRange) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _availableMonths.contains(_advanceDeductStartMonth)
                                  ? _advanceDeductStartMonth
                                  : _availableMonths.first,
                              decoration: const InputDecoration(
                                labelText: 'From Month',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: _availableMonths
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13))))
                                  .toList(),
                              onChanged: (val) => setState(() => _advanceDeductStartMonth = val),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _availableMonths.contains(_advanceDeductEndMonth)
                                  ? _advanceDeductEndMonth
                                  : _availableMonths.last,
                              decoration: const InputDecoration(
                                labelText: 'To Month',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: _availableMonths
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13))))
                                  .toList(),
                              onChanged: (val) => setState(() => _advanceDeductEndMonth = val),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            _sectionTitle('Unpaid Balance Carry-Forward'),
            SwitchListTile(
              title: Text(AppLocalization.tr('carry_forward')),
              subtitle: const Text('Unpaid pending balance rolls into next month'),
              value: _carryForward,
              onChanged: (val) => setState(() => _carryForward = val),
            ),

            const SizedBox(height: 24),
            _sectionTitle('Agreement Document Attachment'),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _agreementType,
              onChanged: (val) => setState(() => _agreementType = val!),
              child: const Column(
                children: [
                  RadioListTile<String>(
                    title: Text('Upload Document Image / Camera Scan'),
                    value: 'upload',
                  ),
                  RadioListTile<String>(
                    title: Text('Google Drive Shared Document Link'),
                    value: 'drive-link',
                  ),
                ],
              ),
            ),

            if (_agreementType == 'upload') ...[
              const SizedBox(height: 12),
              if (_agreementBase64 != null && _agreementBase64!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.statusGreen, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 180,
                          width: double.infinity,
                          child: Image.memory(
                            base64Decode(_agreementBase64!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
                            onPressed: _pickAgreementPhoto,
                            icon: const Icon(Icons.photo_camera),
                            label: const Text('Replace Scan'),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.statusRed),
                            onPressed: () => setState(() => _agreementBase64 = null),
                            icon: const Icon(Icons.delete),
                            label: const Text('Remove'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: _pickAgreementPhoto,
                  child: Container(
                    height: 140,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppTheme.primaryNavy.withAlpha(80), width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: AppTheme.primaryNavy, size: 36),
                        SizedBox(height: 8),
                        Text(
                          'Tap to Pick Agreement Photo Scan / Gallery',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                        ),
                        SizedBox(height: 4),
                        Text('Supports JPEG/PNG photos (Base64)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ],

            if (_agreementType == 'drive-link')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _agreementDriveLinkController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Google Drive Document Link',
                    hintText: 'https://drive.google.com/file/d/...',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
              ),

            const SizedBox(height: 24),
            // v2.2 Advanced Deal Lifecycle Quick Action Bar
            Card(
              color: const Color(0xFFF1F5F9),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Deal Lifecycle & Property Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy, foregroundColor: Colors.white),
                          onPressed: _showTransferUnitDialog,
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: const Text('Transfer Unit'),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy, foregroundColor: AppTheme.goldAccent),
                          onPressed: _showAddUnitDialog,
                          icon: const Icon(Icons.add_home_work, size: 18),
                          label: const Text('Add Additional Unit'),
                        ),
                        if (_liveDeal.assignedUnitIds.length > 1 || _liveDeal.assignedUnitLabels.length > 1)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF991B1B), foregroundColor: Colors.white),
                            onPressed: _showVacateUnitDialog,
                            icon: const Icon(Icons.domain_disabled, size: 18),
                            label: const Text('Vacate / Remove Unit'),
                          ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
                          onPressed: _showAddAdvanceDialog,
                          icon: const Icon(Icons.add_card, size: 18),
                          label: const Text('Add Advance Top-Up'),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.goldAccent, foregroundColor: AppTheme.primaryNavy),
                          onPressed: _showAddAmenityDialog,
                          icon: const Icon(Icons.star_rounded, size: 18),
                          label: const Text('Add Facility / Extra Service'),
                        ),
                        FutureBuilder<bool>(
                          future: _firestore.canDeleteDeal(_liveDeal.id),
                          builder: (context, snap) {
                            final canDel = snap.data == true;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRed, foregroundColor: Colors.white),
                                  onPressed: _showEndDealDialog,
                                  icon: const Icon(Icons.cancel_outlined, size: 18),
                                  label: const Text('End This Deal'),
                                ),
                                if (canDel) ...[
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                    onPressed: _showDeleteDealDialog,
                                    icon: const Icon(Icons.delete_forever_outlined, size: 18),
                                    label: const Text('Delete Test Deal', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.statusGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _confirmAndSaveDealTerms,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Deal Terms', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
                  onPressed: () => setState(() => _isTermsUnlocked = false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
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

  Widget _readOnlyRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF64748B))),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerTab() {
    return StreamBuilder<List<PaymentRecordModel>>(
      stream: _firestore.streamPaymentRecords(_liveDeal.propertyId).map(
        (records) => records.where((r) => r.dealId == _liveDeal.id).toList(),
      ),
      builder: (context, snapshot) {
        final rawRecords = snapshot.data ?? [];
        final records = RentEngine.rebalanceLedgerRecords(rawRecords, _liveDeal);
        records.sort((a, b) => b.periodMonth.compareTo(a.periodMonth));

        if (records.isEmpty) {
          return const Center(child: Text('No payment records logged yet for this deal.'));
        }

        final remainingAdvance = RentEngine.getRunningAdvanceBalance(_liveDeal, DateTime.now());
        final totalDeposited = _liveDeal.totalAdvanceAmount;

        double totalDirectCashPaid = 0.0;
        double totalAdvanceAdjusted = 0.0;
        for (var r in records) {
          if (r.paymentSource == 'direct') {
            totalDirectCashPaid += r.totalPaid;
          } else if (r.paymentSource == 'advance') {
            totalAdvanceAdjusted += r.totalPaid;
          }
        }
        final latestRec = records.first;
        final totalPendingDues = latestRec.amountPending + latestRec.carriedOverDue;

        return Column(
          children: [
            // Live Financial Summary KPI Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F2942),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cash/UPI Paid', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text('₹${totalDirectCashPaid.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.statusGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: Colors.white24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_liveDeal.advanceConsumptionMode ? 'Adv Deducted' : 'Deposit Held', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(
                          _liveDeal.advanceConsumptionMode ? '₹${totalAdvanceAdjusted.toStringAsFixed(0)}' : '₹${totalDeposited.toStringAsFixed(0)}',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: Colors.white24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_liveDeal.advanceConsumptionMode ? 'Adv Remaining' : 'Security Pool', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(
                          '₹${remainingAdvance.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppTheme.goldAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: Colors.white24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pending Due', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(
                          '₹${totalPendingDues.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: totalPendingDues > 0 ? const Color(0xFFFCA5A5) : AppTheme.statusGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
                      onPressed: () {
                        ExportService.generatePDFStatement(
                          renterName: _liveDeal.businessName ?? 'Tenant',
                          unitLabel: widget.unit.label,
                          deal: _liveDeal,
                          records: records,
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: Text(AppLocalization.tr('export_pdf')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                      onPressed: () => _showPastRentSettleDialog(records),
                      icon: const Icon(Icons.bolt),
                      label: const Text('Settle Past Rents'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final rec = records[index];
                  final isAdvance = rec.status == 'adjusted-against-advance';
                  final isFullyPaid = rec.status == 'confirmed-paid' || (rec.amountPending == 0 && !isAdvance);
                  final isPartial = rec.status == 'confirmed-partial' || (rec.totalPaid > 0 && rec.amountPending > 0);

                  Color badgeColor;
                  String badgeLabel;
                  if (isAdvance) {
                    badgeColor = AppTheme.primaryTeal;
                    badgeLabel = 'ADJUSTED FROM ADVANCE';
                  } else if (isFullyPaid) {
                    badgeColor = AppTheme.statusGreen;
                    badgeLabel = 'PAID';
                  } else if (isPartial) {
                    badgeColor = const Color(0xFFD97706); // Amber/Yellow
                    badgeLabel = 'PARTIAL (₹${rec.totalPaid.toStringAsFixed(0)} / ₹${rec.effectiveRent.toStringAsFixed(0)})';
                  } else if (rec.status == 'pending-confirmation') {
                    badgeColor = const Color(0xFFEAB308);
                    badgeLabel = 'AWAITING APPROVAL';
                  } else if (rec.status == 'overdue') {
                    badgeColor = AppTheme.statusRed;
                    badgeLabel = 'OVERDUE';
                  } else {
                    badgeColor = const Color(0xFFEF4444);
                    badgeLabel = 'PENDING';
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: isPartial ? 3 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: isPartial
                          ? const BorderSide(color: Color(0xFFFBBF24), width: 1.5)
                          : (isFullyPaid ? const BorderSide(color: Color(0xFF86EFAC), width: 1) : BorderSide.none),
                    ),
                    child: ExpansionTile(
                      title: Row(
                        children: [
                          Text('${rec.periodMonth} • Month ${rec.monthIndex}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badgeLabel,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: isAdvance
                            ? Text(
                                'Monthly Rent: ₹${rec.effectiveRent.toStringAsFixed(0)} | Covered from Advance (₹0 Due)',
                                style: const TextStyle(fontSize: 13, color: AppTheme.primaryTeal, fontWeight: FontWeight.w600),
                              )
                            : (isFullyPaid
                                ? Text(
                                    'Monthly Rent: ₹${rec.effectiveRent.toStringAsFixed(0)} | Fully Paid: ₹${rec.totalPaid.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 13, color: AppTheme.statusGreen, fontWeight: FontWeight.w600),
                                  )
                                : Text(
                                    'Monthly Rent: ₹${rec.effectiveRent.toStringAsFixed(0)} | Paid: ₹${rec.totalPaid.toStringAsFixed(0)} | Rest Due: ₹${rec.amountPending.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isPartial ? const Color(0xFFD97706) : Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )),
                      ),
                      children: [
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (rec.carriedOverDue > 0) ...[
                                Text(
                                  'Past Arrears (Prior Months): ₹${rec.carriedOverDue.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange, fontSize: 13),
                                ),
                                Text(
                                  'Total Outstanding (Rent + Arrears): ₹${(rec.amountPending + rec.carriedOverDue).toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, fontSize: 13),
                                ),
                                const SizedBox(height: 10),
                              ],
                              if (isPartial) ...[
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Partially Paid: ₹${rec.totalPaid.toStringAsFixed(0)} collected across ${rec.installments.length} installment(s). Remaining ₹${rec.amountPending.toStringAsFixed(0)} pending.',
                                          style: TextStyle(color: Colors.amber.shade900, fontSize: 12.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Text(
                                'Payment Installments Breakdown (${rec.installments.length} Part${rec.installments.length == 1 ? '' : 's'}):',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                              ),
                              const SizedBox(height: 8),
                              if (rec.installments.isEmpty)
                                const Text('No installments submitted yet.', style: TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF64748B)))
                              else
                                ...rec.installments.asMap().entries.map((entry) {
                                  final instIndex = entry.key + 1;
                                  final inst = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.primaryNavy.withAlpha(20),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'Part $instIndex',
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '₹${inst.amount.toStringAsFixed(0)}',
                                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.statusGreen),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'via ${inst.method.toUpperCase()}',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                'Date: ${inst.date.day.toString().padLeft(2, '0')}/${inst.date.month.toString().padLeft(2, '0')}/${inst.date.year} • Added by ${inst.addedBy == 'owner' ? 'Owner / Admin' : 'Tenant'}',
                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                              ),
                                              if (inst.note != null && inst.note!.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text('Note: "${inst.note}"', style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF334155))),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.check_circle, color: AppTheme.statusGreen, size: 20),
                                      ],
                                    ),
                                  );
                                }),
                              const SizedBox(height: 14),
                              if (rec.amountPending > 0 && !isAdvance)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isPartial ? const Color(0xFFD97706) : AppTheme.statusGreen,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    icon: const Icon(Icons.add_card),
                                    label: Text(
                                      isPartial
                                          ? 'Record Next Installment (Due: ₹${rec.amountPending.toStringAsFixed(0)})'
                                          : 'Mark Paid Directly (₹${rec.dueFromRenter.toStringAsFixed(0)})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    onPressed: () => _showMarkPaidDialog(rec),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMarkPaidDialog(PaymentRecordModel rec) {
    final defaultAmount = rec.amountPending > 0 ? rec.amountPending : rec.dueFromRenter;
    final amountController = TextEditingController(text: defaultAmount.toStringAsFixed(0));
    final noteController = TextEditingController();
    String selectedMethod = 'upi';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final double enteredAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
            final double remainingAfterThis = (rec.amountPending - enteredAmount).clamp(0.0, double.infinity);
            final bool willBeFullyPaid = remainingAfterThis == 0 && enteredAmount > 0;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.add_card, color: willBeFullyPaid ? AppTheme.statusGreen : const Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rec.status == 'confirmed-partial' ? 'Record Next Installment' : 'Collect / Record Rent Payment',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Period: ${rec.periodMonth} • Month ${rec.monthIndex}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Monthly Rent: ₹${rec.effectiveRent.toStringAsFixed(0)} | Paid: ₹${rec.totalPaid.toStringAsFixed(0)} | Pending: ₹${rec.amountPending.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const Divider(height: 20),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount (INR) *',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedMethod,
                      decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'upi', child: Text('UPI / QR Code')),
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'bank', child: Text('Bank Transfer / NEFT / IMPS')),
                        DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedMethod = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setDlgState(() => selectedDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Payment Date', border: OutlineInputBorder()),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}'),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note / Transaction ID (Optional)',
                        hintText: 'e.g. Part payment / UPI Ref 123456',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: willBeFullyPaid ? Colors.green.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: willBeFullyPaid ? Colors.green.shade300 : Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            willBeFullyPaid ? Icons.check_circle : Icons.pie_chart,
                            color: willBeFullyPaid ? AppTheme.statusGreen : const Color(0xFFD97706),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              willBeFullyPaid
                                  ? 'This payment of ₹${enteredAmount.toStringAsFixed(0)} will complete full rent for ${rec.periodMonth} (Marked PAID in Green)!'
                                  : 'Partial Payment: ₹${enteredAmount.toStringAsFixed(0)} recorded. Remaining ₹${remainingAfterThis.toStringAsFixed(0)} will be marked PARTIAL in Yellow.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: willBeFullyPaid ? Colors.green.shade900 : Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalization.tr('cancel')),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: willBeFullyPaid ? AppTheme.statusGreen : const Color(0xFFD97706),
                  ),
                  onPressed: () async {
                    if (enteredAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid payment amount.')),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    final ownerUid = FirebaseAuth.instance.currentUser?.uid ?? 'owner';
                    Navigator.pop(ctx);

                    await _firestore.ownerMarkPaid(
                      record: rec,
                      amount: enteredAmount,
                      method: selectedMethod,
                      note: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
                      ownerUid: ownerUid,
                      deal: _liveDeal,
                    );

                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            willBeFullyPaid
                                ? 'Payment of ₹${enteredAmount.toStringAsFixed(0)} recorded! Month ${rec.periodMonth} marked fully PAID.'
                                : 'Partial installment of ₹${enteredAmount.toStringAsFixed(0)} recorded! ₹${remainingAfterThis.toStringAsFixed(0)} remaining in yellow.',
                          ),
                          backgroundColor: willBeFullyPaid ? AppTheme.statusGreen : const Color(0xFFD97706),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: Text(willBeFullyPaid ? 'Record & Mark Paid' : 'Record Partial Part'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAgreementTab() {
    final activeBase64 = _agreementBase64 ?? _liveDeal.agreementFileBase64;
    final driveLink = _agreementDriveLinkController.text.trim().isNotEmpty
        ? _agreementDriveLinkController.text.trim()
        : _liveDeal.agreementDriveLink;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_agreementType == 'drive-link' && driveLink != null && driveLink.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.link, color: AppTheme.goldAccent, size: 54),
                  const SizedBox(height: 12),
                  const Text(
                    'Google Drive Agreement Link Attached',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(driveLink, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.goldAccent, foregroundColor: AppTheme.primaryNavy),
                    onPressed: () async {
                      final url = Uri.parse(driveLink);
                      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Google Drive Document', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (activeBase64 != null && activeBase64.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(base64Decode(activeBase64), fit: BoxFit.contain),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(32),
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.no_photography_outlined, color: Colors.grey.shade400, size: 56),
                  const SizedBox(height: 12),
                  const Text(
                    'No Agreement Photo Scan Uploaded Yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'You can attach a high-resolution photo or scan of the signed lease agreement.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy, foregroundColor: AppTheme.goldAccent),
                    onPressed: () {
                      if (!_isTermsUnlocked) {
                        _handleUnlockTermsWithPin();
                      } else {
                        _pickAgreementPhoto();
                      }
                    },
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Attach Agreement Document Scan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
    );
  }
}
