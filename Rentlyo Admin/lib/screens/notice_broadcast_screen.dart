import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/localization.dart';
import '../models/notice_model.dart';
import '../services/firestore_service.dart';
import '../core/brand_config.dart';
import '../core/app_config.dart';

class NoticeBroadcastScreen extends StatefulWidget {
  final String propertyId;

  const NoticeBroadcastScreen({super.key, required this.propertyId});

  @override
  State<NoticeBroadcastScreen> createState() => _NoticeBroadcastScreenState();
}

class _NoticeBroadcastScreenState extends State<NoticeBroadcastScreen> {
  final _firestore = FirestoreService();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedType = 'announcement';
  String _selectedAudience = 'all';
  bool _isPublishing = false;

  Future<void> _publishNotice() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out both notice title and message.')),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final propId = widget.propertyId.isNotEmpty ? widget.propertyId : AppConfig.defaultPropertyId;
      final notice = NoticeModel(
        id: '',
        propertyId: propId,
        title: title,
        message: message,
        type: _selectedType,
        postedBy: '${BrandConfig.brandName} Management',
        postedAt: DateTime.now(),
        targetAudience: _selectedAudience,
      );

      await _firestore.createNotice(notice);

      if (mounted) {
        _titleController.clear();
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalization.tr('notice_published'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Publishing failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  void _confirmDeleteNotice(NoticeModel notice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retract Announcement'),
        content: Text('Are you sure you want to delete notice "${notice.title}"? It will be removed from tenant dashboards.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.statusRed),
            onPressed: () async {
              await _firestore.deleteNotice(notice.id);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Notice deleted successfully.')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
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
            title: Text(AppLocalization.tr('dispatch_notice')),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.campaign_outlined, color: AppTheme.primaryTeal, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Property Notice Broadcast',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Broadcast instant announcements to all tenant dashboards',
                              style: TextStyle(fontSize: 13, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  AppLocalization.tr('notice_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(hintText: 'e.g. Scheduled Water Tank Cleaning / Diwali Greetings'),
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notice Type',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedType,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'announcement', child: Text('General Announcement', style: TextStyle(fontSize: 13.5), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'maintenance', child: Text('Maintenance Alert', style: TextStyle(fontSize: 13.5), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'warning', child: Text('Important / Warning', style: TextStyle(fontSize: 13.5), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'event', child: Text('Festive / Event', style: TextStyle(fontSize: 13.5), overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (val) => setState(() => _selectedType = val!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Target Audience',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedAudience,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Tenants', style: TextStyle(fontSize: 13.5), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'commercial', child: Text('Commercial Only', style: TextStyle(fontSize: 13.5), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'residential', child: Text('Residential Only', style: TextStyle(fontSize: 13.5), overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (val) => setState(() => _selectedAudience = val!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                Text(
                  AppLocalization.tr('notice_message'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Write the complete notice message to be displayed to tenants...',
                  ),
                ),
                const SizedBox(height: 28),

                ElevatedButton.icon(
                  onPressed: _isPublishing ? null : _publishNotice,
                  icon: _isPublishing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(AppLocalization.tr('publish_notice')),
                ),
                const SizedBox(height: 32),

                const Text(
                  'Recent Published Notices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                ),
                const SizedBox(height: 12),

                StreamBuilder<List<NoticeModel>>(
                  stream: _firestore.streamPropertyNotices(widget.propertyId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final notices = snapshot.data ?? [];

                    if (notices.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text('No notices published yet.')),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: notices.length,
                      itemBuilder: (context, index) {
                        final notice = notices[index];
                        final audienceLabel = notice.targetAudience == 'commercial'
                            ? 'Commercial'
                            : (notice.targetAudience == 'residential' ? 'Residential' : 'All');

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.campaign, color: AppTheme.primaryTeal, size: 22),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        notice.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryNavy.withAlpha(15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        audienceLabel,
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  notice.message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${notice.postedAt.day}/${notice.postedAt.month}/${notice.postedAt.year}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    InkWell(
                                      onTap: () => _confirmDeleteNotice(notice),
                                      borderRadius: BorderRadius.circular(6),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.delete_outline, color: AppTheme.statusRed, size: 20),
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
              ],
            ),
          ),
        );
      },
    );
  }
}
