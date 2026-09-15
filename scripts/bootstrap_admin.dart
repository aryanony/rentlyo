import 'dart:convert';
import 'dart:io';

/// ============================================================================
/// 👑 Centralized Admin & Database Bootstrap Script (v3.0 Production)
/// ============================================================================
/// Reads credentials from client_config.json, auto-extracts Firebase Web API Key
/// & Project ID from client_assets/google-services.json, and handles document
/// initialization via Firestore REST API (POST for new, PATCH for existing).
///
/// Usage:
///   dart scripts/bootstrap_admin.dart
///   dart scripts/bootstrap_admin.dart [phone] [password] [propertyName] [brandName]
/// ============================================================================

final _client = HttpClient();

Future<Map<String, dynamic>> _httpJson(
  String method,
  Uri uri, {
  Map<String, String>? headers,
  dynamic body,
}) async {
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
  final current = Directory.current;
  final subdirs = current.listSync().whereType<Directory>().toList();

  final candidates = [
    File('client_assets/google-services.json'),
  ];

  for (final dir in subdirs) {
    candidates.add(File('${dir.path}/android/app/google-services.json'));
  }

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

  final phone = args.isNotEmpty ? args[0] : (config['ownerPhone'] as String? ?? '9308489230');
  final password = args.length > 1 ? args[1] : (config['ownerInitialPassword'] as String? ?? 'Rentlyo123');
  final propertyName = args.length > 2 ? args[2] : (config['clientName'] as String? ?? 'Royal Complex');
  final brandName = args.length > 3 ? args[3] : (config['brandName'] as String? ?? 'Rentlyo');

  final apiKey = autoFirebase['apiKey'] ?? (config['firebaseApiKey'] as String? ?? '');
  final projectId = autoFirebase['projectId'] ?? (config['firebaseProjectId'] as String? ?? '');

  final authEmailDomain = (config['authEmailDomain'] as String?)?.trim() ?? 'rentlyo.local';
  final defaultPropertyId = (config['defaultPropertyId'] as String?)?.trim() ?? 'prop_royal_complex';
  final address = (config['address'] as String?)?.trim() ?? 'Royal Complex, Jaipur, Rajasthan, India';
  final ownerUpiId = (config['ownerUpiId'] as String?)?.trim() ?? 'rentlyo@upi';
  final defaultCurrency = (config['defaultCurrency'] as String?)?.trim() ?? 'INR';
  final currencySymbol = (config['currencySymbol'] as String?)?.trim() ?? '₹';
  final supportEmail = (config['supportEmail'] as String?)?.trim() ?? 'support@rentlyo.com';

  final primaryHex = (config['primaryColorHex'] as String?)?.trim() ?? '083B4C';
  final accentHex = (config['accentColorHex'] as String?)?.trim() ?? 'C58B2B';
  final darkBgHex = (config['darkBackgroundColorHex'] as String?)?.trim() ?? '041B23';
  final contactPhone = (config['phone'] as String?)?.trim() ?? '+91 $phone';
  final whatsappNumber = (config['whatsapp'] as String?)?.trim() ?? '+91 $phone';
  final tagline = (config['renterTagline'] as String?)?.trim() ?? 'Property Management • LeaseSync Portal';

  if (apiKey.isEmpty || projectId.isEmpty) {
    stderr.writeln('❌ Error: firebaseApiKey or firebaseProjectId is missing.');
    exit(1);
  }

  final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
  final cleanTen = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
  final pseudoEmail = '$cleanTen@$authEmailDomain';

  stdout.writeln('====================================================');
  stdout.writeln('  👑 Admin Bootstrap & Firestore Database Seeder    ');
  stdout.writeln('====================================================\n');
  stdout.writeln('📌 Project ID      : $projectId');
  stdout.writeln('📱 Admin Phone     : $phone ($cleanTen)');
  stdout.writeln('🔐 Password        : $password');
  stdout.writeln('📧 Pseudo-Email    : $pseudoEmail');
  stdout.writeln('🏢 Property ID     : $defaultPropertyId ($propertyName)');
  stdout.writeln('👑 Brand Name      : $brandName\n');

  try {
    // Step 1: Firebase Auth Sign-Up / Sign-In
    stdout.writeln('Step 1: Authenticating / Creating Owner in Firebase Auth...');
    String? idToken;
    String? userUid;

    final signUpUri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');
    final signUpRes = await _httpJson('POST', signUpUri, body: {
      'email': pseudoEmail,
      'password': password,
      'returnSecureToken': true,
    });

    if (signUpRes['statusCode'] == 200) {
      idToken = signUpRes['data']['idToken'];
      userUid = signUpRes['data']['localId'];
      stdout.writeln('✅ Owner created in Firebase Auth! UID: $userUid');
    } else if (signUpRes['data']?['error']?['message'] == 'EMAIL_EXISTS') {
      stdout.writeln('ℹ️ User already exists in Auth. Signing in to retrieve token...');
      final signInUri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey');
      final signInRes = await _httpJson('POST', signInUri, body: {
        'email': pseudoEmail,
        'password': password,
        'returnSecureToken': true,
      });

      if (signInRes['statusCode'] == 200) {
        idToken = signInRes['data']['idToken'];
        userUid = signInRes['data']['localId'];
        stdout.writeln('✅ Signed in successfully! UID: $userUid');
      } else {
        stderr.writeln('❌ Failed to authenticate existing user: ${signInRes['data'] ?? signInRes['raw']}');
        exit(1);
      }
    } else {
      stderr.writeln('❌ Auth Error: ${signUpRes['data'] ?? signUpRes['raw']}');
      exit(1);
    }

    // Step 2: Firestore /users/{userUid}
    stdout.writeln('\nStep 2: Configuring /users/$userUid in Firestore...');
    final existingUserUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$userUid',
    );
    final existingUserRes = await _httpJson('GET', existingUserUri, headers: {'Authorization': 'Bearer $idToken'});
    final Set<String> mergedPropIds = {defaultPropertyId};
    if (existingUserRes['statusCode'] == 200 &&
        existingUserRes['data']?['fields']?['propertyIds']?['arrayValue']?['values'] is List) {
      for (var val in existingUserRes['data']['fields']['propertyIds']['arrayValue']['values']) {
        if (val['stringValue'] != null && val['stringValue'].toString().isNotEmpty) {
          mergedPropIds.add(val['stringValue']);
        }
      }
    }

    final userFields = {
      'fields': {
        'uid': {'stringValue': userUid},
        'role': {'stringValue': 'owner'},
        'name': {'stringValue': '$brandName Management'},
        'phone': {'stringValue': cleanTen},
        'active': {'booleanValue': true},
        'propertyIds': {
          'arrayValue': {
            'values': mergedPropIds.map((id) => {'stringValue': id}).toList(),
          }
        }
      }
    };

    if (existingUserRes['statusCode'] == 200) {
      final userDocUri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$userUid'
        '?updateMask.fieldPaths=uid&updateMask.fieldPaths=role&updateMask.fieldPaths=name&updateMask.fieldPaths=phone&updateMask.fieldPaths=active&updateMask.fieldPaths=propertyIds',
      );
      final res = await _httpJson('PATCH', userDocUri, headers: {'Authorization': 'Bearer $idToken'}, body: userFields);
      if (res['statusCode'] == 200) {
        stdout.writeln('✅ User document updated with role: "owner" and linked property: "$defaultPropertyId"');
      } else {
        stdout.writeln('⚠️ User document note: ${res['data'] ?? res['raw']}');
      }
    } else {
      final postUserUri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users?documentId=$userUid',
      );
      final res = await _httpJson('POST', postUserUri, headers: {'Authorization': 'Bearer $idToken'}, body: userFields);
      if (res['statusCode'] == 200) {
        stdout.writeln('✅ User document created with role: "owner" and linked property: "$defaultPropertyId"');
      } else {
        stdout.writeln('⚠️ User document note: ${res['data'] ?? res['raw']}');
      }
    }

    // Step 3: Firestore /properties/{defaultPropertyId}
    stdout.writeln('\nStep 3: Creating /properties/$defaultPropertyId branding document...');
    final existingPropUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/properties/$defaultPropertyId',
    );
    final existingPropRes = await _httpJson('GET', existingPropUri, headers: {'Authorization': 'Bearer $idToken'});

    final propFields = {
      'fields': {
        'name': {'stringValue': propertyName},
        'brandName': {'stringValue': brandName},
        'ownerUid': {'stringValue': userUid},
        'primaryColorHex': {'stringValue': primaryHex},
        'accentColorHex': {'stringValue': accentHex},
        'backgroundColorHex': {'stringValue': darkBgHex},
        'contactPhone': {'stringValue': contactPhone},
        'whatsappNumber': {'stringValue': whatsappNumber},
        'tagline': {'stringValue': tagline},
        'address': {'stringValue': address},
        'ownerUpiId': {'stringValue': ownerUpiId},
        'defaultCurrency': {'stringValue': defaultCurrency},
        'currencySymbol': {'stringValue': currencySymbol},
        'supportEmail': {'stringValue': supportEmail}
      }
    };

    if (existingPropRes['statusCode'] == 200) {
      final propDocUri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/properties/$defaultPropertyId'
        '?updateMask.fieldPaths=name&updateMask.fieldPaths=brandName&updateMask.fieldPaths=ownerUid&updateMask.fieldPaths=primaryColorHex&updateMask.fieldPaths=accentColorHex&updateMask.fieldPaths=backgroundColorHex&updateMask.fieldPaths=contactPhone&updateMask.fieldPaths=whatsappNumber&updateMask.fieldPaths=tagline&updateMask.fieldPaths=address&updateMask.fieldPaths=ownerUpiId&updateMask.fieldPaths=defaultCurrency&updateMask.fieldPaths=currencySymbol&updateMask.fieldPaths=supportEmail',
      );
      final res = await _httpJson('PATCH', propDocUri, headers: {'Authorization': 'Bearer $idToken'}, body: propFields);
      if (res['statusCode'] == 200) {
        stdout.writeln('✅ Property document /properties/$defaultPropertyId updated');
      } else {
        stdout.writeln('⚠️ Property document note: ${res['data'] ?? res['raw']}');
      }
    } else {
      final postPropUri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/properties?documentId=$defaultPropertyId',
      );
      final res = await _httpJson('POST', postPropUri, headers: {'Authorization': 'Bearer $idToken'}, body: propFields);
      if (res['statusCode'] == 200) {
        stdout.writeln('✅ Property document /properties/$defaultPropertyId created');
      } else {
        stdout.writeln('⚠️ Property document note: ${res['data'] ?? res['raw']}');
      }
    }

    // Step 4: Firestore /appVersions initialization
    stdout.writeln('\nStep 4: Initializing /appVersions collection for OTA update checking...');
    for (final appId in ['admin', 'renter']) {
      final checkVerUri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/appVersions/$appId',
      );
      final checkVerRes = await _httpJson('GET', checkVerUri, headers: {'Authorization': 'Bearer $idToken'});

      final verFields = {
        'fields': {
          'latestVersion': {'stringValue': '1.0.0'},
          'latestVersionName': {'stringValue': '1.0.0'},
          'latestBuildNumber': {'integerValue': '1'},
          'downloadUrl': {'stringValue': ''},
          'changelogEn': {'stringValue': 'Initial release'},
          'forceUpdate': {'booleanValue': false}
        }
      };

      if (checkVerRes['statusCode'] == 200) {
        final patchVerUri = Uri.parse(
          'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/appVersions/$appId'
          '?updateMask.fieldPaths=latestVersion&updateMask.fieldPaths=latestBuildNumber&updateMask.fieldPaths=latestVersionName&updateMask.fieldPaths=downloadUrl&updateMask.fieldPaths=changelogEn&updateMask.fieldPaths=forceUpdate',
        );
        await _httpJson('PATCH', patchVerUri, headers: {'Authorization': 'Bearer $idToken'}, body: verFields);
      } else {
        final postVerUri = Uri.parse(
          'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/appVersions?documentId=$appId',
        );
        await _httpJson('POST', postVerUri, headers: {'Authorization': 'Bearer $idToken'}, body: verFields);
      }
    }
    stdout.writeln('✅ /appVersions configured for both admin and renter apps.');

    stdout.writeln('\n====================================================');
    stdout.writeln('🎉 FIREBASE DATABASE SETUP COMPLETE!');
    stdout.writeln('====================================================');
    stdout.writeln('Owner Login Credentials:');
    stdout.writeln('  📱 Phone Number : $phone (enter as $cleanTen in the app)');
    stdout.writeln('  🔐 Password     : $password');
    stdout.writeln('  🏢 Property ID  : $defaultPropertyId ($propertyName)');
    stdout.writeln('====================================================\n');
  } finally {
    _client.close();
  }
}
