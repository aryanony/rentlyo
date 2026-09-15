import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/app_config.dart';
import '../core/localization.dart';
import '../models/maintenance_request_model.dart';
import '../models/deal_model.dart';
import '../services/firestore_service.dart';

class MaintenanceScreen extends StatefulWidget {
  final DealModel deal;

  const MaintenanceScreen({super.key, required this.deal});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _firestore = FirestoreService();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'general';
  String _selectedPriority = 'medium';
  bool _isSubmitting = false;

  Future<void> _submitRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out both subject and description.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userDoc = await _firestore.streamUser(user.uid).first;
      String renterName = (userDoc?.name ?? '').trim();
      if (renterName.isEmpty) {
        renterName = (user.displayName ?? '').trim();
      }
      if (renterName.isEmpty && widget.deal.businessName != null && widget.deal.businessName!.trim().isNotEmpty) {
        renterName = widget.deal.businessName!.trim();
      }
      if (renterName.isEmpty) {
        renterName = 'Resident';
      }

      final renterPhone = (userDoc?.phone ?? '').isNotEmpty ? userDoc!.phone : (user.phoneNumber ?? '');
      final propId = widget.deal.propertyId.isNotEmpty ? widget.deal.propertyId : AppConfig.defaultPropertyId;

      // Clean human-friendly unit label (e.g. "G1", "Shop 101", "Flat 4B")
      String uLabel = widget.deal.displayMultiUnitLabel.trim();
      if (uLabel.isEmpty || uLabel.toLowerCase() == 'unit' || (uLabel.length > 20 && !uLabel.contains(' '))) {
        uLabel = (widget.deal.unitLabel ?? widget.deal.displayUnitCode).trim();
      }
      if (uLabel.isEmpty) {
        uLabel = widget.deal.currentUnitId;
      }

      final request = MaintenanceRequestModel(
        id: '',
        propertyId: propId,
        unitId: uLabel,
        renterUid: user.uid,
        renterId: widget.deal.renterId,
        renterName: renterName,
        renterPhone: renterPhone,
        title: title,
        description: desc,
        category: _selectedCategory,
        priority: _selectedPriority,
        status: 'open',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.submitMaintenanceRequest(request);

      if (mounted) {
        _titleController.clear();
        _descController.clear();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalization.tr('ticket_msg'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showNewTicketDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.build_outlined, color: AppTheme.primaryTeal, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalization.tr('report_issue'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Text(
                      AppLocalization.tr('issue_title'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(hintText: 'e.g. Water Tap Leakage / Light Switch Defect'),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      AppLocalization.tr('category'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(),
                      items: const [
                        DropdownMenuItem(value: 'general', child: Text('General')),
                        DropdownMenuItem(value: 'plumbing', child: Text('Plumbing / Water')),
                        DropdownMenuItem(value: 'electrical', child: Text('Electrical / Power')),
                        DropdownMenuItem(value: 'structural', child: Text('Doors / Windows / Wall')),
                        DropdownMenuItem(value: 'cleaning', child: Text('Cleaning / Sanitation')),
                      ],
                      onChanged: (val) => setModalState(() => _selectedCategory = val!),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      AppLocalization.tr('priority'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPriority,
                      decoration: const InputDecoration(),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(value: 'medium', child: Text('Normal')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(value: 'emergency', child: Text('Emergency')),
                      ],
                      onChanged: (val) => setModalState(() => _selectedPriority = val!),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      AppLocalization.tr('description'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(hintText: 'Describe the issue clearly...'),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitRequest,
                      icon: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_outlined),
                      label: Text(AppLocalization.tr('submit_ticket')),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ValueListenableBuilder<String>(
      valueListenable: AppLocalization.currentLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalization.tr('maintenance')),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppTheme.primaryTeal,
            onPressed: _showNewTicketDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              AppLocalization.tr('report_issue'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          body: user == null
              ? const Center(child: Text('Session expired'))
              : StreamBuilder<List<MaintenanceRequestModel>>(
                  stream: _firestore.streamRenterMaintenanceRequests(user.uid, widget.deal.renterId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final tickets = snapshot.data ?? [];

                    if (tickets.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTeal.withAlpha(20),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.build_circle_outlined, size: 64, color: AppTheme.primaryTeal),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No active maintenance tickets',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Tap "+ Report Issue" below if something needs repair.',
                              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: tickets.length,
                      itemBuilder: (context, index) {
                        final ticket = tickets[index];

                        Color statusColor;
                        String statusLabel;
                        switch (ticket.status) {
                          case 'in-progress':
                            statusColor = AppTheme.statusYellow;
                            statusLabel = 'In Progress';
                            break;
                          case 'resolved':
                            statusColor = AppTheme.statusGreen;
                            statusLabel = 'Resolved';
                            break;
                          case 'closed':
                            statusColor = AppTheme.statusGrey;
                            statusLabel = 'Closed';
                            break;
                          default:
                            statusColor = AppTheme.statusOrange;
                            statusLabel = 'Open';
                        }

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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withAlpha(25),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: statusColor, width: 1.2),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                          if (ticket.priority == 'emergency' || ticket.priority == 'high')
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: (ticket.priority == 'emergency' ? AppTheme.statusRed : AppTheme.statusOrange).withAlpha(25),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: ticket.priority == 'emergency' ? AppTheme.statusRed : AppTheme.statusOrange,
                                                  width: 1.2,
                                                ),
                                              ),
                                              child: Text(
                                                ticket.priority.toUpperCase(),
                                                style: TextStyle(
                                                  color: ticket.priority == 'emergency' ? AppTheme.statusRed : AppTheme.statusOrange,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
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
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  ticket.title,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ticket.description,
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
                                ),
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
                                                'Owner Note:',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryTeal,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                ticket.adminNote!,
                                                style: const TextStyle(fontSize: 13, color: AppTheme.primaryNavy, height: 1.3),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Text(
                                  DateFormat('dd MMM yyyy, hh:mm a').format(ticket.createdAt),
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
  }
}
