import 'dart:convert';
import 'dart:io';

/// ============================================================================
/// 🧹 Rentlyo Ecosystem — Fresh Database Reset / Cleaning Script
/// ============================================================================
/// Purpose:
///   Cleans test deals, payment records, units, maintenance tickets, visitor logs,
///   utility bills, notices, mess menus, notifications, and test renter users.
///   Keeps the Owner account & Property branding document 100% intact!
///   Auto-detects Firebase Project ID & Web API Key from google-services.json!
///
/// Usage:
///   dart scripts/clean_database.dart
///   dart scripts/clean_database.dart --keep-units
///   dart scripts/clean_database.dart --force
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

Map<String, String> _extractFirebaseDetails() {
  final Map<String, String> extracted = {};
  final candidates = [
    File('client_assets/google-services.json'),
    File('Rentlyo/android/app/google-services.json'),
    File('Rentlyo Admin/android/app/google-services.json'),
  ];

  for (final file in candidates) {
    if (file.existsSync()) {
      try {
        final content = jsonDecode(file.readAsStringSync());
        if (content is Map<String, dynamic>) {
          final projId = content['project_info']?['project_id'] as String?;
          if (projId != null && projId.isNotEmpty && !extracted.containsKey('projectId')) {
            extracted['projectId'] = projId;
          }

          final clients = content['client'] as List?;
          if (clients != null) {
            for (final c in clients) {
              if (c is Map<String, dynamic>) {
                final apiKeys = c['api_key'] as List?;
                if (apiKeys != null && apiKeys.isNotEmpty) {
                  final key = apiKeys[0]?['current_key'] as String?;
                  if (key != null && key.isNotEmpty && !extracted.containsKey('apiKey')) {
                    extracted['apiKey'] = key;
                  }
                }
              }
            }
          }
        }
      } catch (_) {}
    }
  }
  return extracted;
}

void main(List<String> args) async {
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

  final autoFirebase = _extractFirebaseDetails();

  String phone = config['ownerPhone'] as String? ?? '9308489230';
  String password = config['ownerInitialPassword'] as String? ?? 'Rentlyo123';
  bool keepUnits = false;
  bool force = false;

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--keep-units') {
      keepUnits = true;
    } else if (args[i] == '--force' || args[i] == '-y' || args[i] == '--yes') {
      force = true;
    } else if (!args[i].startsWith('-')) {
      if (phone == config['ownerPhone']) {
        phone = args[i];
      } else if (password == config['ownerInitialPassword']) {
        password = args[i];
      }
    }
  }

  final apiKey = ((config['firebaseApiKey'] as String?)?.trim().isNotEmpty == true)
      ? (config['firebaseApiKey'] as String).trim()
      : (autoFirebase['apiKey'] ?? '');
  final projectId = ((config['firebaseProjectId'] as String?)?.trim().isNotEmpty == true)
      ? (config['firebaseProjectId'] as String).trim()
      : (autoFirebase['projectId'] ?? '');

  final authEmailDomain = (config['authEmailDomain'] as String?)?.trim() ?? 'rentlyo.local';

  if (apiKey.isEmpty || projectId.isEmpty) {
    stderr.writeln('❌ Error: firebaseApiKey or firebaseProjectId missing in client_config.json and google-services.json');
    exit(1);
  }

  final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
  final cleanTen = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
  final pseudoEmail = '$cleanTen@$authEmailDomain';

  stdout.writeln('====================================================');
  stdout.writeln('  🧹 Rentlyo — Live Database Reset & Purge Tool ');
  stdout.writeln('====================================================\n');
  stdout.writeln('📌 Project ID : $projectId');
  stdout.writeln('📱 Owner Phone: $phone ($cleanTen)');
  stdout.writeln('🏢 Keep Units : $keepUnits');
  stdout.writeln('⚠️ WARNING   : This will remove all deals, payments & temporary records!\n');

  if (!force) {
    stdout.write('Are you sure you want to proceed with database purge? (type "yes" to confirm): ');
    final confirmation = stdin.readLineSync()?.trim().toLowerCase();
    if (confirmation != 'yes' && confirmation != 'y') {
      stdout.writeln('Purge cancelled by user.');
      exit(0);
    }
  }

  try {
    // 1. Sign in as Owner
    stdout.writeln('\nStep 1: Authenticating Owner...');
    final signInUri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey');
    final signInRes = await _httpJson('POST', signInUri, body: {
      'email': pseudoEmail,
      'password': password,
      'returnSecureToken': true,
    });

    if (signInRes['statusCode'] != 200) {
      stderr.writeln('❌ Failed to authenticate owner: ${signInRes['data']}');
      exit(1);
    }

    final idToken = signInRes['data']['idToken'];
    final ownerUid = signInRes['data']['localId'];
    stdout.writeln('✅ Authenticated Owner (UID: $ownerUid)\n');

    // Collections to clean
    final collections = [
      'deals',
      'paymentRecords',
      if (!keepUnits) 'units',
      'maintenanceRequests',
      'utilityBills',
      'gatePasses',
      'visitorLogs',
      'messMenus',
      'notifications',
      'notices',
    ];

    stdout.writeln('Step 2: Purging transactional & demo collections...');
    for (final col in collections) {
      stdout.write('  🧹 Cleaning collection: /$col... ');
      final listUri = Uri.parse('https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$col');
      final listRes = await _httpJson('GET', listUri, headers: {'Authorization': 'Bearer $idToken'});
      
      final docs = listRes['data']?['documents'] as List?;
      if (docs == null || docs.isEmpty) {
        stdout.writeln('0 items (Clean)');
        continue;
      }

      for (final doc in docs) {
        final docName = doc['name'] as String;
        final delUri = Uri.parse('https://firestore.googleapis.com/v1/$docName');
        await _httpJson('DELETE', delUri, headers: {'Authorization': 'Bearer $idToken'});
      }
      stdout.writeln('${docs.length} items purged.');
    }

    // Clean non-owner users
    stdout.write('\nStep 3: Cleaning test renter user profiles in /users... ');
    final userListUri = Uri.parse('https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users');
    final userListRes = await _httpJson('GET', userListUri, headers: {'Authorization': 'Bearer $idToken'});
    final userDocs = userListRes['data']?['documents'] as List?;
    int deletedUsers = 0;

    if (userDocs != null) {
      for (final doc in userDocs) {
        final docName = doc['name'] as String;
        final docId = docName.split('/').last;
        if (docId != ownerUid) {
          final delUri = Uri.parse('https://firestore.googleapis.com/v1/$docName');
          await _httpJson('DELETE', delUri, headers: {'Authorization': 'Bearer $idToken'});
          deletedUsers++;
        }
      }
    }
    stdout.writeln('$deletedUsers test renter profiles removed (Owner retained).');

    stdout.writeln('\n====================================================');
    stdout.writeln('🎉 DATABASE RESET COMPLETE!');
    stdout.writeln('   - All test renters, deals, payments & temporary units removed.');
    stdout.writeln('   - Owner Account & Property Complex branding preserved.');
    stdout.writeln('   - Ready for live production entries!');
    stdout.writeln('====================================================\n');
  } finally {
    _client.close();
  }
}
