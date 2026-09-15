import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../models/app_version_model.dart';
import '../widgets/update_dialog.dart';
import '../core/localization.dart';
import '../core/app_config.dart';

class UpdateService {
  static String get githubReleasesApi => AppConfig.githubReleasesApi;

  static Future<void> checkForUpdate(
    BuildContext context, {
    required String appId, // "admin" or "renter"
    bool isManual = false,
  }) async {
    try {
      if (isManual) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalization.tr('checking_updates')),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      // 1. Get installed app build number
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

      AppVersionModel? versionModel;

      // 2. First try fetching version info from Firestore appVersions/{appId}
      try {
        final docSnap = await FirebaseFirestore.instance
            .collection('appVersions')
            .doc(appId)
            .get();

        if (docSnap.exists && docSnap.data() != null) {
          versionModel = AppVersionModel.fromMap(docSnap.data()!);
        }
      } catch (e) {
        debugPrint("Firestore update check note: $e");
      }

      // 3. Fallback to GitHub Releases API if Firestore is not set up
      versionModel ??= await _fetchFromGitHubReleases(appId);

      if (versionModel == null) {
        if (isManual && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalization.tr('latest_version_msg'))),
          );
        }
        return;
      }

      // 4. Compare remote build number with local installed build number
      if (versionModel.latestBuildNumber > currentBuildNumber) {
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: !versionModel.forceUpdate,
            builder: (_) => UpdateDialog(versionModel: versionModel!),
          );
        }
      } else if (isManual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalization.tr('latest_version_msg'))),
        );
      }
    } catch (e) {
      if (isManual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update check failed: $e')),
        );
      }
    }
  }

  static Future<AppVersionModel?> _fetchFromGitHubReleases(String appId) async {
    try {
      final res = await http.get(Uri.parse(githubReleasesApi));
      if (res.statusCode != 200) return null;

      final List<dynamic> releases = jsonDecode(res.body);
      final tagPrefix = '$appId-v';

      for (var rel in releases) {
        final String tag = rel['tag_name'] ?? '';
        if (tag.startsWith(tagPrefix)) {
          final verName = tag.replaceFirst(tagPrefix, '');
          final assets = rel['assets'] as List<dynamic>? ?? [];
          String apkUrl = '';

          for (var asset in assets) {
            if ((asset['name'] as String).endsWith('.apk')) {
              apkUrl = asset['browser_download_url'] ?? '';
              break;
            }
          }

          if (apkUrl.isEmpty) {
            apkUrl = '${AppConfig.githubDownloadBaseUrl}/$tag/app-release.apk';
          }

          final bodyText = rel['body'] as String? ?? 'New version released on GitHub.';

          return AppVersionModel(
            latestVersionName: verName,
            latestBuildNumber: 2, // Trigger update prompt for latest GitHub release
            downloadUrl: apkUrl,
            changelogEn: bodyText,
            changelogHi: 'GitHub पर नया वर्ज़न $verName जारी किया गया है।',
            forceUpdate: false,
          );
        }
      }
    } catch (e) {
      debugPrint("GitHub Releases API check error: $e");
    }
    return null;
  }
}
