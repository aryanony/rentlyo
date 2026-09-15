import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme.dart';
import '../core/brand_config.dart';
import '../core/app_config.dart';
import '../core/localization.dart';
import '../core/rent_engine.dart';
import '../models/deal_model.dart';
import '../models/payment_record_model.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import '../widgets/app_loader.dart';
import 'report_payment_screen.dart';
import 'payment_history_screen.dart';
import 'deal_summary_screen.dart';
import 'agreement_viewer_screen.dart';
import 'notifications_screen.dart';
import '../services/smart_notification_service.dart';
import 'settings_screen.dart';
import 'maintenance_screen.dart';
import 'notices_screen.dart';
import 'gate_pass_screen.dart';
import 'utility_bills_screen.dart';
import 'visitor_preapprove_screen.dart';
import 'mess_menu_screen.dart';
import '../services/update_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedDealIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate(context, appId: 'renter');
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestore = FirestoreService();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Authentication session expired. Please log in.')),
      );
    }

    String getPsychologicalGreeting() {
      final hour = DateTime.now().hour;
      if (hour >= 5 && hour < 12) {
        return 'Good Morning';
      } else if (hour >= 12 && hour < 17) {
        return 'Good Afternoon';
      } else if (hour >= 17 && hour < 22) {
        return 'Good Evening';
      } else {
        return 'Welcome Back';
      }
    }

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

    return ValueListenableBuilder<String>(
      valueListenable: AppLocalization.currentLanguage,
      builder: (context, lang, _) {
        return StreamBuilder<List<DealModel>>(
          stream: firestore.streamRenterDeals(user),
          builder: (context, dealSnap) {
            final rawDeals = dealSnap.data ?? [];

            final deals = List<DealModel>.from(rawDeals);
            deals.sort((a, b) {
              final aIsComm = isCommercialItem(a.renterType, a.unitLabel, a.currentUnitId);
              final bIsComm = isCommercialItem(b.renterType, b.unitLabel, b.currentUnitId);
              if (aIsComm && !bIsComm) return -1;
              if (!aIsComm && bIsComm) return 1;
              return 0;
            });

            if (_selectedDealIndex >= deals.length && deals.isNotEmpty) {
              _selectedDealIndex = 0;
            }

            final activeDeal = deals.isNotEmpty ? deals[_selectedDealIndex] : null;

            final shopOrBusinessName = activeDeal?.businessName?.trim().isNotEmpty == true
                ? activeDeal!.businessName!.trim()
                : (user.displayName != null && user.displayName!.trim().isNotEmpty ? user.displayName!.trim() : '${BrandConfig.brandName} Tenant');

            final unitDisplayName = activeDeal != null
                ? (activeDeal.isMultiUnit
                    ? 'Units ${activeDeal.displayMultiUnitLabel}'
                    : 'Unit ${activeDeal.displayMultiUnitLabel}')
                : 'Tenant Portal';

            return Scaffold(
              appBar: AppBar(
                titleSpacing: 8,
                title: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.goldAccent, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.goldAccent.withAlpha(50),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: BrandConfig.buildLogoWidget(
                          fit: BoxFit.contain,
                          defaultAsset: AppConfig.fullLogoAsset,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            shopOrBusinessName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryNavy,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            unitDisplayName,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.primaryTeal,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  StreamBuilder<List<NotificationModel>>(
                    stream: firestore.streamNotifications(user.uid),
                    builder: (context, snapshot) {
                      final notifs = snapshot.data ?? [];
                      final unreadCount = notifs.where((n) => !n.read).length;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined),
                            tooltip: 'Notifications',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => NotificationsScreen(userUid: user.uid)),
                              );
                            },
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 6,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: const BoxDecoration(
                                  color: AppTheme.statusRed,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
                ],
              ),
              body: Builder(
                builder: (context) {
                  if (dealSnap.connectionState == ConnectionState.waiting) {
                    return const AppLoader(message: 'Loading dashboard...');
                  }

                  if (deals.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No active lease agreement found for your account.\nPlease contact your property owner.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  }

                  final deal = deals[_selectedDealIndex];

                  if (deal.status == 'active') {
                    firestore.checkAndLazyGenerateMonthRecord(deal);
                  }

                  return StreamBuilder<List<PaymentRecordModel>>(
                    stream: firestore.streamRenterLedger(deal.id, deal.renterId),
                    builder: (context, ledgerSnap) {
                      final rawRecords = ledgerSnap.data ?? [];
                      final records = RentEngine.rebalanceLedgerRecords(rawRecords, deal);
                      final currentPeriod = RentEngine.formatPeriodMonth(DateTime.now());

                      PaymentRecordModel? currentRecord;
                      if (records.isNotEmpty) {
                        currentRecord = records.firstWhere(
                          (r) => r.periodMonth == currentPeriod,
                          orElse: () => records.first,
                        );
                      }

                      if (deal.status == 'active' && ledgerSnap.hasData && ledgerSnap.connectionState != ConnectionState.waiting) {
                        SmartNotificationService().checkAndGenerateRentNotifications(
                          userUid: user.uid,
                          propertyId: deal.propertyId,
                          deal: deal,
                          payments: rawRecords,
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          await firestore.checkAndLazyGenerateMonthRecord(deal);
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Property Identity Banner
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.primaryNavy, Color(0xFF1E293B)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: AppTheme.goldAccent.withAlpha(200), width: 2.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.goldAccent.withAlpha(40),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 70,
                                        height: 70,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: AppTheme.goldAccent, width: 1.5),
                                        ),
                                        child: BrandConfig.buildLogoWidget(
                                          fit: BoxFit.cover,
                                          defaultAsset: 'assets/images/logo.png',
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  BrandConfig.brandName.toUpperCase(),
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w900,
                                                    color: AppTheme.goldAccent,
                                                    letterSpacing: 1.5,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.goldAccent.withAlpha(40),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: AppTheme.goldAccent, width: 1),
                                                  ),
                                                  child: const Text(
                                                    'OFFICIAL',
                                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.goldAccent),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              AppConfig.defaultAddress,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.white.withAlpha(230),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Verified Software-Managed Property',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.goldAccent.withAlpha(220),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Dual-Lease Switcher Tab Bar
                              if (deals.length > 1) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade300),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(10),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: List.generate(deals.length, (idx) {
                                      final d = deals[idx];
                                      final isSelected = _selectedDealIndex == idx;
                                      final isComm = isCommercialItem(d.renterType, d.unitLabel, d.currentUnitId);

                                      String label;
                                      if (deals.where((item) => isCommercialItem(item.renterType, item.unitLabel, item.currentUnitId) == isComm).length > 1) {
                                        label = isComm ? 'Commercial (${d.displayUnitCode})' : 'Residential (${d.displayUnitCode})';
                                      } else {
                                        label = isComm ? 'Commercial' : 'Residential';
                                      }

                                      return Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() => _selectedDealIndex = idx),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                            decoration: BoxDecoration(
                                              color: isSelected ? AppTheme.primaryNavy : Colors.transparent,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  isComm ? Icons.storefront : Icons.home_work_outlined,
                                                  size: 18,
                                                  color: isSelected ? AppTheme.goldAccent : AppTheme.primaryNavy,
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    label,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: isSelected ? Colors.white : AppTheme.primaryNavy,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ],

                              // Psychological VIP Business / Tenant Header Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppTheme.primaryTeal.withAlpha(40), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryNavy.withAlpha(12),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryTeal.withAlpha(20),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: AppTheme.primaryTeal.withAlpha(60)),
                                          ),
                                          child: Text(
                                            getPsychologicalGreeting(),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.statusGreen.withAlpha(20),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle, size: 14, color: AppTheme.statusGreen),
                                              SizedBox(width: 4),
                                              Text(
                                                'Verified Lease',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.statusGreen),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryNavy.withAlpha(10),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: AppTheme.goldAccent.withAlpha(100)),
                                          ),
                                          child: Icon(
                                            isCommercialItem(deal.renterType, deal.unitLabel, deal.currentUnitId)
                                                ? Icons.storefront
                                                : Icons.home_work_outlined,
                                            color: AppTheme.primaryNavy,
                                            size: 30,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                deal.businessName != null && deal.businessName!.trim().isNotEmpty
                                                    ? deal.businessName!.trim()
                                                    : (user.displayName != null && user.displayName!.trim().isNotEmpty ? user.displayName!.trim() : '${BrandConfig.brandName} Tenant'),
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppTheme.primaryNavy,
                                                  letterSpacing: 0.3,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                               const SizedBox(height: 3),
                                               Text(
                                                 '${deal.isMultiUnit ? "Units ${deal.displayMultiUnitLabel}" : deal.displayUnitLabel} • ${isCommercialItem(deal.renterType, deal.unitLabel, deal.currentUnitId) ? "Commercial Shop" : "Residential Flat"}',
                                                 style: const TextStyle(
                                                   fontSize: 14,
                                                   color: AppTheme.primaryTeal,
                                                   fontWeight: FontWeight.bold,
                                                 ),
                                                 overflow: TextOverflow.ellipsis,
                                                 maxLines: 1,
                                               ),
                                               if (deal.isMultiUnit) ...[
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
                                                         'Merged Deal: ${deal.multiUnitLabelsList.join(" + ")} (${deal.multiUnitLabelsList.length} units)',
                                                         style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                                                       ),
                                                     ],
                                                   ),
                                                 ),
                                               ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // PRIMARY DYNAMIC STATUS CARD (<2-second readability goal)
                              _buildPrimaryStatusCard(context, deal, currentRecord),

                              const SizedBox(height: 24),
                        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                        const SizedBox(height: 12),

                        // Action Tiles Grid Scoped by Renter Type (Commercial vs Residential)
                        Row(
                          children: [
                            Expanded(
                              child: _actionTile(
                                context,
                                icon: Icons.receipt_long_outlined,
                                iconColor: AppTheme.primaryTeal,
                                title: AppLocalization.tr('payment_history'),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => PaymentHistoryScreen(deal: deal)),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _actionTile(
                                context,
                                icon: Icons.article_outlined,
                                iconColor: AppTheme.goldAccent,
                                title: AppLocalization.tr('deal_summary'),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => DealSummaryScreen(deal: deal)),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _actionTile(
                                context,
                                icon: Icons.handyman_outlined,
                                iconColor: const Color(0xFFD97706),
                                title: AppLocalization.tr('maintenance'),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => MaintenanceScreen(deal: deal)),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _actionTile(
                                context,
                                icon: Icons.campaign_outlined,
                                iconColor: const Color(0xFF2563EB),
                                title: AppLocalization.tr('notices'),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NoticesScreen(
                                        propertyId: deal.propertyId.isNotEmpty ? deal.propertyId : AppConfig.defaultPropertyId,
                                        renterType: deal.renterType,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                        if (!isCommercialItem(deal.renterType, deal.unitLabel, deal.currentUnitId)) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _actionTile(
                                  context,
                                  icon: Icons.badge_outlined,
                                  iconColor: const Color(0xFF059669),
                                  title: 'Gate Pass',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => GatePassScreen(deal: deal)),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _actionTile(
                                  context,
                                  icon: Icons.bolt_outlined,
                                  iconColor: const Color(0xFFD97706),
                                  title: 'Sub-Meter Bills',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => UtilityBillsScreen(deal: deal)),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _actionTile(
                                  context,
                                  icon: Icons.sensor_door_outlined,
                                  iconColor: const Color(0xFF7C3AED),
                                  title: 'Visitor Entry',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => VisitorPreapproveScreen(deal: deal)),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _actionTile(
                                  context,
                                  icon: Icons.restaurant_menu_outlined,
                                  iconColor: const Color(0xFF0891B2),
                                  title: 'Mess Menu',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => MessMenuScreen(deal: deal)),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _actionTile(
                                context,
                                icon: Icons.picture_as_pdf_outlined,
                                iconColor: const Color(0xFFE11D48),
                                title: AppLocalization.tr('agreement'),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => AgreementViewerScreen(deal: deal)),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    },
  );
  },
);
}

  Widget _buildPrimaryStatusCard(BuildContext context, DealModel deal, PaymentRecordModel? rec) {
    if (deal.status == 'ended') {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF334155),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.goldAccent),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cancel_outlined, color: AppTheme.goldAccent, size: 28),
                SizedBox(width: 8),
                Text(
                  'Lease Agreement Ended',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              'This lease deal has been closed by the property owner. Read-only mode active: you can view past ledger entries and agreement history below.',
              style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 14, height: 1.4),
            ),
          ],
        ),
      );
    }

    if (rec == null) {
      return const SizedBox.shrink();
    }

    final monthIndex = RentEngine.getMonthIndex(deal.dealStartDate, DateTime.now());
    final isAdvance = RentEngine.getPaymentSource(deal, monthIndex) == 'advance';
    final remainingAdvance = RentEngine.getRunningAdvanceBalance(deal, DateTime.now());

    Widget statusWidget;

    if (isAdvance || rec.status == 'adjusted-against-advance') {
      statusWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '₹0 due this month',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Adjusted against your advance (₹${remainingAdvance.toStringAsFixed(0)} of ₹${deal.totalAdvanceAmount.toStringAsFixed(0)} advance remaining).',
            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 16, height: 1.4, fontWeight: FontWeight.w500),
          ),
        ],
      );
    } else if (rec.status == 'confirmed-paid') {
      statusWidget = const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.lightGreenAccent, size: 30),
              SizedBox(width: 10),
              Text(
                'This month is settled.',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Your payment has been verified and confirmed by the property owner.',
            style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      );
    } else if (rec.status == 'pending-confirmation') {
      statusWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Waiting for owner to confirm',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amberAccent),
          ),
          const SizedBox(height: 6),
          Text(
            'You reported payment of ₹${rec.amountPaidByRenter.toStringAsFixed(0)} via ${rec.paymentMethod?.toUpperCase()}.',
            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 16, fontWeight: FontWeight.w500),
          ),
          if (rec.amountPending > 0) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryNavy,
                minimumSize: const Size(double.infinity, 46),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportPaymentScreen(record: rec, deal: deal),
                  ),
                );
              },
              icon: const Icon(Icons.add_card, size: 20),
              label: const Text('Report Another Installment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ],
      );
    } else if (rec.status == 'confirmed-partial') {
      statusWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '₹${rec.amountPaidByRenter.toStringAsFixed(0)} confirmed, ₹${rec.amountPending.toStringAsFixed(0)} still pending',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
          ),
          const SizedBox(height: 6),
          const Text('Pending amount can be paid in further installments.', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 15, fontWeight: FontWeight.w500)),
          if (rec.amountPending > 0) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryNavy,
                minimumSize: const Size(double.infinity, 46),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportPaymentScreen(record: rec, deal: deal),
                  ),
                );
              },
              icon: const Icon(Icons.payment, size: 20),
              label: const Text('Report Remaining Installment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ],
      );
    } else {
      // Direct payment due
      final dueDay = deal.rentDueDayOfMonth;
      final suffixes = ['th', 'st', 'nd', 'rd'];
      final suffix = (dueDay >= 11 && dueDay <= 13) ? 'th' : (dueDay % 10 < 4 ? suffixes[dueDay % 10] : 'th');
      statusWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '₹${rec.dueFromRenter.toStringAsFixed(0)} due this month',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text('Period: ${rec.periodMonth} • Due by $dueDay$suffix', style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 16, fontWeight: FontWeight.w600)),
          if (rec.carriedOverDue > 0) ...[
            const SizedBox(height: 4),
            Text(
              '(+ ₹${rec.carriedOverDue.toStringAsFixed(0)} past arrears pending)',
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryNavy,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportPaymentScreen(record: rec, deal: deal),
                ),
              );
            },
            icon: const Icon(Icons.payment, size: 22),
            label: Text(AppLocalization.tr('report_payment'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryNavy, Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(38),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: statusWidget,
    );
  }

  Widget _actionTile(BuildContext context, {required IconData icon, Color? iconColor, required String title, required VoidCallback onTap}) {
    final effectiveColor = iconColor ?? AppTheme.primaryTeal;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: effectiveColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: effectiveColor),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
