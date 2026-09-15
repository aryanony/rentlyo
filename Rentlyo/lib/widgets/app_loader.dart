import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/brand_config.dart';
import '../core/app_config.dart';

/// Branded splash screen displayed during app launch & initial state loading.
class AppSplashScreen extends StatelessWidget {
  final String? subtitle;

  const AppSplashScreen({super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              BrandConfig.primaryColor,
              Color.lerp(BrandConfig.primaryColor, Colors.black, 0.35)!,
              BrandConfig.backgroundColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Full Filled Big Size Logo Card Container with Ambient Glow
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                  maxHeight: 320,
                ),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.goldAccent.withAlpha(80),
                      blurRadius: 30,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(120),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: BrandConfig.buildLogoWidget(
                  fit: BoxFit.contain,
                  defaultAsset: AppConfig.fullLogoAsset,
                ),
              ),

              const SizedBox(height: 24),

              // Subtitle Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.goldAccent.withAlpha(160)),
                ),
                child: Text(
                  subtitle ?? BrandConfig.tagline,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.goldAccent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Gold Accent Circular Progress Indicator
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.goldAccent),
                ),
              ),

              const Spacer(),

              // Footer text with Developer Credit
              Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.goldAccent.withAlpha(100)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.code_rounded, color: AppTheme.goldAccent, size: 16),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Engineered by Aaryan Gupta • aryanony.pages.dev',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable inline loading indicator with full filled logo badge for in-app data fetching.
class AppLoader extends StatelessWidget {
  final String? message;
  final double logoSize;

  const AppLoader({
    super.key,
    this.message,
    this.logoSize = 140,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandConfig.primaryColor,
            Color.lerp(BrandConfig.primaryColor, Colors.black, 0.35)!,
            BrandConfig.backgroundColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Big Size Logo Container with Glowing Gradient Card
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.82,
                maxHeight: 280,
              ),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.goldAccent.withAlpha(80),
                    blurRadius: 26,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha(100),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: BrandConfig.buildLogoWidget(
                fit: BoxFit.contain,
                defaultAsset: AppConfig.fullLogoAsset,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3.2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.goldAccent),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 18),
              Text(
                message!,
                style: const TextStyle(
                  color: AppTheme.goldAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
