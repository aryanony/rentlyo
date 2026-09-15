import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import '../core/brand_config.dart';
import '../core/app_config.dart';
import '../core/localization.dart';
import '../core/rent_engine.dart';
import '../core/local_security.dart';
import '../models/property_model.dart';
import '../models/unit_model.dart';
import '../models/deal_model.dart';
import '../models/payment_record_model.dart';
import '../models/user_model.dart';
import '../models/maintenance_request_model.dart';
import '../services/firestore_service.dart';
import 'renter_detail_screen.dart';
import 'add_unit_screen.dart';
import 'add_renter_wizard.dart';
import 'pending_confirmations_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'maintenance_management_screen.dart';
import 'notice_broadcast_screen.dart';
import 'utility_manager_screen.dart';
import 'gate_pass_approvals_screen.dart';
import 'mess_menu_publisher_screen.dart';

import '../services/update_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestore = FirestoreService();
  String _selectedTab = 'commercial'; // 'commercial' | 'residential'
  String _searchQuery = '';
  String _currentPropertyId = AppConfig.defaultPropertyId;
  String _currentPropertyName = AppConfig.propertyName;
  List<PropertyModel> _availableProperties = [];
  bool _isLoadingProperties = true;
  bool _showPastDeals = false;
  bool _isFabExtended = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableProperties();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate(context, appId: 'admin');
    });
  }

  Future<void> _loadAvailableProperties() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final savedId = await LocalSecurity.getSelectedPropertyId();

      // Query all properties in Firestore
      final snap = await FirebaseFirestore.instance.collection('properties').get();
      final allProps = snap.docs.map((d) => PropertyModel.fromMap(d.data(), d.id)).toList();

      List<String> userPropIds = [];
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null && data['propertyIds'] is List) {
            userPropIds = List<String>.from(data['propertyIds']);
          }
        }
      }

      // Filter matched properties owned by owner or configured in user's profile
      List<PropertyModel> matchedProps = allProps.where((p) {
        if (user != null && p.ownerUid == user.uid) return true;
        if (userPropIds.contains(p.id)) return true;
        if (p.id == AppConfig.defaultPropertyId) return true;
        return false;
      }).toList();

      if (matchedProps.isEmpty && allProps.isNotEmpty) {
        matchedProps = allProps;
      }

      String resolvedId = _currentPropertyId;
      if (savedId != null && matchedProps.any((p) => p.id == savedId)) {
        resolvedId = savedId;
      } else if (matchedProps.any((p) => p.id == AppConfig.defaultPropertyId)) {
        resolvedId = AppConfig.defaultPropertyId;
      } else if (matchedProps.isNotEmpty) {
        resolvedId = matchedProps.first.id;
      }

      final activeProp = matchedProps.firstWhere(
        (p) => p.id == resolvedId,
        orElse: () => matchedProps.isNotEmpty
            ? matchedProps.first
            : PropertyModel(
                id: resolvedId,
                name: AppConfig.propertyName,
                address: '',
                ownerUid: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
      );

      if (mounted) {
        setState(() {
          _availableProperties = matchedProps;
          _currentPropertyId = resolvedId;
          _currentPropertyName = activeProp.effectiveBrandName;
          _isLoadingProperties = false;
        });
      }

      await BrandConfig.load(resolvedId);
      _firestore.cleanupDuplicateDeals(resolvedId);
      _firestore.healPropertyUnitStatuses(resolvedId);
    } catch (e) {
      debugPrint("Error loading properties: $e");
      if (mounted) {
        setState(() => _isLoadingProperties = false);
      }
      _firestore.cleanupDuplicateDeals(_currentPropertyId);
      _firestore.healPropertyUnitStatuses(_currentPropertyId);
    }
  }

  Future<void> _switchProperty(String newPropertyId) async {
    if (newPropertyId == _currentPropertyId) return;
    final matched = _availableProperties.firstWhere(
      (p) => p.id == newPropertyId,
      orElse: () => PropertyModel(
        id: newPropertyId,
        name: newPropertyId,
        address: '',
        ownerUid: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    setState(() {
      _currentPropertyId = newPropertyId;
      _currentPropertyName = matched.effectiveBrandName;
    });
    await LocalSecurity.saveSelectedPropertyId(newPropertyId);
    await BrandConfig.load(newPropertyId);
    _firestore.cleanupDuplicateDeals(newPropertyId);
    _firestore.healPropertyUnitStatuses(newPropertyId);
  }

  void _showPropertySwitchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Active Property',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Switch between properties linked to your admin account:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _availableProperties.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final prop = _availableProperties[idx];
                      final isSelected = prop.id == _currentPropertyId;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? AppTheme.goldAccent.withAlpha(40)
                              : const Color(0xFFF1F5F9),
                          child: Icon(
                            Icons.business_outlined,
                            color: isSelected ? AppTheme.primaryNavy : const Color(0xFF64748B),
                          ),
                        ),
                        title: Text(
                          prop.effectiveBrandName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? AppTheme.primaryNavy : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          prop.address.isNotEmpty ? prop.address : 'ID: ${prop.id}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppTheme.goldAccent)
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          _switchProperty(prop.id);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final Uri url = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocalization.currentLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.goldAccent, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.goldAccent.withAlpha(50),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BrandConfig.buildLogoWidget(
                      defaultAsset: AppConfig.fullLogoAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _availableProperties.length > 1
                        ? () => _showPropertySwitchModal(context)
                        : null,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _currentPropertyName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryNavy,
                                  letterSpacing: 0.8,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_availableProperties.length > 1) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: AppTheme.goldAccent,
                                size: 22,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          BrandConfig.tagline.isNotEmpty
                              ? BrandConfig.tagline
                              : 'Admin Console',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.goldAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              StreamBuilder<List<PaymentRecordModel>>(
                stream: _firestore.streamPendingConfirmations(_currentPropertyId),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        tooltip: AppLocalization.tr('pending_confirmations'),
                        icon: const Icon(Icons.fact_check_outlined, size: 22),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PendingConfirmationsScreen(propertyId: _currentPropertyId),
                            ),
                          );
                        },
                      ),
                      if (count > 0)
                        Positioned(
                          right: 4,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.statusRed,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                    ],
                  );
                },
              ),
              IconButton(
                tooltip: AppLocalization.tr('reports'),
                icon: const Icon(Icons.analytics_outlined, size: 22),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportsScreen(propertyId: _currentPropertyId),
                    ),
                  );
                },
              ),
              StreamBuilder<List<MaintenanceRequestModel>>(
                stream: _firestore.streamPropertyMaintenanceRequests(_currentPropertyId),
                builder: (context, snapshot) {
                  final tickets = snapshot.data ?? [];
                  final openTicketsCount = tickets.where((t) => t.status == 'open' || t.status == 'in-progress').length;

                  return PopupMenuButton<String>(
                    icon: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.more_vert, size: 24),
                        if (openTicketsCount > 0)
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.statusOrange,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    tooltip: 'Management Tools & Settings',
                    onSelected: (val) {
                      if (val == 'maintenance') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MaintenanceManagementScreen(propertyId: _currentPropertyId),
                          ),
                        );
                      } else if (val == 'notice') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NoticeBroadcastScreen(propertyId: _currentPropertyId),
                          ),
                        );
                      } else if (val == 'utility') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UtilityManagerScreen(propertyId: _currentPropertyId, units: const []),
                          ),
                        );
                      } else if (val == 'gate_pass') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GatePassApprovalsScreen(propertyId: _currentPropertyId),
                          ),
                        );
                      } else if (val == 'mess') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MessMenuPublisherScreen(propertyId: _currentPropertyId),
                          ),
                        );
                      } else if (val == 'settings') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'maintenance',
                        child: Row(
                          children: [
                            const Icon(Icons.handyman_outlined, color: AppTheme.primaryNavy, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('Maintenance Requests')),
                            if (openTicketsCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.statusOrange,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$openTicketsCount',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'notice',
                        child: Row(
                          children: [
                            Icon(Icons.campaign_outlined, color: AppTheme.primaryNavy, size: 20),
                            SizedBox(width: 10),
                            Text('Notice Broadcast'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'utility',
                        child: Row(
                          children: [
                            Icon(Icons.bolt_outlined, color: AppTheme.primaryNavy, size: 20),
                            SizedBox(width: 10),
                            Text('Sub-Meter Utilities'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'gate_pass',
                        child: Row(
                          children: [
                            Icon(Icons.badge_outlined, color: AppTheme.primaryNavy, size: 20),
                            SizedBox(width: 10),
                            Text('Gate Pass Approvals'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'mess',
                        child: Row(
                          children: [
                            Icon(Icons.restaurant_menu_outlined, color: AppTheme.primaryNavy, size: 20),
                            SizedBox(width: 10),
                            Text('Mess Menu Publisher'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'settings',
                        child: Row(
                          children: [
                            Icon(Icons.settings_outlined, color: AppTheme.primaryNavy, size: 20),
                            SizedBox(width: 10),
                            Text('App Settings'),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              if (_isLoadingProperties)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppTheme.goldAccent,
                  backgroundColor: AppTheme.primaryNavy,
                ),
              // Segmented Control Tab (Commercial vs Residential)
              Container(
                color: AppTheme.primaryNavy,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 'commercial'),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _selectedTab == 'commercial' ? AppTheme.goldAccent : Colors.transparent,
                              borderRadius: BorderRadius.circular(23),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.storefront, color: _selectedTab == 'commercial' ? AppTheme.primaryNavy : Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  AppLocalization.tr('commercial'),
                                  style: TextStyle(
                                    color: _selectedTab == 'commercial' ? AppTheme.primaryNavy : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 'residential'),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _selectedTab == 'residential' ? AppTheme.goldAccent : Colors.transparent,
                              borderRadius: BorderRadius.circular(23),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.home_work_outlined, color: _selectedTab == 'residential' ? AppTheme.primaryNavy : Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  AppLocalization.tr('residential'),
                                  style: TextStyle(
                                    color: _selectedTab == 'residential' ? AppTheme.primaryNavy : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // KPI Dashboard Card v2.0
              StreamBuilder<List<PaymentRecordModel>>(
                stream: _firestore.streamPaymentRecords(_currentPropertyId),
                builder: (context, recordSnap) {
                  final records = recordSnap.data ?? [];
                  final currentPeriod = RentEngine.formatPeriodMonth(DateTime.now());

                  return StreamBuilder<List<UnitModel>>(
                    stream: _firestore.streamUnits(_currentPropertyId),
                    builder: (context, unitSnap) {
                      final allUnits = unitSnap.data ?? [];

                      return StreamBuilder<List<DealModel>>(
                        stream: _firestore.streamDeals(_currentPropertyId, activeOnly: false),
                        builder: (context, dealSnap) {
                          final allDeals = dealSnap.data ?? [];

                          bool isCommercialItem(String? type, String? label, String? unitId, {String? category}) {
                            final t = (type ?? '').toLowerCase().trim();
                            final c = (category ?? '').toLowerCase().trim();
                            final l = (label ?? '').toLowerCase().trim();
                            final u = (unitId ?? '').toLowerCase().trim();

                            if (t == 'commercial') return true;
                            if (t == 'residential') return false;

                            if (c == 'shop') return true;
                            if (c == 'flat' || c == 'room' || c == 'pg_bed') return false;

                            if (l.contains('shop') || l.contains('store') || u.contains('shop') || u.contains('store')) {
                              return true;
                            }
                            if (l.contains('flat') || l.contains('room') || l.contains('bed') || u.contains('flat') || u.contains('room') || u.contains('bed')) {
                              return false;
                            }
                            final shopCodeRegex = RegExp(r'^g\-?\d+', caseSensitive: false);
                            if (shopCodeRegex.hasMatch(l) || shopCodeRegex.hasMatch(u)) {
                              return true;
                            }
                            return false;
                          }

                          bool isDealCommercial(DealModel d) {
                            if (d.renterType.isNotEmpty) {
                              return isCommercialItem(d.renterType, d.unitLabel, d.currentUnitId);
                            }
                            final matchedUnit = allUnits.firstWhere(
                              (u) => u.id == d.currentUnitId || u.label.toLowerCase() == (d.unitLabel ?? '').toLowerCase(),
                              orElse: () => UnitModel(id: '', propertyId: '', label: '', type: '', floor: '', status: ''),
                            );
                            if (matchedUnit.id.isNotEmpty) {
                              return isCommercialItem(matchedUnit.type, matchedUnit.label, matchedUnit.id, category: matchedUnit.category);
                            }
                            return isCommercialItem(d.renterType, d.unitLabel, d.currentUnitId);
                          }

                          final units = allUnits.where((u) {
                            final isComm = isCommercialItem(u.type, u.label, u.id, category: u.category);
                            return _selectedTab == 'commercial' ? isComm : !isComm;
                          }).toList();

                          final activeDeals = allDeals.where((d) {
                            final isComm = isDealCommercial(d);
                            return (_selectedTab == 'commercial' ? isComm : !isComm) && d.status == 'active';
                          }).toList();

                          // Calculate total occupied units in selected tab (accounts for multi-unit deals)
                          final occupiedCount = units.where((u) {
                            return u.status == 'occupied' || activeDeals.any((d) =>
                              d.containsUnit(u.id) || d.containsUnit(u.label)
                            );
                          }).length;

                          final vacantCount = math.max(0, units.length - occupiedCount);

                          // Match payment records specifically for active deals in the selected tab
                          final activeDealIds = activeDeals.map((d) => d.id).toSet();

                          double expected = 0;
                          double collected = 0;
                          double pending = 0;
                          int overdueCount = 0;

                          for (var r in records) {
                            if (r.periodMonth != currentPeriod) continue;
                            final belongsToActiveCategory = activeDealIds.contains(r.dealId) ||
                                activeDeals.any((d) => d.containsUnit(r.unitId));
                            if (belongsToActiveCategory) {
                              expected += r.dueFromRenter;
                              collected += r.totalPaid;
                              pending += r.amountPending;
                              if (r.status == 'overdue') {
                                overdueCount++;
                              }
                            }
                          }

                          final percentage = expected > 0 ? (collected / expected).clamp(0.0, 1.0) : 0.0;

                          // Step-up count this month for active deals
                          int stepUpCount = 0;
                          final now = DateTime.now();
                          for (var d in activeDeals) {
                            final hasStepThisMonth = d.rentSchedule.any((s) =>
                                s.effectiveFromDate.year == now.year &&
                                s.effectiveFromDate.month == now.month &&
                                s.effectiveFromDate != d.rentSchedule.first.effectiveFromDate);
                            if (hasStepThisMonth) stepUpCount++;
                          }

                          // Advance Deposit Pool for active deals in selected tab
                          double totalAdvancePool = 0;
                          for (var d in activeDeals) {
                            totalAdvancePool += RentEngine.getRunningAdvanceBalance(d, now);
                          }

                          return Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.primaryNavy, Color(0xFF0F2942)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Month & Collection Rate Badge
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(25),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_month, color: AppTheme.goldAccent, size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            'This Month ($currentPeriod)',
                                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.goldAccent.withAlpha(40),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.goldAccent, width: 1),
                                      ),
                                      child: Text(
                                        '${(percentage * 100).toStringAsFixed(0)}% Collected',
                                        style: const TextStyle(color: AppTheme.goldAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Expected / Collected / Pending Metrics
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _summaryCol(AppLocalization.tr('expected'), '₹${expected.toStringAsFixed(0)}', Colors.white),
                                    _summaryCol(AppLocalization.tr('collected'), '₹${collected.toStringAsFixed(0)}', const Color(0xFF86EFAC)),
                                    _summaryCol(AppLocalization.tr('pending'), '₹${pending.toStringAsFixed(0)}', Colors.amberAccent),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage,
                                    backgroundColor: Colors.white24,
                                    color: AppTheme.goldAccent,
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Structured Operational Intelligence Cards
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Row(
                                              children: [
                                                Icon(Icons.home_work_outlined, color: AppTheme.goldAccent, size: 16),
                                                SizedBox(width: 6),
                                                Text('Occupancy', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$occupiedCount / ${math.max(units.length, occupiedCount)} Occupied',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            Text(
                                              '$vacantCount Vacant Unit${vacantCount == 1 ? "" : "s"}',
                                              style: TextStyle(
                                                color: vacantCount > 0 ? Colors.amberAccent : Colors.white70,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Row(
                                              children: [
                                                Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 16),
                                                SizedBox(width: 6),
                                                Text('Advance Deposit', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '₹${totalAdvancePool.toStringAsFixed(0)}',
                                              style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            Text(
                                              '$overdueCount Overdue • $stepUpCount Step-up${stepUpCount == 1 ? "" : "s"}',
                                              style: TextStyle(
                                                color: overdueCount > 0 ? const Color(0xFFFCA5A5) : Colors.white70,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search renter name or unit label...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),

              // Filter Bar (Active vs Past Ended Deals)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    FilterChip(
                      selected: !_showPastDeals,
                      label: const Text('Active Renters'),
                      onSelected: (val) => setState(() => _showPastDeals = !val),
                      selectedColor: AppTheme.primaryNavy.withAlpha(20),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _showPastDeals,
                      label: const Text('Past / Ended Deals'),
                      onSelected: (val) => setState(() => _showPastDeals = val),
                      selectedColor: AppTheme.primaryNavy.withAlpha(20),
                    ),
                  ],
                ),
              ),

              // Units & Renters List
              Expanded(
                child: StreamBuilder<List<UnitModel>>(
                  stream: _firestore.streamUnits(_currentPropertyId),
                  builder: (context, unitSnap) {
                    if (unitSnap.connectionState == ConnectionState.waiting && !unitSnap.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (unitSnap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_off_outlined, size: 48, color: AppTheme.statusRed),
                              const SizedBox(height: 12),
                              Text(
                                'Error loading units: ${unitSnap.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => setState(() {}),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry Connection'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final allUnits = unitSnap.data ?? [];

                    return StreamBuilder<List<DealModel>>(
                      stream: _firestore.streamDeals(_currentPropertyId, activeOnly: !_showPastDeals, pastOnly: _showPastDeals),
                      builder: (context, dealSnap) {
                        final allDeals = dealSnap.data ?? [];

                        bool isCommercialItem(String? type, String? label, String? unitId, {String? category}) {
                          final t = (type ?? '').toLowerCase().trim();
                          final c = (category ?? '').toLowerCase().trim();
                          final l = (label ?? '').toLowerCase().trim();
                          final u = (unitId ?? '').toLowerCase().trim();

                          if (t == 'commercial') return true;
                          if (t == 'residential') return false;

                          if (c == 'shop') return true;
                          if (c == 'flat' || c == 'room' || c == 'pg_bed') return false;

                          if (l.contains('shop') || l.contains('store') || u.contains('shop') || u.contains('store')) {
                            return true;
                          }
                          if (l.contains('flat') || l.contains('room') || l.contains('bed') || u.contains('flat') || u.contains('room') || u.contains('bed')) {
                            return false;
                          }
                          final shopCodeRegex = RegExp(r'^g\-?\d+', caseSensitive: false);
                          if (shopCodeRegex.hasMatch(l) || shopCodeRegex.hasMatch(u)) {
                            return true;
                          }
                          return false;
                        }

                        bool isDealCommercial(DealModel d) {
                          if (d.renterType.isNotEmpty) {
                            return isCommercialItem(d.renterType, d.unitLabel, d.currentUnitId);
                          }
                          final matchedUnit = allUnits.firstWhere(
                            (u) => u.id == d.currentUnitId || u.label.toLowerCase() == (d.unitLabel ?? '').toLowerCase(),
                            orElse: () => UnitModel(id: '', propertyId: '', label: '', type: '', floor: '', status: ''),
                          );
                          if (matchedUnit.id.isNotEmpty) {
                            return isCommercialItem(matchedUnit.type, matchedUnit.label, matchedUnit.id, category: matchedUnit.category);
                          }
                          return isCommercialItem(d.renterType, d.unitLabel, d.currentUnitId);
                        }

                        // Filter units matching selected tab
                        final units = allUnits.where((u) {
                          final isComm = isCommercialItem(u.type, u.label, u.id, category: u.category);
                          return _selectedTab == 'commercial' ? isComm : !isComm;
                        }).toList();

                        // Filter deals matching selected tab
                        final deals = allDeals.where((d) {
                          final isComm = isDealCommercial(d);
                          return _selectedTab == 'commercial' ? isComm : !isComm;
                        }).toList();

                        // Merge fallback virtual units for deals without a unit document
                        final unitMap = <String, UnitModel>{for (var u in units) u.id: u};
                        for (var d in deals) {
                          if (!unitMap.containsKey(d.currentUnitId)) {
                            final virtualUnit = UnitModel(
                              id: d.currentUnitId.isNotEmpty ? d.currentUnitId : d.id,
                              propertyId: d.propertyId,
                              type: _selectedTab,
                              floor: 'Ground',
                              label: d.displayUnitLabel,
                              status: 'occupied',
                            );
                            units.add(virtualUnit);
                            unitMap[virtualUnit.id] = virtualUnit;
                          }
                        }

                        return StreamBuilder<List<PaymentRecordModel>>(
                          stream: _firestore.streamPaymentRecords(_currentPropertyId),
                          builder: (context, recSnap) {
                            final allRecords = recSnap.data ?? [];
                            final currentPeriod = RentEngine.formatPeriodMonth(DateTime.now());

                            if (units.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.business_outlined, size: 56, color: Color(0xFF94A3B8)),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No $_selectedTab units found in $_currentPropertyName.',
                                      style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(minimumSize: const Size(140, 44)),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => AddUnitScreen(propertyId: _currentPropertyId, initialType: _selectedTab),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.add),
                                          label: Text(AppLocalization.tr('add_unit')),
                                        ),
                                        if (_availableProperties.length > 1) ...[
                                          const SizedBox(width: 10),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(minimumSize: const Size(140, 44)),
                                            onPressed: () => _showPropertySwitchModal(context),
                                            icon: const Icon(Icons.swap_horiz),
                                            label: const Text('Switch Property'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }

                             if (_showPastDeals) {
                              final endedDeals = deals.where((d) => d.status == 'ended' || d.status == 'closed').toList();
                              final filteredEnded = endedDeals.where((d) {
                                if (_searchQuery.isEmpty) return true;
                                final matchUnit = d.displayMultiUnitLabel.toLowerCase().contains(_searchQuery);
                                final matchBiz = d.businessName?.toLowerCase().contains(_searchQuery) ?? false;
                                return matchUnit || matchBiz;
                              }).toList();

                              if (filteredEnded.isEmpty) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.history_outlined, size: 48, color: Color(0xFF94A3B8)),
                                        SizedBox(height: 12),
                                        Text('No Past / Ended Deals Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                                        SizedBox(height: 4),
                                        Text('Ended or closed lease deals will appear here.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return NotificationListener<UserScrollNotification>(
                                onNotification: (notification) {
                                  if (notification.direction == ScrollDirection.reverse) {
                                    if (_isFabExtended) setState(() => _isFabExtended = false);
                                  } else if (notification.direction == ScrollDirection.forward) {
                                    if (!_isFabExtended) setState(() => _isFabExtended = true);
                                  }
                                  return true;
                                },
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
                                  itemCount: filteredEnded.length,
                                  itemBuilder: (context, index) {
                                  final deal = filteredEnded[index];
                                  final dummyUnit = UnitModel(
                                    id: deal.currentUnitId.isNotEmpty ? deal.currentUnitId : 'past_unit',
                                    propertyId: deal.propertyId,
                                    floor: 'Ground',
                                    type: deal.renterType,
                                    label: deal.displayMultiUnitLabel,
                                    status: 'vacant',
                                  );

                                  final returnedAdv = deal.advanceRefundAmount ?? deal.totalAdvanceAmount;
                                  final refundNoteStr = deal.advanceRefundNote ?? 'Advance deposit returned on deal closing';
                                  final startStr = '${deal.dealStartDate.day}/${deal.dealStartDate.month}/${deal.dealStartDate.year}';
                                  final endD = deal.dealEndDate ?? deal.updatedAt;
                                  final endStr = '${endD.day}/${endD.month}/${endD.year}';

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => RenterDetailScreen(unit: dummyUnit, deal: deal),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 22,
                                                  backgroundColor: const Color(0xFF64748B),
                                                  child: Text(
                                                    deal.displayMultiUnitLabel.substring(0, math.min(deal.displayMultiUnitLabel.length, 3)).toUpperCase(),
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              'Unit ${deal.displayMultiUnitLabel} • ${deal.businessName ?? "Past Tenant"}',
                                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFFEF2F2),
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(color: const Color(0xFFFCA5A5)),
                                                            ),
                                                            child: const Text('ENDED / CLOSED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                                                          ),
                                                          const SizedBox(width: 4),
                                                           FutureBuilder<bool>(
                                                             future: _firestore.canDeleteDeal(deal.id),
                                                             builder: (context, snap) {
                                                               final canDel = snap.data == true;
                                                               if (!canDel) return const SizedBox.shrink();
                                                               return IconButton(
                                                                 icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                                                 tooltip: 'Delete Deal Record',
                                                                 constraints: const BoxConstraints(),
                                                                 padding: EdgeInsets.zero,
                                                                 onPressed: () async {
                                                                   final confirm = await showDialog<bool>(
                                                                     context: context,
                                                                     builder: (ctx) => AlertDialog(
                                                                       title: const Text('Delete Deal'),
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
                                                                     await _firestore.deleteDeal(deal.id);
                                                                   }
                                                                 },
                                                               );
                                                             },
                                                           ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Tenant: ${deal.businessName ?? deal.renterId}',
                                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(height: 16),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Deal Tenure: $startStr – $endStr',
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                ),
                                                const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF94A3B8)),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF0FDF4),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFBBF7D0)),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.verified_user_outlined, size: 14, color: AppTheme.statusGreen),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      'Returned Advance: ₹${returnedAdv.toStringAsFixed(0)} ($refundNoteStr)',
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }

                            final renderedDealIds = <String>{};
                            final activeDisplayItems = <Map<String, dynamic>>[];

                            // Build set of secondary merged unit IDs/labels that should be
                            // hidden from the list. When a deal has multiple assigned units
                            // (e.g. G1 + G2 + G3), only the primary unit (currentUnitId)
                            // gets its own card — the secondaries are absorbed into it.
                            final mergedSecondaryUnitIds = <String>{};
                            final mergedSecondaryUnitLabels = <String>{};
                            for (var d in deals) {
                              if (d.status != 'active') continue;
                              if (d.assignedUnitIds.length <= 1 && d.assignedUnitLabels.length <= 1) continue;
                              for (var uid in d.assignedUnitIds) {
                                if (uid.isNotEmpty && uid != d.currentUnitId) {
                                  mergedSecondaryUnitIds.add(uid);
                                }
                              }
                              // Also collect label-based secondaries
                              final primaryLabel = d.currentUnitId.toLowerCase().trim();
                              for (var lbl in d.assignedUnitLabels) {
                                final cleanLbl = lbl.toLowerCase().trim();
                                if (cleanLbl.isNotEmpty && cleanLbl != primaryLabel) {
                                  // Check if this label matches the primary unit's label
                                  final primaryUnitMatch = units.where((u) => u.id == d.currentUnitId).toList();
                                  final primaryUnitLabel = primaryUnitMatch.isNotEmpty
                                      ? primaryUnitMatch.first.label.toLowerCase().trim()
                                      : '';
                                  if (cleanLbl != primaryUnitLabel) {
                                    mergedSecondaryUnitLabels.add(cleanLbl);
                                  }
                                }
                              }
                            }

                            for (var unit in units) {
                              // Skip secondary merged units — they are shown inside the
                              // primary deal card via displayMultiUnitLabel
                              if (mergedSecondaryUnitIds.contains(unit.id) ||
                                  mergedSecondaryUnitLabels.contains(unit.label.toLowerCase().trim())) {
                                continue;
                              }

                              final deal = deals.firstWhere(
                                (d) =>
                                  d.status == 'active' && (
                                    d.currentUnitId == unit.id ||
                                    (d.unitLabel != null && d.unitLabel!.toLowerCase() == unit.label.toLowerCase()) ||
                                    d.assignedUnitIds.contains(unit.id) ||
                                    d.assignedUnitLabels.any((l) => l.toLowerCase() == unit.label.toLowerCase()) ||
                                    d.containsUnit(unit.id) ||
                                    d.containsUnit(unit.label)
                                  ),
                                orElse: () => DealModel(
                                  id: '',
                                  propertyId: '',
                                  currentUnitId: '',
                                  renterId: '',
                                  renterType: _selectedTab,
                                  dealStartDate: DateTime.now(),
                                  rentSchedule: [],
                                  advanceTransactions: [],
                                  advanceConsumptionMode: false,
                                  unitHistory: [],
                                  amenities: [],
                                  carryForwardPendingBalance: true,
                                  status: 'vacant',
                                  notes: '',
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                ),
                              );

                              final isOccupied = (unit.status == 'occupied' || deal.id.isNotEmpty) && deal.status == 'active';

                              if (_searchQuery.isNotEmpty) {
                                final matchUnit = unit.label.toLowerCase().contains(_searchQuery) ||
                                    deal.displayMultiUnitLabel.toLowerCase().contains(_searchQuery);
                                final matchBiz = deal.businessName?.toLowerCase().contains(_searchQuery) ?? false;
                                if (!matchUnit && !matchBiz) continue;
                              }

                              if (isOccupied) {
                                if (!renderedDealIds.contains(deal.id)) {
                                  renderedDealIds.add(deal.id);
                                  activeDisplayItems.add({
                                    'unit': unit,
                                    'deal': deal,
                                    'isOccupied': true,
                                  });
                                }
                              } else {
                                activeDisplayItems.add({
                                  'unit': unit,
                                  'deal': deal,
                                  'isOccupied': false,
                                });
                              }
                            }

                            return NotificationListener<UserScrollNotification>(
                              onNotification: (notification) {
                                if (notification.direction == ScrollDirection.reverse) {
                                  if (_isFabExtended) setState(() => _isFabExtended = false);
                                } else if (notification.direction == ScrollDirection.forward) {
                                  if (!_isFabExtended) setState(() => _isFabExtended = true);
                                }
                                return true;
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
                                itemCount: activeDisplayItems.length,
                                itemBuilder: (context, index) {
                                final item = activeDisplayItems[index];
                                final unit = item['unit'] as UnitModel;
                                final deal = item['deal'] as DealModel;
                                final isOccupied = item['isOccupied'] as bool;

                                final record = allRecords.firstWhere(
                                  (r) => r.dealId == deal.id && r.periodMonth == currentPeriod,
                                  orElse: () => PaymentRecordModel(
                                    id: '',
                                    dealId: '',
                                    renterId: '',
                                    propertyId: '',
                                    unitId: '',
                                    periodMonth: currentPeriod,
                                    monthIndex: 1,
                                    effectiveRent: 0,
                                    paymentSource: 'direct',
                                    dueFromRenter: 0,
                                    carriedOverDue: 0,
                                    totalPaid: 0,
                                    amountPending: 0,
                                    status: 'pending',
                                  ),
                                );

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: InkWell(
                                    onTap: () {
                                      if (isOccupied) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => RenterDetailScreen(unit: unit, deal: deal),
                                          ),
                                        );
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AddRenterWizard(unit: unit),
                                          ),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 22,
                                                backgroundColor: isOccupied ? AppTheme.primaryNavy : const Color(0xFF94A3B8),
                                                child: Text(
                                                  unit.label.substring(0, math.min(unit.label.length, 3)).toUpperCase(),
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '${isOccupied && deal.assignedUnitLabels.isNotEmpty ? deal.displayMultiUnitLabel : unit.label} • ${unit.floor}',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      isOccupied
                                                          ? (deal.businessName != null && deal.businessName!.isNotEmpty
                                                              ? deal.businessName!
                                                              : 'Tenant Active')
                                                      : AppLocalization.tr('vacant'),
                                                      style: TextStyle(
                                                        color: isOccupied ? const Color(0xFF334155) : AppTheme.statusGrey,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    if (isOccupied && deal.isMultiUnit) ...[
                                                      const SizedBox(height: 4),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.primaryTeal.withAlpha(20),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: AppTheme.primaryTeal.withAlpha(60)),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.merge_type, size: 13, color: AppTheme.primaryTeal),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              'Merged: ${deal.multiUnitLabelsList.join(" + ")} (${deal.multiUnitLabelsList.length} units)',
                                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              if (isOccupied)
                                                _buildStatusChip(record.status)
                                              else
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                                      tooltip: 'Delete Unit',
                                                      onPressed: () async {
                                                        final messenger = ScaffoldMessenger.of(context);
                                                        final canDel = await _firestore.canDeleteUnit(unit.id, unitLabel: unit.label);
                                                        if (!mounted) return;
                                                        if (!canDel) {
                                                          messenger.showSnackBar(
                                                            const SnackBar(content: Text('This unit has deal history — cannot be deleted. Only "Mark Vacant" is offered instead.')),
                                                          );
                                                          return;
                                                        }

                                                        if (!mounted) return;
                                                        final confirm = await showDialog<bool>(
                                                          context: this.context,
                                                          builder: (ctx) => AlertDialog(
                                                            title: const Text('Delete Unit'),
                                                            content: Text('This will permanently remove this test entry — continue? (Unit "${unit.label}")'),
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
                                                          await _firestore.deleteUnit(unit.id);
                                                          if (mounted) {
                                                            messenger.showSnackBar(
                                                              SnackBar(content: Text('Unit ${unit.label} deleted.')),
                                                            );
                                                          }
                                                        }
                                                      },
                                                    ),
                                                    const SizedBox(width: 4),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        minimumSize: const Size(80, 36),
                                                        backgroundColor: AppTheme.primaryNavy,
                                                      ),
                                                      onPressed: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) => AddRenterWizard(unit: unit),
                                                          ),
                                                        );
                                                      },
                                                      child: const Text('Rent', style: TextStyle(fontSize: 13)),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                          if (isOccupied) ...[
                                            const Divider(height: 18, color: Color(0xFFF1F5F9)),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Rent: ₹${RentEngine.getEffectiveRent(deal, RentEngine.getMonthIndex(deal.dealStartDate, DateTime.now())).toStringAsFixed(0)}/mo (Due ${deal.rentDueDayOfMonth}th)',
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                StreamBuilder<UserModel?>(
                                                  stream: _firestore.streamUser(deal.renterId),
                                                  builder: (context, userSnap) {
                                                    final phone = userSnap.data?.phone ?? '';
                                                    if (phone.isEmpty) return const SizedBox.shrink();
                                                    return Row(
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(Icons.phone, color: AppTheme.primaryNavy, size: 20),
                                                          onPressed: () => _makePhoneCall(phone),
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.statusGreen, size: 20),
                                                          onPressed: () => _openWhatsApp(phone),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                )
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            isExtended: _isFabExtended,
            backgroundColor: AppTheme.primaryNavy,
            elevation: 4,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddUnitScreen(propertyId: _currentPropertyId, initialType: _selectedTab),
                ),
              );
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(AppLocalization.tr('add_unit'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _summaryCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    String label;

    switch (status) {
      case 'confirmed-paid':
        bg = AppTheme.statusGreen;
        label = 'Paid';
        break;
      case 'pending-confirmation':
        bg = AppTheme.statusYellow;
        label = 'Confirm';
        break;
      case 'confirmed-partial':
        bg = AppTheme.statusOrange;
        label = 'Partial';
        break;
      case 'overdue':
        bg = AppTheme.statusRed;
        label = 'Overdue';
        break;
      case 'pending':
        bg = AppTheme.statusRed;
        label = 'Pending';
        break;
      case 'adjusted-against-advance':
        bg = const Color(0xFF0284C7); // Vibrant Royal/Sky Blue
        label = 'Advance';
        break;
      default:
        bg = AppTheme.statusGrey;
        label = 'Unknown';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
