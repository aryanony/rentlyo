import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/localization.dart';
import '../models/deal_model.dart';

class AgreementViewerScreen extends StatelessWidget {
  final DealModel deal;

  const AgreementViewerScreen({super.key, required this.deal});

  Future<void> _openUrl(String link) async {
    final Uri url = Uri.parse(link);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base64Str = deal.agreementFileBase64;
    final driveLink = deal.agreementDriveLink;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalization.tr('agreement')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (driveLink != null && driveLink.isNotEmpty) ...[
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
                      'Google Drive Rent Agreement Link',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap below to open your agreement document directly in Google Drive.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.goldAccent,
                        foregroundColor: AppTheme.primaryNavy,
                      ),
                      onPressed: () => _openUrl(driveLink),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open Google Drive Agreement', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (base64Str != null && base64Str.isNotEmpty)
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(base64Decode(base64Str), fit: BoxFit.contain),
                ),
              )
            else if (driveLink == null || driveLink.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No scanned agreement document uploaded yet.\nYour property owner will attach a copy soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
