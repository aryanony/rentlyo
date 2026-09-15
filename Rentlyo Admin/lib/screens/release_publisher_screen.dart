import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import '../core/app_config.dart';
import '../models/app_version_model.dart';

class ReleasePublisherScreen extends StatefulWidget {
  const ReleasePublisherScreen({super.key});

  @override
  State<ReleasePublisherScreen> createState() => _ReleasePublisherScreenState();
}

class _ReleasePublisherScreenState extends State<ReleasePublisherScreen> {
  String _selectedAppId = 'renter'; // 'renter' or 'admin'
  final _versionNameCtrl = TextEditingController(text: '1.0.1');
  final _buildNumberCtrl = TextEditingController(text: '2');
  late final TextEditingController _downloadUrlCtrl = TextEditingController(
    text: '${AppConfig.githubDownloadBaseUrl}/renter-v1.0.0/app-release.apk',
  );
  final _changelogEnCtrl = TextEditingController(
    text: 'New performance improvements, live rent receipts, and updated lease agreement viewer.',
  );
  final _changelogHiCtrl = TextEditingController(
    text: 'नए फीचर्स, परफॉरमेंस सुधार, और अपडेटेड एग्रीमेंट व्यूअर।',
  );
  bool _forceUpdate = false;
  bool _isPublishing = false;

  void _onAppSelected(String appId) {
    setState(() {
      _selectedAppId = appId;
      if (appId == 'renter') {
        _downloadUrlCtrl.text =
            '${AppConfig.githubDownloadBaseUrl}/renter-v1.0.0/app-release.apk';
      } else {
        _downloadUrlCtrl.text =
            '${AppConfig.githubDownloadBaseUrl}/admin-v1.0.0/app-release.apk';
      }
    });
  }

  Future<void> _publishRelease() async {
    final versionName = _versionNameCtrl.text.trim();
    final buildNum = int.tryParse(_buildNumberCtrl.text.trim());
    final url = _downloadUrlCtrl.text.trim();

    if (versionName.isEmpty || buildNum == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in Version Name, Build Number, and APK URL.')),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final model = AppVersionModel(
        latestVersionName: versionName,
        latestBuildNumber: buildNum,
        downloadUrl: url,
        changelogEn: _changelogEnCtrl.text.trim(),
        changelogHi: _changelogHiCtrl.text.trim(),
        forceUpdate: _forceUpdate,
        releasedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('appVersions')
          .doc(_selectedAppId)
          .set(model.toMap());

      if (mounted) {
        setState(() => _isPublishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.statusGreen,
            content: Text(
              '🎉 Release $versionName published successfully for ${_selectedAppId == "renter" ? "Renter App" : "Admin App"}!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish release: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub Release & Version Manager'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryNavy, Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.system_update_alt_rounded, color: AppTheme.goldAccent, size: 40),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GitHub In-App Auto Update Manager',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Publish new release APKs directly to all installed apps',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Current Live Published Versions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 10),

            // Live status stream
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('appVersions').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                Map<String, Map<String, dynamic>> versions = {};
                for (var doc in docs) {
                  versions[doc.id] = doc.data() as Map<String, dynamic>;
                }

                final renterData = versions['renter'];
                final adminData = versions['admin'];

                return Row(
                  children: [
                    Expanded(
                      child: _buildVersionStatusCard(
                        title: 'Renter App',
                        data: renterData,
                        icon: Icons.person_pin_circle_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildVersionStatusCard(
                        title: 'Admin App',
                        data: adminData,
                        icon: Icons.admin_panel_settings_outlined,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 28),
            const Text(
              'Publish New Release',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 12),

            // App Selector Switch
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'renter',
                  label: Text('Renter App'),
                  icon: Icon(Icons.touch_app_outlined),
                ),
                ButtonSegment(
                  value: 'admin',
                  label: Text('Admin App'),
                  icon: Icon(Icons.admin_panel_settings_outlined),
                ),
              ],
              selected: {_selectedAppId},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) _onAppSelected(set.first);
              },
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _versionNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Version Name (e.g. 1.0.1)',
                      prefixIcon: Icon(Icons.label_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _buildNumberCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Build Number (e.g. 2)',
                      prefixIcon: Icon(Icons.numbers_outlined),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            TextField(
              controller: _downloadUrlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Direct GitHub Release APK Download URL',
                prefixIcon: const Icon(Icons.link_outlined),
                helperText: 'e.g. ${AppConfig.githubDownloadBaseUrl}/[tag]/app-release.apk',
              ),
            ),

            const SizedBox(height: 14),
            TextField(
              controller: _changelogEnCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'What\'s New (Changelog - English)',
                prefixIcon: Icon(Icons.article_outlined),
              ),
            ),

            const SizedBox(height: 14),
            TextField(
              controller: _changelogHiCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'क्या नया है (Changelog - Hindi)',
                prefixIcon: Icon(Icons.translate_outlined),
              ),
            ),

            const SizedBox(height: 14),
            Card(
              elevation: 0,
              color: const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: SwitchListTile(
                activeThumbColor: AppTheme.primaryNavy,
                title: const Text(
                  'Force Mandatory Update',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: const Text(
                  'Prevents users from closing the update dialog until they install the latest APK.',
                  style: TextStyle(fontSize: 12),
                ),
                value: _forceUpdate,
                onChanged: (val) => setState(() => _forceUpdate = val),
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isPublishing ? null : _publishRelease,
              icon: _isPublishing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined, color: Colors.white),
              label: Text(
                _isPublishing ? 'Publishing Release...' : 'Publish Update to All Apps',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionStatusCard({
    required String title,
    required Map<String, dynamic>? data,
    required IconData icon,
  }) {
    final verName = data?['latestVersionName'] ?? '1.0.0 (Initial)';
    final buildNum = data?['latestBuildNumber'] ?? 1;
    final force = data?['forceUpdate'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryNavy, size: 20),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'v$verName (Build $buildNum)',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: force ? AppTheme.statusRed.withAlpha(30) : AppTheme.statusGreen.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              force ? 'Mandatory' : 'Optional Update',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: force ? AppTheme.statusRed : AppTheme.statusGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
