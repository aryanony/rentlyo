import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/brand_config.dart';
import '../core/app_config.dart';
import '../core/local_security.dart';
import '../core/localization.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class PinScreen extends StatefulWidget {
  final bool isSetup;
  const PinScreen({super.key, this.isSetup = false});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isCheckMode = false;
  String _message = '';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _checkExistingPin();
  }

  Future<void> _checkExistingPin() async {
    final hasPin = await LocalSecurity.isPinSet();
    setState(() {
      _isCheckMode = hasPin && !widget.isSetup;
      _message = _isCheckMode ? AppLocalization.tr('enter_pin') : AppLocalization.tr('set_pin');
    });
  }

  void _onKeyPress(String digit) {
    if (_pin.length < 6) {
      setState(() {
        _pin += digit;
        _isError = false;
      });

      if (_pin.length == 6) {
        _handlePinComplete();
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _isError = false;
      });
    }
  }

  Future<void> _handlePinComplete() async {
    if (_isCheckMode) {
      if (LocalSecurity.isLockedOut()) {
        final secs = LocalSecurity.getRemainingLockoutSeconds();
        setState(() {
          _isError = true;
          _message = '${AppLocalization.tr('pin_lockout')} ${secs}s.';
          _pin = '';
        });
        return;
      }

      final isValid = await LocalSecurity.verifyPin(_pin);
      if (isValid) {
        LocalSecurity.recordSuccessfulPinAttempt();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        LocalSecurity.recordFailedPinAttempt();
        if (LocalSecurity.isLockedOut()) {
          final secs = LocalSecurity.getRemainingLockoutSeconds();
          setState(() {
            _isError = true;
            _message = '${AppLocalization.tr('pin_lockout')} ${secs}s.';
            _pin = '';
          });
        } else {
          setState(() {
            _isError = true;
            _message = AppLocalization.tr('incorrect_pin');
            _pin = '';
          });
        }
      }
    } else if (!_isConfirming) {
      setState(() {
        _confirmPin = _pin;
        _pin = '';
        _isConfirming = true;
        _message = AppLocalization.tr('confirm_pin');
      });
    } else {
      if (_pin == _confirmPin) {
        await LocalSecurity.savePin(_pin);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        setState(() {
          _isError = true;
          _message = AppLocalization.tr('pin_mismatch');
          _pin = '';
          _confirmPin = '';
          _isConfirming = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await LocalSecurity.clearCredentials();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(),
                      // Big Size Logo Image - seamlessly blends into white background
                      SizedBox(
                        height: 200,
                        child: BrandConfig.buildLogoWidget(
                          fit: BoxFit.contain,
                          defaultAsset: AppConfig.fullLogoAsset,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNavy.withAlpha(15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primaryNavy.withAlpha(40)),
                        ),
                        child: Text(
                          BrandConfig.tagline.isNotEmpty ? BrandConfig.tagline : 'Admin Security Console',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryNavy,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isError ? AppTheme.statusRed : AppTheme.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          final filled = index < _pin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled ? AppTheme.goldAccent : const Color(0xFFF1F5F9),
                              border: Border.all(
                                color: filled ? AppTheme.primaryNavy : const Color(0xFFCBD5E1),
                                width: 2,
                              ),
                              boxShadow: filled
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.goldAccent.withAlpha(80),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),
                      const Spacer(),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryNavy.withAlpha(12),
                              blurRadius: 16,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            for (var row in [
                              ['1', '2', '3'],
                              ['4', '5', '6'],
                              ['7', '8', '9'],
                              ['logout', '0', 'backspace']
                            ])
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: row.map((key) {
                                    if (key == 'logout') {
                                      return IconButton(
                                        tooltip: 'Logout',
                                        icon: const Icon(Icons.logout, color: AppTheme.statusRed, size: 28),
                                        onPressed: _logout,
                                      );
                                    } else if (key == 'backspace') {
                                      return IconButton(
                                        tooltip: 'Delete',
                                        icon: const Icon(Icons.backspace_outlined, color: AppTheme.primaryNavy, size: 28),
                                        onPressed: _onDelete,
                                      );
                                    } else {
                                      return InkWell(
                                        onTap: () => _onKeyPress(key),
                                        borderRadius: BorderRadius.circular(40),
                                        child: Container(
                                          width: 68,
                                          height: 68,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFFF8FAF9),
                                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.primaryNavy.withAlpha(12),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            key,
                                            style: const TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryNavy,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }).toList(),
                                ),
                              ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: () async {
                                final Uri url = Uri.parse('https://aryanony.pages.dev/');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryNavy.withAlpha(12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.goldAccent.withAlpha(140)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.code_rounded, color: AppTheme.goldAccent, size: 15),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Engineered by Aaryan Gupta • aryanony.pages.dev',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppTheme.primaryNavy,
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
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
