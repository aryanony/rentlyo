import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/localization.dart';
import '../models/maintenance_request_model.dart';
import '../models/unit_model.dart';
import '../models/deal_model.dart';
import '../services/firestore_service.dart';

class MaintenanceManagementScreen extends StatefulWidget {
  final String propertyId;

  const MaintenanceManagementScreen({super.key, required this.propertyId});

  @override
  State<MaintenanceManagementScreen> createState() => _MaintenanceManagementScreenState();
}

class _MaintenanceManagementScreenState extends State<MaintenanceManagementScreen> {
  final _firestore = FirestoreService();
  String _selectedFilter = 'all';

  String _resolveUnitLabel(
    MaintenanceRequestModel ticket,
    Map<String, UnitModel> unitsMap,
    Map<String, DealModel> dealsMap,
  ) {
    final raw = ticket.unitId.trim();

    // 1. If it matches a known unit in the property
    if (unitsMap.containsKey(raw)) {
      final u = unitsMap[raw]!;
      return '${u.label} • ${u.floor}';
    }

    // 2. Check if a unit's label itself is the raw string
    for (var u in unitsMap.values) {
      if (u.label.toLowerCase() == raw.toLowerCase() || raw.toLowerCase().contains(u.label.toLowerCase())) {
        return '${u.label} • ${u.floor}';
      }
    }

    // 3. If it matches a deal's ID or unit assignment
    for (var d in dealsMap.values) {
      if (d.id == raw ||
          d.currentUnitId == raw ||
          d.renterId == ticket.renterId ||
          d.renterId == ticket.renterUid ||
          d.containsUnit(raw)) {
        if (unitsMap.containsKey(d.currentUnitId)) {
          final u = unitsMap[d.currentUnitId]!;
          return '${u.label} • ${u.floor}';
        }
        final display = d.displayMultiUnitLabel.trim();
        if (display.isNotEmpty && display.toLowerCase() != 'unit' && !display.startsWith('unit_')) {
          return display;
        }
      }
    }

    // 4. If raw is already clean & human-readable (e.g. "G1", "Shop 101", "Flat 4B")
    if (raw.isNotEmpty && raw.length <= 15 && !raw.startsWith('unit_') && !RegExp(r'^[a-zA-Z0-9]{18,}$').hasMatch(raw)) {
      return raw.startsWith('Unit') ? raw : 'Unit $raw';
    }

    return 'Unit';
  }

  String _resolveRenterName(
    MaintenanceRequestModel ticket,
    Map<String, DealModel> dealsMap,
  ) {
    final rawName = ticket.renterName.trim();
    if (rawName.isNotEmpty &&
        rawName.toLowerCase() != 'tenant' &&
        rawName.toLowerCase() != 'resident' &&
        rawName.toLowerCase() != 'user') {
      return rawName;
    }

    // Lookup through active deals for this renter or unit
    for (var d in dealsMap.values) {
      if (d.renterId == ticket.renterId ||
          d.renterId == ticket.renterUid ||
          d.currentUnitId == ticket.unitId ||
          d.id == ticket.unitId) {
        if (d.businessName != null && d.businessName!.trim().isNotEmpty) {
          return d.businessName!.trim();
        }
      }
    }

    return rawName.isNotEmpty ? rawName : 'Resident';
  }

  void _showUpdateDialog(MaintenanceRequestModel ticket) {
    final noteController = TextEditingController(text: ticket.adminNote ?? '');
    String selectedStatus = ticket.status;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: AppTheme.primaryTeal, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ticket.unitId.isNotEmpty
                          ? 'Update Ticket #${ticket.unitId}'
                          : 'Update Ticket',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                      'Update Status:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'open', child: Text('Open')),
                        DropdownMenuItem(value: 'in-progress', child: Text('In Progress')),
                        DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                        DropdownMenuItem(value: 'closed', child: Text('Closed')),
                      ],
                      onChanged: isSaving ? null : (val) => setDialogState(() => selectedStatus = val!),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Note for Tenant:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      enabled: !isSaving,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'e.g. Electrician scheduled for tomorrow 10 AM',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: Text(AppLocalization.tr('cancel')),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          try {
                            await _firestore.updateMaintenanceStatus(
                              ticket.id,
                              selectedStatus,
                              noteController.text.trim(),
                              ticket: ticket,
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Ticket status updated successfully!')),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setDialogState(() => isSaving = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Failed to update: $e')),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Update Status'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String filterKey, String label, int count) {
    final isSelected = _selectedFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        label: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.primaryNavy,
          ),
        ),
        backgroundColor: Colors.white,
        selectedColor: AppTheme.primaryNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppTheme.primaryNavy : const Color(0xFFCBD5E1),
          ),
        ),
        onSelected: (_) {
          setState(() {
            _selectedFilter = filterKey;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocalization.currentLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalization.tr('maintenance_manager')),
          ),
          body: StreamBuilder<List<UnitModel>>(
            stream: _firestore.streamUnits(widget.propertyId),
            builder: (context, unitsSnapshot) {
              final unitsList = unitsSnapshot.data ?? [];
              final unitsMap = {for (var u in unitsList) u.id: u};

              return StreamBuilder<List<DealModel>>(
                stream: _firestore.streamDeals(widget.propertyId),
                builder: (context, dealsSnapshot) {
                  final dealsList = dealsSnapshot.data ?? [];
                  final dealsMap = {for (var d in dealsList) d.id: d};

                  return StreamBuilder<List<MaintenanceRequestModel>>(
                    stream: _firestore.streamPropertyMaintenanceRequests(widget.propertyId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allTickets = snapshot.data ?? [];

                      if (allTickets.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryTeal.withAlpha(20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_circle_outline, size: 64, color: AppTheme.primaryTeal),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No maintenance tickets',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Tenant repair requests will appear here in real-time.',
                                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final filteredTickets = allTickets.where((t) {
                        if (_selectedFilter == 'all') return true;
                        return t.status.toLowerCase() == _selectedFilter;
                      }).toList();

                      final openCount = allTickets.where((t) => t.status == 'open').length;
                      final inProgressCount = allTickets.where((t) => t.status == 'in-progress').length;
                      final resolvedCount = allTickets.where((t) => t.status == 'resolved').length;
                      final closedCount = allTickets.where((t) => t.status == 'closed').length;

                      return Column(
                        children: [
                          // Filter Chips Bar
                          Container(
                            width: double.infinity,
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip('all', 'All', allTickets.length),
                                  _buildFilterChip('open', 'Open', openCount),
                                  _buildFilterChip('in-progress', 'In Progress', inProgressCount),
                                  _buildFilterChip('resolved', 'Resolved', resolvedCount),
                                  _buildFilterChip('closed', 'Closed', closedCount),
                                ],
                              ),
                            ),
                          ),

                          // Tickets List
                          Expanded(
                            child: filteredTickets.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Text(
                                        'No tickets found in "${_selectedFilter.toUpperCase()}".',
                                        style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                    itemCount: filteredTickets.length,
                                    itemBuilder: (context, index) {
                                      final ticket = filteredTickets[index];
                                      final displayUnit = _resolveUnitLabel(ticket, unitsMap, dealsMap);
                                      final displayName = _resolveRenterName(ticket, dealsMap);

                                      Color statusColor;
                                      String statusLabel;
                                      IconData statusIcon;
                                      switch (ticket.status.toLowerCase()) {
                                        case 'in-progress':
                                          statusColor = AppTheme.statusYellow;
                                          statusLabel = 'IN-PROGRESS';
                                          statusIcon = Icons.hourglass_top_rounded;
                                          break;
                                        case 'resolved':
                                          statusColor = AppTheme.statusGreen;
                                          statusLabel = 'RESOLVED';
                                          statusIcon = Icons.check_circle_rounded;
                                          break;
                                        case 'closed':
                                          statusColor = AppTheme.statusGrey;
                                          statusLabel = 'CLOSED';
                                          statusIcon = Icons.cancel_outlined;
                                          break;
                                        default:
                                          statusColor = AppTheme.statusOrange;
                                          statusLabel = 'OPEN';
                                          statusIcon = Icons.error_outline_rounded;
                                      }

                                      final isEmergency = ticket.priority.toLowerCase() == 'emergency';
                                      final isHigh = ticket.priority.toLowerCase() == 'high';

                                      return Card(
                                        elevation: 2,
                                        margin: const EdgeInsets.only(bottom: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: BorderSide(
                                            color: statusColor.withAlpha(50),
                                            width: 1,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Top Row: Badges (Left) + Edit Button (Right)
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    child: Wrap(
                                                      spacing: 8,
                                                      runSpacing: 6,
                                                      crossAxisAlignment: WrapCrossAlignment.center,
                                                      children: [
                                                        // Status Badge
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: statusColor.withAlpha(25),
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(color: statusColor, width: 1.2),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(statusIcon, size: 13, color: statusColor),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                statusLabel,
                                                                style: TextStyle(
                                                                  color: statusColor,
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 12,
                                                                  letterSpacing: 0.3,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),

                                                        // Priority Badge
                                                        if (isEmergency || isHigh)
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: (isEmergency ? AppTheme.statusRed : AppTheme.statusOrange).withAlpha(25),
                                                              borderRadius: BorderRadius.circular(8),
                                                              border: Border.all(
                                                                color: isEmergency ? AppTheme.statusRed : AppTheme.statusOrange,
                                                                width: 1.2,
                                                              ),
                                                            ),
                                                            child: Text(
                                                              ticket.priority.toUpperCase(),
                                                              style: TextStyle(
                                                                color: isEmergency ? AppTheme.statusRed : AppTheme.statusOrange,
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 11,
                                                              ),
                                                            ),
                                                          ),

                                                        // Category Badge
                                                        if (ticket.category.isNotEmpty && ticket.category.toLowerCase() != 'general')
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: AppTheme.primaryNavy.withAlpha(12),
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Text(
                                                              ticket.category.toUpperCase(),
                                                              style: const TextStyle(
                                                                color: AppTheme.primaryNavy,
                                                                fontWeight: FontWeight.w600,
                                                                fontSize: 11,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Edit / Update Action Button
                                                  Material(
                                                    color: AppTheme.primaryTeal.withAlpha(20),
                                                    borderRadius: BorderRadius.circular(10),
                                                    child: InkWell(
                                                      borderRadius: BorderRadius.circular(10),
                                                      onTap: () => _showUpdateDialog(ticket),
                                                      child: const Padding(
                                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.edit_outlined, size: 16, color: AppTheme.primaryTeal),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'Edit',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight: FontWeight.bold,
                                                                color: AppTheme.primaryTeal,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              const SizedBox(height: 12),

                                              // Renter Info Container
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 16,
                                                      backgroundColor: AppTheme.primaryNavy,
                                                      child: Text(
                                                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'R',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
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
                                                            displayName,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 15,
                                                              color: AppTheme.primaryNavy,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          if (ticket.renterPhone.isNotEmpty)
                                                            Text(
                                                              ticket.renterPhone,
                                                              style: const TextStyle(
                                                                fontSize: 12,
                                                                color: Color(0xFF64748B),
                                                                fontWeight: FontWeight.w500,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.primaryNavy.withAlpha(15),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: AppTheme.primaryNavy.withAlpha(30)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.storefront_outlined, size: 14, color: AppTheme.primaryNavy),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            displayUnit,
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppTheme.primaryNavy,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (ticket.renterPhone.isNotEmpty) ...[
                                                      const SizedBox(width: 4),
                                                      IconButton(
                                                        icon: const Icon(Icons.phone_outlined, size: 20, color: AppTheme.primaryTeal),
                                                        tooltip: 'Call Resident',
                                                        visualDensity: VisualDensity.compact,
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                        onPressed: () async {
                                                          final uri = Uri.parse('tel:${ticket.renterPhone}');
                                                          if (await canLaunchUrl(uri)) {
                                                            await launchUrl(uri);
                                                          }
                                                        },
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),

                                              const SizedBox(height: 12),

                                              // Ticket Title
                                              Text(
                                                ticket.title,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryNavy,
                                                ),
                                              ),
                                              const SizedBox(height: 4),

                                              // Ticket Description
                                              Text(
                                                ticket.description,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFF334155),
                                                  height: 1.4,
                                                ),
                                              ),

                                              // Admin Note
                                              if (ticket.adminNote != null && ticket.adminNote!.trim().isNotEmpty) ...[
                                                const SizedBox(height: 12),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryTeal.withAlpha(12),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: AppTheme.primaryTeal.withAlpha(35)),
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Icon(Icons.admin_panel_settings_outlined, size: 18, color: AppTheme.primaryTeal),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            const Text(
                                                              'Admin Note:',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.bold,
                                                                color: AppTheme.primaryTeal,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              ticket.adminNote!,
                                                              style: const TextStyle(
                                                                fontSize: 13,
                                                                color: AppTheme.primaryNavy,
                                                                height: 1.3,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],

                                              const SizedBox(height: 10),

                                              // Footer with timestamp
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    DateFormat('dd MMM yyyy, hh:mm a').format(ticket.createdAt),
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
