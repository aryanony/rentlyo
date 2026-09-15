import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/brand_config.dart';
import '../core/app_config.dart';
import '../core/localization.dart';
import '../core/local_security.dart';
import '../core/phone_utils.dart';
import 'pin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  String _getFriendlyErrorMessage(String code, String? rawMessage) {
    final msg = (rawMessage ?? '').toLowerCase();
    if (code == 'network-request-failed' || msg.contains('network')) {
      return AppLocalization.tr('err_no_internet');
    }
    if (code == 'too-many-requests' || msg.contains('too-many-requests')) {
      return AppLocalization.tr('err_too_many_attempts');
    }
    if (code == 'user-disabled' || msg.contains('user-disabled')) {
      return AppLocalization.tr('err_account_disabled');
    }
    return AppLocalization.tr('err_invalid_credentials');
  }

  Future<void> _handleLogin() async {
    final rawPhone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (rawPhone.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = AppLocalization.tr('err_empty_login'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final pseudoEmail = PhoneUtils.toPseudoEmail(rawPhone);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: pseudoEmail,
        password: password,
      );

      await LocalSecurity.saveCredentials(rawPhone, password);

      if (mounted) {
        final isPinSet = await LocalSecurity.isPinSet();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => PinScreen(isSetup: !isPinSet)),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFriendlyErrorMessage(e.code, e.message);
      });
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalization.tr('err_invalid_credentials');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocalization.currentLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Big Size Logo Image - seamlessly blends into white background
                  SizedBox(
                    height: 220,
                    child: BrandConfig.buildLogoWidget(
                      fit: BoxFit.contain,
                      defaultAsset: AppConfig.fullLogoAsset,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Portal Subtitle Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withAlpha(15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryNavy.withAlpha(40)),
                    ),
                    child: Text(
                      BrandConfig.tagline.isNotEmpty ? BrandConfig.tagline : 'Property Owner & Admin Console',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Login Form Container
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryNavy.withAlpha(18),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.statusRed.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.statusRed),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppTheme.statusRed),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppTheme.statusRed,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Text(
                          AppLocalization.tr('phone_number'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 17, color: AppTheme.primaryNavy, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'e.g. 919876543210',
                            prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.primaryNavy),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAF9),
                          ),
                        ),
                        const SizedBox(height: 18),

                        Text(
                          AppLocalization.tr('password'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(fontSize: 17, color: AppTheme.primaryNavy, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryNavy),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAF9),
                          ),
                        ),
                        const SizedBox(height: 26),

                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNavy,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 3,
                          ),
                          onPressed: _isLoading ? null : _handleLogin,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                )
                              : const Icon(Icons.login, size: 22),
                          label: Text(
                            AppLocalization.tr('login'),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Language Switcher Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryNavy,
                      side: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    onPressed: AppLocalization.toggleLanguage,
                    icon: const Icon(Icons.language, size: 18),
                    label: Text(
                      AppLocalization.tr('language'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Highly Responsive & Premium Developer Credit Badge
                  InkWell(
                    onTap: () async {
                      final Uri url = Uri.parse('https://aryanony.pages.dev/');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy.withAlpha(12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.goldAccent.withAlpha(140)),
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
                                color: AppTheme.primaryNavy,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
