import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/brand_config.dart';
import '../core/app_config.dart';
import '../core/localization.dart';
import '../core/local_security.dart';
import '../services/update_service.dart';
import 'login_screen.dart';
import 'release_publisher_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _propertyId = AppConfig.defaultPropertyId;

  @override
  void initState() {
    super.initState();
    _loadSelectedPropertyId();
  }

  Future<void> _loadSelectedPropertyId() async {
    final saved = await LocalSecurity.getSelectedPropertyId();
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _propertyId = saved);
    }
  }

  void _showEditPropertyDialog(BuildContext context, Map<String, dynamic>? currentData) {
    final nameCtrl = TextEditingController(text: currentData?['brandName'] ?? currentData?['name'] ?? BrandConfig.brandName);
    final addrCtrl = TextEditingController(text: currentData?['address'] ?? AppConfig.defaultAddress);
    final taglineCtrl = TextEditingController(text: currentData?['tagline'] ?? AppConfig.tagline);
    final primaryCtrl = TextEditingController(text: currentData?['primaryColorHex'] ?? AppConfig.primaryHex);
    final accentCtrl = TextEditingController(text: currentData?['accentColorHex'] ?? AppConfig.accentHex);
    final phoneCtrl = TextEditingController(text: currentData?['contactPhone'] ?? AppConfig.contactPhone);
    final whatsappCtrl = TextEditingController(text: currentData?['whatsappNumber'] ?? AppConfig.whatsappNumber);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Property & Brand Branding'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Brand / Property Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: taglineCtrl,
                decoration: const InputDecoration(labelText: 'Tagline / Subtitle'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addrCtrl,
                decoration: const InputDecoration(labelText: 'Address / Location'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: primaryCtrl,
                      decoration: const InputDecoration(labelText: 'Primary Hex', hintText: '083B4C'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: accentCtrl,
                      decoration: const InputDecoration(labelText: 'Accent Hex', hintText: 'C58B2B'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Contact Phone'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: whatsappCtrl,
                decoration: const InputDecoration(labelText: 'WhatsApp Number'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalization.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('properties').doc(_propertyId).set({
                'name': nameCtrl.text.trim(),
                'brandName': nameCtrl.text.trim(),
                'address': addrCtrl.text.trim(),
                'tagline': taglineCtrl.text.trim(),
                'primaryColorHex': primaryCtrl.text.trim().replaceAll('#', ''),
                'accentColorHex': accentCtrl.text.trim().replaceAll('#', ''),
                'contactPhone': phoneCtrl.text.trim(),
                'whatsappNumber': whatsappCtrl.text.trim(),
                'updatedAt': Timestamp.now(),
              }, SetOptions(merge: true));

              await BrandConfig.load(_propertyId);

              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Property & Brand configuration updated live!')),
                );
              }
            },
            child: const Text('Save Brand Changes'),
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
            title: Text(AppLocalization.tr('settings')),
          ),
          body: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('properties').doc(_propertyId).snapshots(),
            builder: (context, propSnap) {
              final propData = propSnap.data?.data() as Map<String, dynamic>?;
              final propName = propData?['brandName'] ?? propData?['name'] ?? BrandConfig.brandName;
              final propAddr = propData?['address'] ?? AppConfig.defaultAddress;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Production Level Branded Header Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryNavy, Color(0xFF1E293B)],
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
                                (propData?['brandName'] ?? propName).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.goldAccent,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                propData?['tagline'] ?? propAddr,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Property Owner & Admin Portal • v1.0.0',
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
                      leading: const Icon(Icons.business_outlined, color: AppTheme.primaryNavy, size: 30),
                      title: const Text('Property & Brand Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text('${propData?['brandName'] ?? propName} • $propAddr'),
                      trailing: const Icon(Icons.edit_outlined, color: AppTheme.primaryNavy),
                      onTap: () => _showEditPropertyDialog(context, propData),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.language_outlined, color: AppTheme.primaryNavy, size: 30),
                      title: Text(AppLocalization.tr('language')),
                      subtitle: Text(AppLocalization.currentLanguage.value == 'en' ? 'English (En)' : 'हिंदी (Hindi)'),
                      trailing: Switch(
                        value: AppLocalization.currentLanguage.value == 'hi',
                        activeThumbColor: AppTheme.primaryNavy,
                        onChanged: (_) {
                          AppLocalization.toggleLanguage();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Self-Update Feature Check Tile
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.system_update_outlined, color: AppTheme.goldAccent, size: 30),
                      title: Text(AppLocalization.tr('check_for_updates'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: const Text('Check for new version release & changelog'),
                      trailing: const Icon(Icons.refresh, color: AppTheme.primaryNavy),
                      onTap: () {
                        UpdateService.checkForUpdate(context, appId: 'admin', isManual: true);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.lock_reset_outlined, color: AppTheme.primaryNavy, size: 30),
                      title: Text(AppLocalization.tr('reset_pin')),
                      subtitle: const Text('Re-enter or change your 6-digit security PIN'),
                      onTap: () async {
                        await LocalSecurity.clearPin();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PIN reset successfully! Please re-open the app to set a new 6-digit PIN.')),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.rocket_launch_outlined, color: AppTheme.goldAccent, size: 30),
                      title: const Text('GitHub Release & Version Manager', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: const Text('Publish new APK releases & trigger in-app updates'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ReleasePublisherScreen()));
                      },
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

                  const SizedBox(height: 16),
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
              );
            },
          ),
        );
      },
    );
  }
}
