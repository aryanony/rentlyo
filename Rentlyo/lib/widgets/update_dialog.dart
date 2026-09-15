import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/localization.dart';
import '../models/app_version_model.dart';

class UpdateDialog extends StatefulWidget {
  final AppVersionModel versionModel;

  const UpdateDialog({super.key, required this.versionModel});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusText = '';

  String _cleanChangelogText(String raw, String version) {
    if (raw.trim().isEmpty) {
      return _defaultChangelog(version);
    }

    final lines = raw.split('\n');
    final cleanedLines = <String>[];

    for (var line in lines) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.toLowerCase().contains('full changelog') ||
          trimmed.toLowerCase().contains('github.com') ||
          trimmed.startsWith('https://') ||
          trimmed.startsWith('http://')) {
        continue;
      }
      trimmed = trimmed.replaceAll(RegExp(r'^\s*[\-\*]\s*'), '• ');
      trimmed = trimmed.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1');
      trimmed = trimmed.replaceAll(RegExp(r'#+\s*'), '');
      if (trimmed.isNotEmpty) {
        if (!trimmed.startsWith('• ')) {
          trimmed = '• $trimmed';
        }
        cleanedLines.add(trimmed);
      }
    }

    if (cleanedLines.isEmpty) {
      return _defaultChangelog(version);
    }

    return cleanedLines.join('\n');
  }

  String _defaultChangelog(String version) {
    return '• Official build update v$version\n'
        '• Enhanced system performance & real-time sync\n'
        '• Improved security features & lease management controls\n'
        '• Responsive UI refinements and bug fixes';
  }

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusText = AppLocalization.tr('downloading_update');
    });

    try {
      if (Platform.isAndroid && widget.versionModel.downloadUrl.isNotEmpty) {
        OtaUpdate().execute(widget.versionModel.downloadUrl).listen(
          (OtaEvent event) {
            if (mounted) {
              setState(() {
                if (event.status == OtaStatus.DOWNLOADING) {
                  final progress = double.tryParse(event.value ?? '0') ?? 0.0;
                  _downloadProgress = progress / 100.0;
                } else if (event.status == OtaStatus.INSTALLING) {
                  _statusText = 'Installing update package...';
                  _downloadProgress = 1.0;
                }
              });
            }
          },
          onError: (e) async {
            await _fallbackHttpDownloadAndInstall();
          },
        );
      } else {
        await _fallbackHttpDownloadAndInstall();
      }
    } catch (e) {
      await _fallbackHttpDownloadAndInstall();
    }
  }

  Future<void> _fallbackHttpDownloadAndInstall() async {
    try {
      final uri = Uri.parse(widget.versionModel.downloadUrl);
      final client = http.Client();
      final req = http.Request('GET', uri);
      req.headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 10; K)';

      final res = await client.send(req);

      final contentLength = res.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final apkPath = '${tempDir.path}/app_update_${widget.versionModel.latestVersionName}.apk';
      final apkFile = File(apkPath);

      int bytesDownloaded = 0;
      final sink = apkFile.openWrite();

      await res.stream.listen(
        (chunk) {
          bytesDownloaded += chunk.length;
          sink.add(chunk);
          if (mounted && contentLength > 0) {
            setState(() {
              _downloadProgress = bytesDownloaded / contentLength;
            });
          }
        },
        onDone: () async {
          await sink.close();
          if (mounted) {
            setState(() {
              _statusText = 'Opening installer...';
              _downloadProgress = 1.0;
            });
          }
          final result = await OpenFilex.open(apkPath);
          if (result.type != ResultType.done) {
            await _openInBrowser();
          }
        },
      ).asFuture();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        await _openInBrowser();
      }
    }
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.versionModel.downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalization.currentLanguage.value;
    final rawChangelog = lang == 'hi' ? widget.versionModel.changelogHi : widget.versionModel.changelogEn;
    final changelog = _cleanChangelogText(rawChangelog, widget.versionModel.latestVersionName);
    final force = widget.versionModel.forceUpdate;

    return PopScope(
      canPop: !force,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        title: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.system_update_outlined, color: AppTheme.goldAccent, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              force ? AppLocalization.tr('mandatory_update') : AppLocalization.tr('update_available'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.goldAccent.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.goldAccent.withAlpha(120)),
              ),
              child: Text(
                'Version ${widget.versionModel.latestVersionName}',
                style: const TextStyle(fontSize: 13, color: AppTheme.primaryNavy, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              AppLocalization.tr('whats_new'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  changelog,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.5, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 18),
              Text(
                '$_statusText (${(_downloadProgress * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  backgroundColor: const Color(0xFFCBD5E1),
                  color: AppTheme.goldAccent,
                  minHeight: 8,
                ),
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          if (!force && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalization.tr('later')),
            ),
          if (!_isDownloading) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryNavy),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _openInBrowser,
              icon: const Icon(Icons.language, size: 18, color: AppTheme.primaryNavy),
              label: const Text('Browser', style: TextStyle(color: AppTheme.primaryNavy, fontWeight: FontWeight.bold)),
            ),
          ],
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: _isDownloading ? null : _startUpdate,
            icon: _isDownloading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download),
            label: Text(AppLocalization.tr('update_now')),
          ),
        ],
      ),
    );
  }
}
