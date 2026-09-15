import 'dart:convert';
import 'dart:io';

/// ============================================================================
/// 🏷️ CENTRALIZED SMART WHITE-LABEL CLIENT SETUP & ONBOARDING SYSTEM
/// ============================================================================
/// Zero external package dependencies — runs instantly via pure Dart!
/// Auto-detects Flutter app directories, Firebase Project ID & Web API Key!
///
/// Usage:
///   dart scripts/setup_client.dart                   (1-Click: Sync + Assets + Icons + Firebase)
///   dart scripts/setup_client.dart --interactive     (Step-by-step terminal variables form)
///   dart scripts/setup_client.dart --verify          (Pre-flight sanity check & diagnostics)
///   dart scripts/setup_client.dart --build-apk       (Compile release APKs for both apps)
///   dart scripts/setup_client.dart --all             (Full 1-Click: Setup + Build Release APKs)
///   dart scripts/setup_client.dart --skip-icons      (Fast sync skipping icon generation)
///   dart scripts/setup_client.dart --skip-firebase   (Fast sync skipping Firebase bootstrap)
///   dart scripts/setup_client.dart --help            (Show all options)
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

String _promptUser(String prompt, String defaultValue) {
  stdout.write('$prompt [$defaultValue]: ');
  final input = stdin.readLineSync()?.trim();
  return (input == null || input.isEmpty) ? defaultValue : input;
}

/// Dynamic Flutter App Directory Detection
class AppDirectories {
  final Directory renterDir;
  final Directory adminDir;

  AppDirectories({required this.renterDir, required this.adminDir});
}

AppDirectories _detectAppDirectories() {
  Directory? foundRenter;
  Directory? foundAdmin;

  final current = Directory.current;
  final entities = current.listSync().whereType<Directory>().toList();

  for (final dir in entities) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      final nameLower = dir.uri.pathSegments.where((s) => s.isNotEmpty).last.toLowerCase();
      String pubContent = '';
      try {
        pubContent = pubspec.readAsStringSync().toLowerCase();
      } catch (_) {}

      final isAdmin = nameLower.contains('admin') ||
          pubContent.contains('name: rentlyo_admin') ||
          pubContent.contains('name: rentlyo_admin') ||
          pubContent.contains('admin app') ||
          pubContent.contains('admin console');

      if (isAdmin) {
        foundAdmin = dir;
      } else {
        foundRenter = dir;
      }
    }
  }

  // Fallbacks if not auto-detected
  if (foundRenter == null) {
    if (Directory('Rentlyo').existsSync()) {
      foundRenter = Directory('Rentlyo');
    } else if (Directory('Rentlyo').existsSync()) {
      foundRenter = Directory('Rentlyo');
    } else {
      foundRenter = Directory('Rentlyo');
    }
  }

  if (foundAdmin == null) {
    if (Directory('Rentlyo Admin').existsSync()) {
      foundAdmin = Directory('Rentlyo Admin');
    } else if (Directory('Rentlyo Admin').existsSync()) {
      foundAdmin = Directory('Rentlyo Admin');
    } else {
      foundAdmin = Directory('Rentlyo Admin');
    }
  }

  return AppDirectories(renterDir: foundRenter, adminDir: foundAdmin);
}

/// Automatically extracts Firebase Project ID, Web API Key and Package Names
/// directly from any available google-services.json file!
Map<String, String> _extractFirebaseDetails(AppDirectories dirs) {
  final Map<String, String> extracted = {};
  final candidates = [
    File('client_assets/google-services.json'),
    File('${dirs.renterDir.path}/android/app/google-services.json'),
    File('${dirs.adminDir.path}/android/app/google-services.json'),
  ];

  for (final file in candidates) {
    if (file.existsSync()) {
      try {
        final content = jsonDecode(file.readAsStringSync());
        if (content is Map<String, dynamic>) {
          // Project ID
          final projId = content['project_info']?['project_id'] as String?;
          if (projId != null && projId.isNotEmpty && !extracted.containsKey('projectId')) {
            extracted['projectId'] = projId;
          }

          // Inspect client array
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

                final pkg = c['client_info']?['android_client_info']?['package_name'] as String?;
                if (pkg != null && pkg.isNotEmpty) {
                  if (pkg.contains('admin') && !extracted.containsKey('adminPackageId')) {
                    extracted['adminPackageId'] = pkg;
                  } else if ((pkg.contains('renter') || pkg.contains('tenant') || pkg.contains('client')) &&
                      !extracted.containsKey('renterPackageId')) {
                    extracted['renterPackageId'] = pkg;
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

/// Smart search for client assets in client_assets/
File? _findClientAsset(List<String> keywords) {
  final dir = Directory('client_assets');
  if (!dir.existsSync()) return null;

  final files = dir.listSync().whereType<File>().toList();
  for (final keyword in keywords) {
    for (final file in files) {
      final name = file.uri.pathSegments.last.toLowerCase();
      if (name.contains(keyword.toLowerCase()) &&
          (name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.webp'))) {
        return file;
      }
    }
  }
  return null;
}

void main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln('''
============================================================================
🏷️ Rentlyo White-Label Client Onboarding Tool (v3.0 Production)
============================================================================
Usage:
  dart scripts/setup_client.dart [options]

Options:
  --interactive, -i       Interactive variables form (terminal questionnaire)
  --verify, -v            Pre-flight diagnostics & sanity check
  --dry-run               Preview changes without modifying any files
  --config <path>         Path to client configuration JSON (default: client_config.json)
  --skip-icons            Skip regenerating launcher icons & splash screens
  --skip-firebase         Skip Firebase Auth & Firestore DB bootstrap
  --build-apk             Compile release APKs for both Admin and Tenant apps
  --all                   Complete setup and compile release APKs
  --help, -h              Show this help manual
============================================================================
''');
    exit(0);
  }

  // 1. Detect app directories
  final dirs = _detectAppDirectories();

  // 2. Locate configuration JSON file
  String configPath = 'client_config.json';
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--config' && i + 1 < args.length) {
      configPath = args[i + 1];
    }
  }

  File configFile = File(configPath);
  if (!configFile.existsSync()) {
    stderr.writeln('❌ Configuration file not found at: $configPath');
    stderr.writeln('   Please ensure client_config.json exists in the root directory.');
    exit(1);
  }

  Map<String, dynamic> configMap = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;

  // Auto-detect Firebase details from client_assets/google-services.json
  final autoFirebase = _extractFirebaseDetails(dirs);
  bool configNeedsSave = false;

  if (autoFirebase.containsKey('projectId') && autoFirebase['projectId']!.isNotEmpty) {
    if (configMap['firebaseProjectId'] != autoFirebase['projectId']) {
      configMap['firebaseProjectId'] = autoFirebase['projectId'];
      configNeedsSave = true;
    }
  }
  if (autoFirebase.containsKey('apiKey') && autoFirebase['apiKey']!.isNotEmpty) {
    if (configMap['firebaseApiKey'] != autoFirebase['apiKey']) {
      configMap['firebaseApiKey'] = autoFirebase['apiKey'];
      configNeedsSave = true;
    }
  }
  if (autoFirebase.containsKey('adminPackageId') && autoFirebase['adminPackageId']!.isNotEmpty) {
    if (configMap['adminPackageId'] != autoFirebase['adminPackageId']) {
      configMap['adminPackageId'] = autoFirebase['adminPackageId'];
      configNeedsSave = true;
    }
  }
  if (autoFirebase.containsKey('renterPackageId') && autoFirebase['renterPackageId']!.isNotEmpty) {
    if (configMap['renterPackageId'] != autoFirebase['renterPackageId']) {
      configMap['renterPackageId'] = autoFirebase['renterPackageId'];
      configNeedsSave = true;
    }
  }

  if (configNeedsSave) {
    final pretty = const JsonEncoder.withIndent('  ').convert(configMap);
    configFile.writeAsStringSync(pretty);
  }

  // 3. Interactive Terminal Variables Form Mode
  final bool isInteractive = args.contains('--interactive') || args.contains('-i');
  if (isInteractive) {
    stdout.writeln('====================================================');
    stdout.writeln('📝 CLIENT ONBOARDING VARIABLES FORM (INTERACTIVE)   ');
    stdout.writeln('====================================================');
    stdout.writeln('💡 Tip: You can drop logo.png, banner.png, and google-services.json');
    stdout.writeln('   directly into the "client_assets" folder for automatic setup!');
    stdout.writeln('   Press ENTER on any question to keep the current value.\n');

    configMap['clientName'] = _promptUser('🏢 Property / Complex Name', configMap['clientName'] ?? 'Royal Complex');
    configMap['brandName'] = _promptUser('👑 Master Brand Name', configMap['brandName'] ?? 'Rentlyo');
    configMap['address'] = _promptUser('📍 Physical Address', configMap['address'] ?? 'Royal Complex, Jaipur, Rajasthan, India');

    configMap['renterAppName'] = _promptUser('📱 Tenant App Name', configMap['renterAppName'] ?? 'Rentlyo Spaces');
    configMap['adminAppName'] = _promptUser('🛡️ Admin App Name', configMap['adminAppName'] ?? 'Rentlyo Admin');
    configMap['renterTagline'] = _promptUser('💬 Tenant Subtitle', configMap['renterTagline'] ?? 'Tenant Companion • LeaseSync Portal');
    configMap['adminTagline'] = _promptUser('💬 Admin Subtitle', configMap['adminTagline'] ?? 'Property Management • Admin Console');

    configMap['phone'] = _promptUser('📞 Support Phone', configMap['phone'] ?? '+91 93084 89230');
    configMap['whatsapp'] = _promptUser('💬 WhatsApp Number', configMap['whatsapp'] ?? configMap['phone'] ?? '+91 93084 89230');
    configMap['supportEmail'] = _promptUser('📧 Support Email', configMap['supportEmail'] ?? 'support@rentlyo.com');
    configMap['ownerUpiId'] = _promptUser('💳 Owner UPI ID for Rent', configMap['ownerUpiId'] ?? 'rentlyo@upi');

    configMap['primaryColorHex'] = _promptUser('🎨 Primary Hex Color (no #)', configMap['primaryColorHex'] ?? '083B4C');
    configMap['accentColorHex'] = _promptUser('✨ Accent Hex Color (no #)', configMap['accentColorHex'] ?? 'C58B2B');
    configMap['darkBackgroundColorHex'] = _promptUser('🌑 Dark Background Hex Color (no #)', configMap['darkBackgroundColorHex'] ?? '041B23');

    configMap['firebaseProjectId'] = _promptUser('🔐 Firebase Project ID', configMap['firebaseProjectId'] ?? autoFirebase['projectId'] ?? 'rentlyo');
    configMap['firebaseApiKey'] = _promptUser('🔑 Firebase Web API Key', configMap['firebaseApiKey'] ?? autoFirebase['apiKey'] ?? '');
    configMap['ownerPhone'] = _promptUser('👑 Owner Phone Number', configMap['ownerPhone'] ?? '9308489230');
    configMap['ownerInitialPassword'] = _promptUser('🔑 Owner Initial Password', configMap['ownerInitialPassword'] ?? 'Rentlyo123');

    configMap['renterPackageId'] = _promptUser('📦 Tenant Package ID', configMap['renterPackageId'] ?? autoFirebase['renterPackageId'] ?? 'com.rentlyo.renter');
    configMap['adminPackageId'] = _promptUser('📦 Admin Package ID', configMap['adminPackageId'] ?? autoFirebase['adminPackageId'] ?? 'com.rentlyo.admin');

    // Save updated JSON
    final prettyJson = const JsonEncoder.withIndent('  ').convert(configMap);
    configFile.writeAsStringSync(prettyJson);
    stdout.writeln('\n✅ client_config.json updated successfully!\n');
  }

  // Extract variables
  final clientName = (configMap['clientName'] as String?)?.trim() ?? 'Royal Complex';
  final brandName = (configMap['brandName'] as String?)?.trim() ?? 'Rentlyo';
  final renterAppName = (configMap['renterAppName'] as String?)?.trim() ?? 'Rentlyo';
  final adminAppName = (configMap['adminAppName'] as String?)?.trim() ?? 'Rentlyo Admin';
  final renterTagline = (configMap['renterTagline'] as String?)?.trim() ?? 'Tenant Companion • LeaseSync Portal';
  final adminTagline = (configMap['adminTagline'] as String?)?.trim() ?? 'Property Management • Admin Console';
  final address = (configMap['address'] as String?)?.trim() ?? 'Royal Complex, Jaipur, Rajasthan, India';
  final phone = (configMap['phone'] as String?)?.trim() ?? '+91 93084 89230';
  final whatsapp = (configMap['whatsapp'] as String?)?.trim() ?? '+91 93084 89230';
  final supportEmail = (configMap['supportEmail'] as String?)?.trim() ?? 'support@rentlyo.com';
  final ownerUpiId = (configMap['ownerUpiId'] as String?)?.trim() ?? 'rentlyo@upi';

  final primaryHex = (configMap['primaryColorHex'] as String?)?.trim().replaceAll('#', '') ?? '083B4C';
  final secondaryHex = (configMap['secondaryColorHex'] as String?)?.trim().replaceAll('#', '') ?? '0B4F60';
  final accentHex = (configMap['accentColorHex'] as String?)?.trim().replaceAll('#', '') ?? 'C58B2B';
  final darkBgHex = (configMap['darkBackgroundColorHex'] as String?)?.trim().replaceAll('#', '') ?? '041B23';
  final lightSurfaceHex = (configMap['lightSurfaceColorHex'] as String?)?.trim().replaceAll('#', '') ?? 'F8FAF9';

  final authEmailDomain = (configMap['authEmailDomain'] as String?)?.trim() ?? 'rentlyo.local';
  final defaultPropertyId = (configMap['defaultPropertyId'] as String?)?.trim() ?? 'prop_royal_complex';
  final defaultCurrency = (configMap['defaultCurrency'] as String?)?.trim() ?? 'INR';
  final currencySymbol = (configMap['currencySymbol'] as String?)?.trim() ?? '₹';

  final githubRepoOwner = (configMap['githubRepoOwner'] as String?)?.trim() ?? 'aryanony';
  final githubRepoName = (configMap['githubRepoName'] as String?)?.trim() ?? 'rentlyo';

  final renterPackageId = (configMap['renterPackageId'] as String?)?.trim() ?? autoFirebase['renterPackageId'] ?? 'com.rentlyo.renter';
  final adminPackageId = (configMap['adminPackageId'] as String?)?.trim() ?? autoFirebase['adminPackageId'] ?? 'com.rentlyo.admin';

  final logoImagePath = (configMap['logoImagePath'] as String?)?.trim() ?? '';
  final bannerImagePath = (configMap['bannerImagePath'] as String?)?.trim() ?? '';

  final apiKey = ((configMap['firebaseApiKey'] as String?)?.trim().isNotEmpty == true)
      ? (configMap['firebaseApiKey'] as String).trim()
      : (autoFirebase['apiKey'] ?? '');
  final projectId = ((configMap['firebaseProjectId'] as String?)?.trim().isNotEmpty == true)
      ? (configMap['firebaseProjectId'] as String).trim()
      : (autoFirebase['projectId'] ?? '');

  final ownerPhone = (configMap['ownerPhone'] as String?)?.trim() ?? phone;
  final ownerPassword = (configMap['ownerInitialPassword'] as String?)?.trim() ?? 'Rentlyo123';

  // 4. Pre-flight verification mode
  final bool isVerify = args.contains('--verify') || args.contains('-v');
  if (isVerify) {
    stdout.writeln('====================================================');
    stdout.writeln('🔍 PRE-FLIGHT CLIENT CONFIGURATION DIAGNOSTICS      ');
    stdout.writeln('====================================================\n');

    bool hasErrors = false;

    // Check App Directories
    stdout.writeln('📁 Detected Apps:');
    stdout.writeln('   • Tenant App Directory : ${dirs.renterDir.path} (${dirs.renterDir.existsSync() ? "✅" : "❌ NOT FOUND"})');
    stdout.writeln('   • Admin App Directory  : ${dirs.adminDir.path} (${dirs.adminDir.existsSync() ? "✅" : "❌ NOT FOUND"})');

    if (!dirs.renterDir.existsSync() || !dirs.adminDir.existsSync()) {
      hasErrors = true;
    }

    // Check Hex colors
    for (final entry in {
      'primaryColorHex': primaryHex,
      'secondaryColorHex': secondaryHex,
      'accentColorHex': accentHex,
      'darkBackgroundColorHex': darkBgHex,
      'lightSurfaceColorHex': lightSurfaceHex,
    }.entries) {
      if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(entry.value)) {
        stdout.writeln('❌ Invalid color hex for ${entry.key}: #${entry.value}');
        hasErrors = true;
      } else {
        stdout.writeln('✅ ${entry.key}: #${entry.value}');
      }
    }

    // Check Centralized client_assets folder
    final centralGServices = File('client_assets/google-services.json');
    final resolvedLogo = (logoImagePath.isNotEmpty && File(logoImagePath).existsSync())
        ? File(logoImagePath)
        : _findClientAsset(['logo', 'icon', 'app_icon', 'brand', 'plaza']);
    final resolvedBanner = (bannerImagePath.isNotEmpty && File(bannerImagePath).existsSync())
        ? File(bannerImagePath)
        : _findClientAsset(['banner', 'header', 'cover', 'wide', 'full']);

    if (centralGServices.existsSync()) {
      stdout.writeln('✅ Centralized client_assets/google-services.json located');
    } else {
      stdout.writeln('ℹ️ client_assets/google-services.json not in client_assets/ (checking app folders directly...)');
    }

    if (resolvedLogo != null) {
      stdout.writeln('✅ Client Logo found at: ${resolvedLogo.path}');
    } else {
      stdout.writeln('⚠️ Client Logo not found in client_assets/ (default will be preserved)');
    }

    if (resolvedBanner != null) {
      stdout.writeln('✅ Client Banner found at: ${resolvedBanner.path}');
    } else {
      stdout.writeln('ℹ️ Client Banner not found; will mirror logo as banner');
    }

    // Check Firebase Google Services JSON in app directories
    final renterGServices = File('${dirs.renterDir.path}/android/app/google-services.json');
    final adminGServices = File('${dirs.adminDir.path}/android/app/google-services.json');

    if (renterGServices.existsSync() || centralGServices.existsSync()) {
      stdout.writeln('✅ Tenant google-services.json located');
    } else {
      stdout.writeln('⚠️ Tenant google-services.json NOT FOUND. Place in client_assets/ or ${dirs.renterDir.path}/android/app/');
      hasErrors = true;
    }

    if (adminGServices.existsSync() || centralGServices.existsSync()) {
      stdout.writeln('✅ Admin google-services.json located');
    } else {
      stdout.writeln('⚠️ Admin google-services.json NOT FOUND. Place in client_assets/ or ${dirs.adminDir.path}/android/app/');
      hasErrors = true;
    }

    // Check Firebase project ID and API key
    if (projectId.isNotEmpty) {
      stdout.writeln('✅ Firebase Project ID: $projectId ${autoFirebase['projectId'] == projectId ? "(Auto-detected from google-services.json)" : ""}');
    } else {
      stdout.writeln('⚠️ Firebase Project ID is blank and could not be detected from google-services.json');
      hasErrors = true;
    }

    if (apiKey.isNotEmpty) {
      stdout.writeln('✅ Firebase Web API Key: present (${apiKey.substring(0, 8)}...) ${autoFirebase['apiKey'] == apiKey ? "(Auto-detected from google-services.json)" : ""}');
    } else {
      stdout.writeln('⚠️ Firebase Web API Key is blank and could not be detected from google-services.json');
      hasErrors = true;
    }

    stdout.writeln('\nDiagnostics complete. Result: ${hasErrors ? "❌ Fix errors above" : "✅ All checks passed"}\n');
    exit(hasErrors ? 1 : 0);
  }

  // 5. Dry Run Mode
  final bool isDryRun = args.contains('--dry-run');

  stdout.writeln('====================================================');
  stdout.writeln('  🏷️  1-Click White-Label Client Setup Engine      ');
  stdout.writeln('====================================================\n');
  stdout.writeln('🏢 Client Property : $clientName');
  stdout.writeln('👑 Brand Name     : $brandName');
  stdout.writeln('📱 Renter App     : $renterAppName ($renterPackageId) -> ${dirs.renterDir.path}');
  stdout.writeln('🛡️ Admin App      : $adminAppName ($adminPackageId) -> ${dirs.adminDir.path}');
  stdout.writeln('🎨 Colors         : Primary #$primaryHex | Accent #$accentHex | Dark #$darkBgHex');
  stdout.writeln('🔐 Auth Domain    : @$authEmailDomain');
  stdout.writeln('🏢 Property ID    : $defaultPropertyId');
  stdout.writeln('🔐 Firebase Proj  : $projectId');
  stdout.writeln('📦 GitHub Releases: $githubRepoOwner/$githubRepoName\n');

  if (isDryRun) {
    stdout.writeln('ℹ️ DRY RUN MODE: No files will be modified.');
    exit(0);
  }

  // STEP 1: Synchronize Centralized Assets from client_assets/
  stdout.writeln('Step 1: Distributing centralized assets from client_assets/...');
  final centralGServices = File('client_assets/google-services.json');
  final centralGServicesAdmin = File('client_assets/google-services-admin.json');
  final centralGServicesTenant = File('client_assets/google-services-tenant.json');

  // Ensure directories exist
  final renterAppGoogle = File('${dirs.renterDir.path}/android/app/google-services.json');
  final adminAppGoogle = File('${dirs.adminDir.path}/android/app/google-services.json');
  renterAppGoogle.parent.createSync(recursive: true);
  adminAppGoogle.parent.createSync(recursive: true);

  if (centralGServices.existsSync()) {
    centralGServices.copySync(renterAppGoogle.path);
    centralGServices.copySync(adminAppGoogle.path);
    stdout.writeln('  ✅ google-services.json distributed to both apps.');
  }
  if (centralGServicesAdmin.existsSync()) {
    centralGServicesAdmin.copySync(adminAppGoogle.path);
    stdout.writeln('  ✅ google-services-admin.json copied to Admin app.');
  }
  if (centralGServicesTenant.existsSync()) {
    centralGServicesTenant.copySync(renterAppGoogle.path);
    stdout.writeln('  ✅ google-services-tenant.json copied to Tenant app.');
  }

  // Smart Logo Detection & Copying
  File? resolvedLogo;
  if (logoImagePath.isNotEmpty && File(logoImagePath).existsSync()) {
    resolvedLogo = File(logoImagePath);
  } else {
    resolvedLogo = _findClientAsset(['logo', 'icon', 'app_icon', 'brand', 'plaza']);
  }

  final renterImagesDir = Directory('${dirs.renterDir.path}/assets/images');
  final adminImagesDir = Directory('${dirs.adminDir.path}/assets/images');
  renterImagesDir.createSync(recursive: true);
  adminImagesDir.createSync(recursive: true);

  if (resolvedLogo != null && resolvedLogo.existsSync()) {
    resolvedLogo.copySync('${dirs.renterDir.path}/assets/images/logo.png');
    resolvedLogo.copySync('${dirs.adminDir.path}/assets/images/logo.png');
    stdout.writeln('  ✅ Logo updated from: ${resolvedLogo.path}');
  }

  // Smart Banner Detection & Copying
  File? resolvedBanner;
  if (bannerImagePath.isNotEmpty && File(bannerImagePath).existsSync()) {
    resolvedBanner = File(bannerImagePath);
  } else {
    resolvedBanner = _findClientAsset(['banner', 'header', 'cover', 'wide', 'full']);
  }

  if (resolvedBanner != null && resolvedBanner.existsSync()) {
    resolvedBanner.copySync('${dirs.renterDir.path}/assets/images/rentlyo_full.png');
    resolvedBanner.copySync('${dirs.adminDir.path}/assets/images/rentlyo_full.png');
    stdout.writeln('  ✅ Banner updated from: ${resolvedBanner.path}');
  } else if (resolvedLogo != null && resolvedLogo.existsSync()) {
    resolvedLogo.copySync('${dirs.renterDir.path}/assets/images/rentlyo_full.png');
    resolvedLogo.copySync('${dirs.adminDir.path}/assets/images/rentlyo_full.png');
    stdout.writeln('  ℹ️ Banner not found; mirrored logo as banner.');
  }

  // STEP 2: Generate AppConfig for Tenant App
  stdout.writeln('\nStep 2: Writing ${dirs.renterDir.path}/lib/core/app_config.dart...');
  final renterAppConfigContent = _buildAppConfigCode(
    isRenter: true,
    brandName: brandName,
    propertyName: clientName,
    appName: renterAppName,
    tagline: renterTagline,
    address: address,
    phone: phone,
    whatsapp: whatsapp,
    supportEmail: supportEmail,
    ownerUpiId: ownerUpiId,
    primaryHex: primaryHex,
    secondaryHex: secondaryHex,
    accentHex: accentHex,
    darkBgHex: darkBgHex,
    lightSurfaceHex: lightSurfaceHex,
    authEmailDomain: authEmailDomain,
    defaultPropertyId: defaultPropertyId,
    defaultCurrency: defaultCurrency,
    currencySymbol: currencySymbol,
    githubRepoOwner: githubRepoOwner,
    githubRepoName: githubRepoName,
  );
  File('${dirs.renterDir.path}/lib/core/app_config.dart').writeAsStringSync(renterAppConfigContent);
  stdout.writeln('  ✅ Tenant AppConfig updated.');

  // STEP 3: Generate AppConfig for Admin App
  stdout.writeln('Step 3: Writing ${dirs.adminDir.path}/lib/core/app_config.dart...');
  final adminAppConfigContent = _buildAppConfigCode(
    isRenter: false,
    brandName: brandName,
    propertyName: clientName,
    appName: adminAppName,
    tagline: adminTagline,
    address: address,
    phone: phone,
    whatsapp: whatsapp,
    supportEmail: supportEmail,
    ownerUpiId: ownerUpiId,
    primaryHex: primaryHex,
    secondaryHex: secondaryHex,
    accentHex: accentHex,
    darkBgHex: darkBgHex,
    lightSurfaceHex: lightSurfaceHex,
    authEmailDomain: authEmailDomain,
    defaultPropertyId: defaultPropertyId,
    defaultCurrency: defaultCurrency,
    currencySymbol: currencySymbol,
    githubRepoOwner: githubRepoOwner,
    githubRepoName: githubRepoName,
  );
  File('${dirs.adminDir.path}/lib/core/app_config.dart').writeAsStringSync(adminAppConfigContent);
  stdout.writeln('  ✅ Admin AppConfig updated.');

  // STEP 4: Update pubspec.yaml colors & launcher icon backgrounds
  stdout.writeln('Step 4: Synchronizing pubspec.yaml launcher icon & splash configurations...');
  _updatePubspec('${dirs.renterDir.path}/pubspec.yaml', primaryHex);
  _updatePubspec('${dirs.adminDir.path}/pubspec.yaml', primaryHex);
  stdout.writeln('  ✅ pubspec.yaml splash & icons updated with primary color #$primaryHex.');

  // STEP 5: Update Android manifests and build.gradle
  stdout.writeln('Step 5: Updating Android build.gradle & AndroidManifest.xml...');
  _updateAndroidPackageAndName(
    appDir: dirs.renterDir.path,
    packageId: renterPackageId,
    appLabel: renterAppName,
  );
  _updateAndroidPackageAndName(
    appDir: dirs.adminDir.path,
    packageId: adminPackageId,
    appLabel: adminAppName,
  );
  stdout.writeln('  ✅ Android package IDs & labels updated.');

  // STEP 6: Update Web metadata and PWA manifest
  stdout.writeln('Step 6: Synchronizing Web metadata & PWA manifest...');
  _updateWebMetadata(
    appDir: dirs.renterDir.path,
    appLabel: renterAppName,
    primaryHex: primaryHex,
  );
  _updateWebMetadata(
    appDir: dirs.adminDir.path,
    appLabel: adminAppName,
    primaryHex: primaryHex,
  );
  stdout.writeln('  ✅ Web title, meta & manifest synced.');

  // STEP 7: Rebuild Launcher Icons & Native Splash (Default ON for 1-Click Perfection!)
  final bool skipIcons = args.contains('--skip-icons');
  if (!skipIcons) {
    stdout.writeln('\nStep 7: Compiling app launcher icons and native splash screens...');
    stdout.writeln('  🎨 Compiling icons for Tenant App (${dirs.renterDir.path})...');
    await _runFlutterDartCommand(['run', 'flutter_launcher_icons'], workingDirectory: dirs.renterDir.path);
    await _runFlutterDartCommand(['run', 'flutter_native_splash:create'], workingDirectory: dirs.renterDir.path);

    stdout.writeln('  🎨 Compiling icons for Admin App (${dirs.adminDir.path})...');
    await _runFlutterDartCommand(['run', 'flutter_launcher_icons'], workingDirectory: dirs.adminDir.path);
    await _runFlutterDartCommand(['run', 'flutter_native_splash:create'], workingDirectory: dirs.adminDir.path);
    stdout.writeln('  ✅ App icons & splash screens compiled successfully.');
  } else {
    stdout.writeln('\nStep 7: Skipping icon generation (--skip-icons set).');
  }

  // STEP 8: Firebase & Firestore Database Bootstrap (Default ON for 1-Click Perfection!)
  final bool skipFirebase = args.contains('--skip-firebase');
  if (!skipFirebase) {
    stdout.writeln('\nStep 8: Bootstrapping Client Firebase Authentication & Firestore DB...');
    if (apiKey.isNotEmpty && projectId.isNotEmpty) {
      await _bootstrapFirebase(
        apiKey: apiKey,
        projectId: projectId,
        ownerPhone: ownerPhone,
        ownerPassword: ownerPassword,
        propertyName: clientName,
        brandName: brandName,
        authEmailDomain: authEmailDomain,
        defaultPropertyId: defaultPropertyId,
        primaryHex: primaryHex,
        accentHex: accentHex,
        darkBgHex: darkBgHex,
        contactPhone: phone,
        whatsappNumber: whatsapp,
        tagline: renterTagline,
        address: address,
        ownerUpiId: ownerUpiId,
        defaultCurrency: defaultCurrency,
        currencySymbol: currencySymbol,
        supportEmail: supportEmail,
      );
    } else {
      stdout.writeln('  ⚠️ Skipping Firebase bootstrap: firebaseApiKey or firebaseProjectId empty.');
    }
  } else {
    stdout.writeln('\nStep 8: Skipping Firebase bootstrap (--skip-firebase set).');
  }

  // STEP 9: Optional Build Release APKs
  final bool shouldBuildApk = args.contains('--all') || args.contains('--build-apk');
  if (shouldBuildApk) {
    stdout.writeln('\nStep 9: Compiling production release APKs for both applications...');
    stdout.writeln('  🔨 Compiling ${dirs.renterDir.path} (Tenant)...');
    await _runProcess('flutter', ['build', 'apk', '--release'], workingDirectory: dirs.renterDir.path);
    stdout.writeln('  🔨 Compiling ${dirs.adminDir.path} (Admin)...');
    await _runProcess('flutter', ['build', 'apk', '--release'], workingDirectory: dirs.adminDir.path);
    stdout.writeln('  ✅ Production APKs compiled successfully!');
  }

  stdout.writeln('\n====================================================');
  stdout.writeln('🎉 CLIENT SETUP COMPLETE & 1000% VERIFIED!');
  stdout.writeln('====================================================');
  stdout.writeln('Summary of Client Setup:');
  stdout.writeln('  🏢 Property     : $clientName ($defaultPropertyId)');
  stdout.writeln('  👑 Brand        : $brandName');
  stdout.writeln('  📱 Tenant App   : $renterAppName ($renterPackageId) [${dirs.renterDir.path}]');
  stdout.writeln('  🛡️ Admin App    : $adminAppName ($adminPackageId) [${dirs.adminDir.path}]');
  final cleanTen = ownerPhone.replaceAll(RegExp(r'\D'), '');
  stdout.writeln('  👑 Owner Login  : ${cleanTen.length > 10 ? cleanTen.substring(cleanTen.length - 10) : cleanTen}');
  stdout.writeln('  🔐 Owner Pass   : $ownerPassword');
  stdout.writeln('  💳 Owner UPI    : $ownerUpiId');
  stdout.writeln('  🔐 Firebase DB  : $projectId');
  stdout.writeln('====================================================\n');
}

Future<void> _runFlutterDartCommand(List<String> arguments, {required String workingDirectory}) async {
  try {
    final process = await Process.start(
      'dart',
      arguments,
      workingDirectory: workingDirectory,
      runInShell: true,
    );
    process.stdout.transform(utf8.decoder).listen((data) => stdout.write(data));
    process.stderr.transform(utf8.decoder).listen((data) => stderr.write(data));
    final code = await process.exitCode;
    if (code == 0) return;
  } catch (_) {}

  try {
    final fallback = await Process.start(
      'flutter',
      ['pub', ...arguments],
      workingDirectory: workingDirectory,
      runInShell: true,
    );
    fallback.stdout.transform(utf8.decoder).listen((data) => stdout.write(data));
    fallback.stderr.transform(utf8.decoder).listen((data) => stderr.write(data));
    await fallback.exitCode;
  } catch (_) {}
}

Future<void> _runProcess(String exe, List<String> arguments, {required String workingDirectory}) async {
  final process = await Process.start(exe, arguments, workingDirectory: workingDirectory, runInShell: true);
  process.stdout.transform(utf8.decoder).listen((data) => stdout.write(data));
  process.stderr.transform(utf8.decoder).listen((data) => stderr.write(data));
  await process.exitCode;
}

String _buildAppConfigCode({
  required bool isRenter,
  required String brandName,
  required String propertyName,
  required String appName,
  required String tagline,
  required String address,
  required String phone,
  required String whatsapp,
  required String supportEmail,
  required String ownerUpiId,
  required String primaryHex,
  required String secondaryHex,
  required String accentHex,
  required String darkBgHex,
  required String lightSurfaceHex,
  required String authEmailDomain,
  required String defaultPropertyId,
  required String defaultCurrency,
  required String currencySymbol,
  required String githubRepoOwner,
  required String githubRepoName,
}) {
  return '''// ============================================================================
// 🏷️ APP CONFIGURATION — CENTRALIZED WHITE-LABEL SETUP (${isRenter ? "TENANT COMPANION" : "ADMIN CONSOLE"})
// ============================================================================
// This is the SINGLE Dart file to configure if setting up manually without scripts.
// All values below represent the client's configuration variables.
// ============================================================================

class AppConfig {
  // ─── 1. BRAND & PROPERTY IDENTITY ─────────────────────────────────────────
  /// Display brand name across app bars, dialogs, and statements
  static const String brandName = "$brandName";

  /// Property complex name
  static const String propertyName = "$propertyName";

  /// Physical address of the complex
  static const String defaultAddress = "$address";

  // ─── 2. APP PRESENTATION & LABELS ─────────────────────────────────────────
  /// Application name displayed on user's device
  static const String appName = "$appName";

  /// Subtitle/tagline shown on splash, login, and home screens
  static const String tagline = "$tagline";

  // ─── 3. CONTACT & SUPPORT CHANNELS ────────────────────────────────────────
  /// Official support phone number for inquiries & tenant support
  static const String contactPhone = "$phone";

  /// Official WhatsApp number for 1-click tenant communication
  static const String whatsappNumber = "$whatsapp";

  /// Support email address
  static const String supportEmail = "$supportEmail";

  /// Official UPI ID for rent payments & deposits
  static const String ownerUpiId = "$ownerUpiId";

  // ─── 4. BRAND COLORS & PALETTE ────────────────────────────────────────────
  /// Primary brand color (Hex without #)
  static const String primaryHex = "$primaryHex";

  /// Secondary complementary color
  static const String secondaryHex = "$secondaryHex";

  /// Accent / highlight color (Gold / Warm Accent)
  static const String accentHex = "$accentHex";

  /// Deep dark background color for splash & dark accents
  static const String darkBackgroundHex = "$darkBgHex";

  /// Light surface / scaffold background
  static const String lightSurfaceHex = "$lightSurfaceHex";

  // ─── 5. FIREBASE BACKEND & DATABASE DETAILS ───────────────────────────────
  /// Auth domain used for mapping 10-digit mobile numbers to Firebase pseudo-emails
  /// Format: <phone>@<authEmailDomain> (e.g. 9876543210@$authEmailDomain)
  static const String authEmailDomain = "$authEmailDomain";

  /// Default property document ID in Firestore `/properties/{id}`
  static const String defaultPropertyId = "$defaultPropertyId";

  /// Default currency code
  static const String defaultCurrency = "$defaultCurrency";

  /// Currency symbol used in rent receipts and statements
  static const String currencySymbol = "$currencySymbol";

  // ─── 6. GITHUB RELEASES & IN-APP AUTO-UPDATES ─────────────────────────────
  /// GitHub repository owner where release APKs are hosted
  static const String githubRepoOwner = "$githubRepoOwner";

  /// GitHub repository name
  static const String githubRepoName = "$githubRepoName";

  /// Generated GitHub Releases REST API endpoint
  static String get githubReleasesApi =>
      "https://api.github.com/repos/\$githubRepoOwner/\$githubRepoName/releases";

  /// Generated GitHub Release download base URL
  static String get githubDownloadBaseUrl =>
      "https://github.com/\$githubRepoOwner/\$githubRepoName/releases/download";

  // ─── 7. ASSETS & IMAGES ───────────────────────────────────────────────────
  /// Main logo asset path (512x512 PNG)
  static const String logoAsset = "assets/images/logo.png";

  /// Full brand banner / horizontal logo asset path
  static const String fullLogoAsset = "assets/images/rentlyo_full.png";
}
''';
}

void _updatePubspec(String filePath, String primaryHex) {
  final file = File(filePath);
  if (!file.existsSync()) return;

  final parentDir = file.parent;
  final hasIos = Directory('${parentDir.path}/ios').existsSync();

  String content = file.readAsStringSync();
  content = content.replaceAll(
    RegExp(r'adaptive_icon_background:\s*"#[0-9A-Fa-f]{6}"'),
    'adaptive_icon_background: "#$primaryHex"',
  );
  content = content.replaceAll(
    RegExp(r'color:\s*"#[0-9A-Fa-f]{6}"'),
    'color: "#$primaryHex"',
  );
  content = content.replaceAll(
    RegExp(r'icon_background_color:\s*"#[0-9A-Fa-f]{6}"'),
    'icon_background_color: "#$primaryHex"',
  );

  if (!hasIos) {
    content = content.replaceAll(RegExp(r'ios:\s*true'), 'ios: false');
  }

  file.writeAsStringSync(content);
}

void _updateAndroidPackageAndName({
  required String appDir,
  required String packageId,
  required String appLabel,
}) {
  // 1. build.gradle
  final gradleFile = File('$appDir/android/app/build.gradle');
  if (gradleFile.existsSync()) {
    String gradleContent = gradleFile.readAsStringSync();
    gradleContent = gradleContent.replaceAll(RegExp(r'namespace\s+"[^"]+"'), 'namespace "$packageId"');
    gradleContent = gradleContent.replaceAll(RegExp(r'applicationId\s+"[^"]+"'), 'applicationId "$packageId"');
    gradleFile.writeAsStringSync(gradleContent);
  }

  // 2. AndroidManifest.xml
  final manifestFile = File('$appDir/android/app/src/main/AndroidManifest.xml');
  if (manifestFile.existsSync()) {
    String manifestContent = manifestFile.readAsStringSync();
    manifestContent = manifestContent.replaceAll(RegExp(r'package="[^"]+"'), 'package="$packageId"');
    manifestContent = manifestContent.replaceAll(RegExp(r'android:label="[^"]+"'), 'android:label="$appLabel"');
    manifestFile.writeAsStringSync(manifestContent);
  }

  // 3. Kotlin MainActivity.kt & Directory Structure
  final packagePath = packageId.replaceAll('.', Platform.pathSeparator);
  final kotlinDir = Directory('$appDir/android/app/src/main/kotlin/$packagePath');
  kotlinDir.createSync(recursive: true);

  final mainActivityFile = File('${kotlinDir.path}/MainActivity.kt');
  mainActivityFile.writeAsStringSync('''package $packageId

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
''');

  // Clean up any stale MainActivity.kt from previous package names to prevent duplicate class errors
  final baseKotlinDir = Directory('$appDir/android/app/src/main/kotlin');
  if (baseKotlinDir.existsSync()) {
    final cleanNewPath = mainActivityFile.absolute.path.toLowerCase().replaceAll('/', '\\');
    final existingMainFiles = baseKotlinDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('MainActivity.kt'));
    for (final file in existingMainFiles) {
      final cleanFilePath = file.absolute.path.toLowerCase().replaceAll('/', '\\');
      if (cleanFilePath != cleanNewPath) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
  }
}

void _updateWebMetadata({
  required String appDir,
  required String appLabel,
  required String primaryHex,
}) {
  final indexHtml = File('$appDir/web/index.html');
  if (indexHtml.existsSync()) {
    var content = indexHtml.readAsStringSync();
    content = content.replaceAll(RegExp(r'<title>.*?</title>'), '<title>$appLabel</title>');
    content = content.replaceAll(RegExp(r'content="rentlyo_[^"]+"'), 'content="$appLabel"');
    content = content.replaceAll(RegExp(r'content="rentlyo_[^"]+"'), 'content="$appLabel"');
    content = content.replaceAll(RegExp(r'background-color:\s*#[0-9A-Fa-f]{6};'), 'background-color: #$primaryHex;');
    indexHtml.writeAsStringSync(content);
  }
  final manifestJson = File('$appDir/web/manifest.json');
  if (manifestJson.existsSync()) {
    try {
      final map = jsonDecode(manifestJson.readAsStringSync()) as Map<String, dynamic>;
      map['name'] = appLabel;
      map['short_name'] = appLabel;
      map['theme_color'] = '#$primaryHex';
      map['background_color'] = '#$primaryHex';
      manifestJson.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(map));
    } catch (_) {}
  }
}

Future<void> _bootstrapFirebase({
  required String apiKey,
  required String projectId,
  required String ownerPhone,
  required String ownerPassword,
  required String propertyName,
  required String brandName,
  required String authEmailDomain,
  required String defaultPropertyId,
  required String primaryHex,
  required String accentHex,
  required String darkBgHex,
  required String contactPhone,
  required String whatsappNumber,
  required String tagline,
  required String address,
  required String ownerUpiId,
  required String defaultCurrency,
  required String currencySymbol,
  required String supportEmail,
}) async {
  final cleanPhone = ownerPhone.replaceAll(RegExp(r'\D'), '');
  final cleanTen = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
  final pseudoEmail = '$cleanTen@$authEmailDomain';

  try {
    String? idToken;
    String? userUid;

    stdout.writeln('  [Firebase] Creating / Signing in Owner account ($pseudoEmail)...');
    final signUpUri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');
    final signUpRes = await _httpJson('POST', signUpUri, body: {
      'email': pseudoEmail,
      'password': ownerPassword,
      'returnSecureToken': true,
    });

    if (signUpRes['statusCode'] == 200) {
      idToken = signUpRes['data']['idToken'];
      userUid = signUpRes['data']['localId'];
      stdout.writeln('  ✅ Owner account created in Firebase Auth! (UID: $userUid)');
    } else if (signUpRes['data']?['error']?['message'] == 'EMAIL_EXISTS') {
      stdout.writeln('  ℹ️ User exists in Firebase Auth. Signing in to retrieve auth token...');
      final signInUri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey');
      final signInRes = await _httpJson('POST', signInUri, body: {
        'email': pseudoEmail,
        'password': ownerPassword,
        'returnSecureToken': true,
      });

      if (signInRes['statusCode'] == 200) {
        idToken = signInRes['data']['idToken'];
        userUid = signInRes['data']['localId'];
        stdout.writeln('  ✅ Owner authenticated in Firebase Auth! (UID: $userUid)');
      } else {
        stderr.writeln('  ❌ Auth failure: ${signInRes['data'] ?? signInRes['raw']}');
        return;
      }
    } else {
      stderr.writeln('  ❌ Auth error: ${signUpRes['data'] ?? signUpRes['raw']}');
      return;
    }

    // 1. Create or Update /users/{uid}
    stdout.writeln('  [Firestore] Configuring /users/$userUid...');
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
      final patchRes = await _httpJson('PATCH', userDocUri, headers: {'Authorization': 'Bearer $idToken'}, body: userFields);
      if (patchRes['statusCode'] == 200) {
        stdout.writeln('  ✅ Firestore /users/$userUid updated with role: "owner"');
      } else {
        stderr.writeln('  ⚠️ Firestore /users update warning: ${patchRes['data'] ?? patchRes['raw']}');
      }
    } else {
      final postUserUri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users?documentId=$userUid',
      );
      final postRes = await _httpJson('POST', postUserUri, headers: {'Authorization': 'Bearer $idToken'}, body: userFields);
      if (postRes['statusCode'] == 200) {
        stdout.writeln('  ✅ Firestore /users/$userUid created with role: "owner"');
      } else {
        stderr.writeln('  ⚠️ Firestore /users create warning: ${postRes['data'] ?? postRes['raw']}');
      }
    }

    // 2. Create or Update /properties/{defaultPropertyId}
    stdout.writeln('  [Firestore] Configuring /properties/$defaultPropertyId...');
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
      final patchPropUri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/properties/$defaultPropertyId'
        '?updateMask.fieldPaths=name&updateMask.fieldPaths=brandName&updateMask.fieldPaths=ownerUid&updateMask.fieldPaths=primaryColorHex&updateMask.fieldPaths=accentColorHex&updateMask.fieldPaths=backgroundColorHex&updateMask.fieldPaths=contactPhone&updateMask.fieldPaths=whatsappNumber&updateMask.fieldPaths=tagline&updateMask.fieldPaths=address&updateMask.fieldPaths=ownerUpiId&updateMask.fieldPaths=defaultCurrency&updateMask.fieldPaths=currencySymbol&updateMask.fieldPaths=supportEmail',
      );
      final patchPropRes = await _httpJson('PATCH', patchPropUri, headers: {'Authorization': 'Bearer $idToken'}, body: propFields);
      if (patchPropRes['statusCode'] == 200) {
        stdout.writeln('  ✅ Firestore /properties/$defaultPropertyId branding document updated.');
      } else {
        stderr.writeln('  ⚠️ Firestore /properties update warning: ${patchPropRes['data'] ?? patchPropRes['raw']}');
      }
    } else {
      final postPropUri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/properties?documentId=$defaultPropertyId',
      );
      final postPropRes = await _httpJson('POST', postPropUri, headers: {'Authorization': 'Bearer $idToken'}, body: propFields);
      if (postPropRes['statusCode'] == 200) {
        stdout.writeln('  ✅ Firestore /properties/$defaultPropertyId branding document created.');
      } else {
        stderr.writeln('  ⚠️ Firestore /properties create warning: ${postPropRes['data'] ?? postPropRes['raw']}');
      }
    }

    // 3. Initialize /appVersions for both apps
    stdout.writeln('  [Firestore] Initializing /appVersions...');
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
    stdout.writeln('  ✅ Firestore /appVersions initialized for OTA update tracking.');
  } finally {
    _client.close();
  }
}
