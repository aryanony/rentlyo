import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/localization.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';

class NotificationsScreen extends StatefulWidget {
  final String userUid;

  const NotificationsScreen({super.key, required this.userUid});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirestoreService _firestore = FirestoreService();
  String _selectedFilter = 'all'; // 'all', 'unread', 'read', 'payment', 'rent', 'maintenance', 'notice'

  @override
  void initState() {
    super.initState();
    // Run automated background cleanup of obsolete duplicates
    _firestore.cleanupDuplicateNotifications(widget.userUid);
  }

  void _markAllAsRead(int unreadCount) async {
    if (unreadCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unread notifications to mark.')),
      );
      return;
    }

    await _firestore.markAllNotificationsAsRead(widget.userUid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$unreadCount notification${unreadCount > 1 ? 's' : ''} marked as read.'),
          backgroundColor: AppTheme.statusGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _clearReadNotifications(int readCount) async {
    if (readCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No read notifications to clear.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_outlined, color: AppTheme.statusRed),
            SizedBox(width: 8),
            Text('Clear Read Notifications?'),
          ],
        ),
        content: Text(
          'This will permanently remove $readCount read notification${readCount > 1 ? 's' : ''} from your drawer.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalization.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All Read'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final cleared = await _firestore.clearAllReadNotifications(widget.userUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleared $cleared read notification${cleared > 1 ? 's' : ''}.'),
            backgroundColor: AppTheme.primaryNavy,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24 && now.day == dt.day) {
      return 'Today at ${DateFormat('hh:mm a').format(dt)}';
    } else if (difference.inDays < 2 && now.subtract(const Duration(days: 1)).day == dt.day) {
      return 'Yesterday at ${DateFormat('hh:mm a').format(dt)}';
    } else {
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    }
  }

  Widget _buildFilterChip(String key, String label, int count, {bool hasUnreadBadge = false}) {
    final isSelected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        avatar: hasUnreadBadge && count > 0
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.statusRed,
                  shape: BoxShape.circle,
                ),
              )
            : null,
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
            _selectedFilter = key;
          });
        },
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'payment-confirmed':
        return Icons.verified_rounded;
      case 'payment-request':
        return Icons.receipt_long_rounded;
      case 'rent-cycle-start':
        return Icons.calendar_month_rounded;
      case 'rent-overdue-warning':
        return Icons.warning_amber_rounded;
      case 'maintenance':
      case 'maintenance-updated':
      case 'maintenance-submitted':
        return Icons.build_circle_rounded;
      case 'notice':
      case 'notice-broadcast':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _colorForNotification(NotificationModel n) {
    final type = n.type.toLowerCase();
    final priority = n.priority.toLowerCase();

    if (type == 'rent-overdue-warning' || priority == 'urgent' || priority == 'warning') {
      return AppTheme.statusRed;
    }
    if (type == 'payment-confirmed') {
      return AppTheme.statusGreen;
    }
    if (type == 'rent-cycle-start' || priority == 'gentle') {
      return const Color(0xFF0D9488);
    }
    if (type.contains('maintenance')) {
      return AppTheme.primaryNavy;
    }
    if (type.contains('notice')) {
      return const Color(0xFF7C3AED); // Purple
    }
    return const Color(0xFF2563EB); // Blue
  }

  String _categoryLabel(String type) {
    switch (type.toLowerCase()) {
      case 'payment-confirmed':
        return 'PAYMENT CONFIRMED';
      case 'payment-request':
        return 'PAYMENT UPDATE';
      case 'rent-cycle-start':
        return 'RENT CYCLE';
      case 'rent-overdue-warning':
        return 'OVERDUE ALERT';
      case 'maintenance':
      case 'maintenance-updated':
      case 'maintenance-submitted':
        return 'MAINTENANCE';
      case 'notice':
      case 'notice-broadcast':
        return 'ANNOUNCEMENT';
      default:
        return 'UPDATE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocalization.currentLanguage,
      builder: (context, lang, _) {
        return StreamBuilder<List<NotificationModel>>(
          stream: _firestore.streamNotifications(widget.userUid),
          builder: (context, snapshot) {
            final rawList = snapshot.data ?? [];

            // In-memory deduplication fallback
            final allNotifications = <NotificationModel>[];
            final seenKeys = <String>{};
            for (var n in rawList) {
              final key = "${n.type}_${n.title}_${n.message}_${n.createdAt.day}_${n.createdAt.hour}";
              if (!seenKeys.contains(key)) {
                seenKeys.add(key);
                allNotifications.add(n);
              }
            }

            final unreadList = allNotifications.where((n) => !n.read).toList();
            final readList = allNotifications.where((n) => n.read).toList();

            final filteredList = allNotifications.where((n) {
              if (_selectedFilter == 'unread') return !n.read;
              if (_selectedFilter == 'read') return n.read;
              if (_selectedFilter == 'payment') {
                return n.type.contains('payment');
              }
              if (_selectedFilter == 'rent') {
                return n.type.contains('rent');
              }
              if (_selectedFilter == 'maintenance') {
                return n.type.contains('maintenance');
              }
              if (_selectedFilter == 'notice') {
                return n.type.contains('notice');
              }
              return true;
            }).toList();

            return Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    Text(AppLocalization.tr('notifications')),
                    if (unreadList.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.statusRed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${unreadList.length} new',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  if (unreadList.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.done_all_rounded),
                      tooltip: 'Mark all as read',
                      onPressed: () => _markAllAsRead(unreadList.length),
                    ),
                  if (readList.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined),
                      tooltip: 'Clear read notifications',
                      onPressed: () => _clearReadNotifications(readList.length),
                    ),
                ],
              ),
              body: allNotifications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTeal.withAlpha(20),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                size: 64,
                                color: AppTheme.primaryTeal,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              "All Caught Up!",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "You don't have any notifications right now.\nNew dues, payments, and property notices will appear here.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // Filter Chips Bar
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('all', 'All', allNotifications.length),
                                _buildFilterChip('unread', 'Unread', unreadList.length, hasUnreadBadge: true),
                                _buildFilterChip('read', 'Read', readList.length),
                                _buildFilterChip(
                                  'payment',
                                  'Payments',
                                  allNotifications.where((n) => n.type.contains('payment')).length,
                                ),
                                _buildFilterChip(
                                  'rent',
                                  'Rent Cycle',
                                  allNotifications.where((n) => n.type.contains('rent')).length,
                                ),
                                _buildFilterChip(
                                  'maintenance',
                                  'Maintenance',
                                  allNotifications.where((n) => n.type.contains('maintenance')).length,
                                ),
                                _buildFilterChip(
                                  'notice',
                                  'Notices',
                                  allNotifications.where((n) => n.type.contains('notice')).length,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Action Helper Subtitle
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing ${filteredList.length} notification${filteredList.length == 1 ? '' : 's'}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                              ),
                              const Text(
                                'Swipe card to delete',
                                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Notification List
                        Expanded(
                          child: filteredList.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.filter_list_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No notifications found in "${_selectedFilter.toUpperCase()}".',
                                          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 12),
                                        TextButton(
                                          onPressed: () => setState(() => _selectedFilter = 'all'),
                                          child: const Text('View All Notifications'),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                  itemCount: filteredList.length,
                                  itemBuilder: (context, index) {
                                    final n = filteredList[index];
                                    final isUnread = !n.read;
                                    final color = _colorForNotification(n);

                                    return Dismissible(
                                      key: Key(n.id.isNotEmpty ? n.id : '${n.type}_$index'),
                                      direction: DismissDirection.horizontal,
                                      background: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.statusRed,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.delete_outline, color: Colors.white, size: 24),
                                            SizedBox(width: 8),
                                            Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      secondaryBackground: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.statusRed,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.delete_outline, color: Colors.white, size: 24),
                                          ],
                                        ),
                                      ),
                                      onDismissed: (_) {
                                        _firestore.deleteNotification(n.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Notification deleted.'),
                                            duration: Duration(seconds: 2),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                      child: Card(
                                        elevation: isUnread ? 3 : 1,
                                        margin: const EdgeInsets.only(bottom: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: BorderSide(
                                            color: isUnread ? color.withAlpha(90) : const Color(0xFFE2E8F0),
                                            width: isUnread ? 1.5 : 1,
                                          ),
                                        ),
                                        color: isUnread ? color.withAlpha(10) : Colors.white,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(16),
                                          onTap: () {
                                            if (isUnread) {
                                              _firestore.markNotificationAsRead(n.id);
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(14),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Header row: Category Avatar + Category Pill + Timestamp + Unread Dot
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 16,
                                                      backgroundColor: color.withAlpha(30),
                                                      child: Icon(
                                                        _iconForType(n.type),
                                                        color: color,
                                                        size: 18,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: color.withAlpha(25),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: color.withAlpha(60)),
                                                      ),
                                                      child: Text(
                                                        _categoryLabel(n.type),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: color,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isUnread) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.statusRed,
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: const Text(
                                                          'NEW',
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    const Spacer(),
                                                    Text(
                                                      _formatTimestamp(n.createdAt),
                                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                                    ),
                                                  ],
                                                ),

                                                const SizedBox(height: 10),

                                                // Title
                                                Text(
                                                  n.title.isNotEmpty ? n.title : _categoryLabel(n.type),
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                                    color: AppTheme.primaryNavy,
                                                  ),
                                                ),

                                                const SizedBox(height: 4),

                                                // Message Body
                                                Text(
                                                  n.message,
                                                  style: TextStyle(
                                                    fontSize: 13.5,
                                                    color: isUnread ? const Color(0xFF1E293B) : const Color(0xFF475569),
                                                    height: 1.4,
                                                    fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                                                  ),
                                                ),

                                                const SizedBox(height: 10),

                                                // Footer Actions Row
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    if (isUnread)
                                                      TextButton.icon(
                                                        style: TextButton.styleFrom(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          minimumSize: Size.zero,
                                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                        ),
                                                        onPressed: () => _firestore.markNotificationAsRead(n.id),
                                                        icon: const Icon(Icons.check_rounded, size: 14, color: AppTheme.primaryTeal),
                                                        label: const Text(
                                                          'Mark Read',
                                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                                                        ),
                                                      )
                                                    else
                                                      TextButton.icon(
                                                        style: TextButton.styleFrom(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          minimumSize: Size.zero,
                                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                        ),
                                                        onPressed: () => _firestore.markNotificationAsRead(n.id, read: false),
                                                        icon: const Icon(Icons.mark_email_unread_outlined, size: 14, color: Color(0xFF64748B)),
                                                        label: const Text(
                                                          'Mark Unread',
                                                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                        ),
                                                      ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                                                      tooltip: 'Delete',
                                                      visualDensity: VisualDensity.compact,
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                      onPressed: () {
                                                        _firestore.deleteNotification(n.id);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}
