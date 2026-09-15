import 'dart:convert';
import 'dart:io';

/// ============================================================================
/// Rentlyo Ecosystem — App Version & In-App OTA Update Manager
/// ============================================================================
/// Purpose:
///   Updates the `appVersions` collection in Firestore so both apps can detect
///   new APK releases and prompt users to download/install updates automatically.
///
/// Usage:
///   dart scripts/update_version.dart [app_id] [version] [build_number] [min_version] [apk_url] [notes]
///
/// Example:
///   dart scripts/update_version.dart rentlyo_renter 1.1.0 2 1.0.0 "https://github.com/myorg/releases/download/v1.1.0/renter.apk" "Bug fixes and improvements"
/// ============================================================================

final _client = HttpClient();

Future<Map<String, dynamic>> _httpJson(String method, Uri uri, {Map<String, String>? headers, dynamic body}) async {
  final req = await _client.openUrl(method, uri);
  req.headers.set('Content-Type', 'application/json; charset=UTF-8');
  headers?.forEach((k, v) => req.headers.set(k, v));
  if (body != null) {
    req.write(jsonEncode(body));
  }
  final res = await req.close();
  final respBody = await utf8.decoder.bind(res).join();
  try {
    return {'statusCode': res.statusCode, 'data': jsonDecode(respBody)};
  } catch (e) {
    return {'statusCode': res.statusCode, 'raw': respBody};
  }
}

void main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('Usage: dart scripts/update_version.dart <app_id> <version> <build_num> <min_version> <apk_url> <notes>');
    stdout.writeln('Example: dart scripts/update_version.dart rentlyo_renter 1.0.1 2 1.0.0 "https://myurl.com/app.apk" "New features added"');
    exit(0);
  }

  final appId = args[0]; // 'rentlyo_admin' or 'rentlyo_renter'
  final version = args.length > 1 ? args[1] : '1.0.0';
  final buildNum = args.length > 2 ? int.tryParse(args[2]) ?? 1 : 1;
  final minVersion = args.length > 3 ? args[3] : '1.0.0';
  final apkUrl = args.length > 4 ? args[4] : '';
  final notes = args.length > 5 ? args[5] : 'New update available';

  // Load client_config.json
  Map<String, dynamic> config = {};
  for (final path in ['client_config.json', 'scripts/client_config.json']) {
    final f = File(path);
    if (f.existsSync()) {
      try {
        config = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        break;
      } catch (_) {}
    }
  }

  final apiKey = (config['firebaseApiKey'] as String?)?.trim() ?? '';
  final projectId = (config['firebaseProjectId'] as String?)?.trim() ?? '';
  final phone = (config['ownerPhone'] as String?)?.trim() ?? '9308489230';
  final password = (config['ownerInitialPassword'] as String?)?.trim() ?? 'Rentlyo123';
  final authEmailDomain = (config['authEmailDomain'] as String?)?.trim() ?? 'rentlyo.local';

  if (apiKey.isEmpty || projectId.isEmpty) {
    stderr.writeln('❌ Error: firebaseApiKey or firebaseProjectId missing in client_config.json');
    exit(1);
  }

  final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
  final cleanTen = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
  final pseudoEmail = '$cleanTen@$authEmailDomain';

  stdout.writeln('====================================================');
  stdout.writeln('  Rentlyo — App Version & Release Manager      ');
  stdout.writeln('====================================================\n');
  stdout.writeln('📦 App ID       : $appId');
  stdout.writeln('🏷️ Version      : $version (Build $buildNum)');
  stdout.writeln('🛑 Min Version  : $minVersion');
  stdout.writeln('🔗 APK URL      : $apkUrl');
  stdout.writeln('📝 Release Notes: $notes\n');

  try {
    // Authenticate as owner
    final signInUri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey');
    final signInRes = await _httpJson('POST', signInUri, body: {
      'email': pseudoEmail,
      'password': password,
      'returnSecureToken': true,
    });

    if (signInRes['statusCode'] != 200) {
      stderr.writeln('❌ Auth error: ${signInRes['data']}');
      exit(1);
    }

    final idToken = signInRes['data']['idToken'];

    final verUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/appVersions/$appId'
      '?updateMask.fieldPaths=latestVersion&updateMask.fieldPaths=latestBuildNumber&updateMask.fieldPaths=minRequiredVersion&updateMask.fieldPaths=apkDownloadUrl&updateMask.fieldPaths=releaseNotes',
    );

    final res = await _httpJson(
      'PATCH',
      verUri,
      headers: {'Authorization': 'Bearer $idToken'},
      body: {
        'fields': {
          'latestVersion': {'stringValue': version},
          'latestBuildNumber': {'integerValue': '$buildNum'},
          'minRequiredVersion': {'stringValue': minVersion},
          'apkDownloadUrl': {'stringValue': apkUrl},
          'releaseNotes': {'stringValue': notes}
        }
      },
    );

    if (res['statusCode'] == 200) {
      stdout.writeln('✅ Version document successfully published in Firestore!');
    } else {
      stderr.writeln('❌ Error: ${res['data'] ?? res['raw']}');
    }
  } finally {
    _client.close();
  }
}
