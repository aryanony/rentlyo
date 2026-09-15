import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/localization.dart';
import '../models/notice_model.dart';
import '../services/firestore_service.dart';

class NoticesScreen extends StatelessWidget {
  final String propertyId;
  final String? renterType;

  const NoticesScreen({super.key, required this.propertyId, this.renterType});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return ValueListenableBuilder<String>(
      valueListenable: AppLocalization.currentLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalization.tr('notices')),
          ),
          body: StreamBuilder<List<NoticeModel>>(
            stream: firestore.streamPropertyNotices(propertyId, renterType: renterType),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final notices = snapshot.data ?? [];

              if (notices.isEmpty) {
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
                        child: const Icon(Icons.campaign_outlined, size: 64, color: AppTheme.primaryTeal),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No announcements yet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Official property notices will appear here.',
                        style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notices.length,
                itemBuilder: (context, index) {
                  final notice = notices[index];

                  IconData typeIcon;
                  Color iconColor;
                  switch (notice.type) {
                    case 'maintenance':
                      typeIcon = Icons.build_outlined;
                      iconColor = AppTheme.statusOrange;
                      break;
                    case 'warning':
                      typeIcon = Icons.warning_amber_outlined;
                      iconColor = AppTheme.statusRed;
                      break;
                    case 'event':
                      typeIcon = Icons.event_outlined;
                      iconColor = AppTheme.statusGreen;
                      break;
                    default:
                      typeIcon = Icons.campaign_outlined;
                      iconColor = AppTheme.primaryTeal;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: iconColor.withAlpha(25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(typeIcon, color: iconColor, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notice.postedBy,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryTeal,
                                      ),
                                    ),
                                    Text(
                                      '${notice.postedAt.day}/${notice.postedAt.month}/${notice.postedAt.year}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            notice.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            notice.message,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF334155),
                              height: 1.5,
                            ),
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
