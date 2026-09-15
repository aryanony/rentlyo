import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/brand_config.dart';
import '../core/localization.dart';
import '../core/local_security.dart';
import '../services/update_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocalization.currentLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          appBar: AppBar(title: Text(AppLocalization.tr('settings'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Production Level Branded Header Card
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryDark, Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppTheme.goldAccent, width: 2.8),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.goldAccent.withAlpha(50),
                            blurRadius: 14,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: BrandConfig.buildLogoWidget(
                          defaultAsset: 'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            BrandConfig.brandName.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.goldAccent,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            BrandConfig.tagline.isNotEmpty ? BrandConfig.tagline : 'Commercial & Residential Complex',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Tenant Companion App • v1.0.0',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.language, color: AppTheme.primaryNavy, size: 30),
                  title: Text(AppLocalization.tr('language'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(lang == 'en' ? 'English (En)' : 'Hindi (हिंदी)'),
                  trailing: Switch(
                    value: lang == 'hi',
                    activeThumbColor: AppTheme.primaryNavy,
                    onChanged: (_) => AppLocalization.toggleLanguage(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.system_update_outlined, color: AppTheme.goldAccent, size: 30),
                  title: Text(AppLocalization.tr('check_for_updates'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: const Text('Check for new version release & changelog'),
                  trailing: const Icon(Icons.refresh, color: AppTheme.primaryNavy),
                  onTap: () {
                    UpdateService.checkForUpdate(context, appId: 'renter', isManual: true);
                  },
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_reset, color: AppTheme.primaryNavy, size: 30),
                  title: Text(AppLocalization.tr('reset_pin'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: const Text('Clear local numeric PIN and set a fresh security PIN'),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Reset PIN'),
                        content: const Text(
                          'Are you sure you want to clear your PIN? You will need to set a new one on next app open.',
                          style: TextStyle(fontSize: 16),
                        ),
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

                    await LocalSecurity.clearPin();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN cleared. Please set your new PIN on next open.')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline, color: AppTheme.primaryNavy, size: 30),
                  title: const Text('App Version', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text('${BrandConfig.brandName} v1.0.0'),
                  trailing: const Text('Build 1', style: TextStyle(color: Color(0xFF64748B))),
                ),
              ),

              // Developer Branding & Portfolio Credit Card (Aaryan Gupta)
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryNavy, Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.goldAccent.withAlpha(220), width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: InkWell(
                  onTap: () async {
                    final Uri url = Uri.parse('https://aryanony.pages.dev/');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.goldAccent.withAlpha(40),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.goldAccent, width: 1.5),
                            ),
                            child: const Icon(Icons.code_rounded, color: AppTheme.goldAccent, size: 28),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Software Architecture & Development',
                                  style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Aaryan Gupta',
                                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Lead Architect & System Engineer',
                                  style: TextStyle(fontSize: 13, color: AppTheme.goldAccent, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 22),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.language_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'https://aryanony.pages.dev/',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRed),
                onPressed: () async {
                  final pinCtrl = TextEditingController();
                  String? err;
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => StatefulBuilder(
                      builder: (ctx, setDlgState) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.security, color: AppTheme.statusRed),
                            SizedBox(width: 8),
                            Text('Confirm Logout (PIN Required)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'To prevent accidental logout, please enter your 6-digit Security PIN:',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: pinCtrl,
                              obscureText: true,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: InputDecoration(
                                labelText: '6-Digit Security PIN',
                                errorText: err,
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(AppLocalization.tr('cancel')),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRed),
                            onPressed: () async {
                              final isPinSet = await LocalSecurity.isPinSet();
                              if (ctx.mounted && !isPinSet) {
                                Navigator.pop(ctx, true);
                                return;
                              }
                              final valid = await LocalSecurity.verifyPin(pinCtrl.text.trim());
                              if (ctx.mounted && valid) {
                                Navigator.pop(ctx, true);
                              } else {
                                setDlgState(() => err = 'Incorrect PIN. Please try again.');
                              }
                            },
                            child: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (confirm != true) return;

                  await LocalSecurity.clearCredentials();
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: Text(AppLocalization.tr('logout')),
              ),
            ],
          ),
        );
      },
    );
  }
}
