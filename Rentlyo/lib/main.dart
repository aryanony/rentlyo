import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/brand_config.dart';
import 'core/theme.dart';
import 'core/local_security.dart';
import 'screens/login_screen.dart';
import 'screens/pin_screen.dart';
import 'widgets/app_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Catch Flutter framework errors gracefully to prevent instant app closure
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("Caught Flutter error: ${details.exception}");
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("Caught global async error: $error");
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.amber, size: 48),
              const SizedBox(height: 12),
              const Text('An unexpected display issue occurred.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(details.exception.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  };

  try {
    await Firebase.initializeApp();
    await BrandConfig.load();
  } catch (e) {
    debugPrint("Firebase init note: $e");
  }

  runApp(const AryaSpacesRenterApp());
}

class AryaSpacesRenterApp extends StatefulWidget {
  const AryaSpacesRenterApp({super.key});

  @override
  State<AryaSpacesRenterApp> createState() => _AryaSpacesRenterAppState();
}

class _AryaSpacesRenterAppState extends State<AryaSpacesRenterApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      LocalSecurity.recordPause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: BrandConfig.notifier,
      builder: (context, _, __) {
        return MaterialApp(
          title: BrandConfig.brandName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          builder: (context, child) {
            final mediaQueryData = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQueryData.copyWith(
                textScaler: mediaQueryData.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.15),
              ),
              child: child!,
            );
          },
          home: FutureBuilder<bool>(
            future: LocalSecurity.ensureSilentAutoLogin(),
            builder: (context, autoLoginSnap) {
              if (autoLoginSnap.connectionState == ConnectionState.waiting) {
                return const AppSplashScreen(subtitle: 'Connecting...');
              }

              return StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, authSnap) {
                  final user = authSnap.data ?? FirebaseAuth.instance.currentUser;

                  if (user != null) {
                    return FutureBuilder<bool>(
                      future: LocalSecurity.isPinSet(),
                      builder: (context, pinSnap) {
                        if (pinSnap.connectionState == ConnectionState.waiting) {
                          return const AppSplashScreen(subtitle: 'Securing session...');
                        }
                        final isPinSet = pinSnap.data ?? false;
                        return PinScreen(isSetup: !isPinSet);
                      },
                    );
                  }

                  return const LoginScreen();
                },
              );
            },
          ),
        );
      },
    );
  }
}
