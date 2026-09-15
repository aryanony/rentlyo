import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'phone_utils.dart';

class LocalSecurity {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );

  static const String _pinKey = 'user_app_pin';
  static const String _phoneKey = 'saved_user_phone';
  static const String _passwordKey = 'saved_user_password';
  static DateTime? _lastPausedTime;

  static Future<bool> isPinSet() async {
    try {
      String? pin = await _storage.read(key: _pinKey);
      return pin != null && pin.isNotEmpty;
    } catch (e) {
      debugPrint("Error reading PIN: $e");
      return false;
    }
  }

  static Future<void> savePin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  static Future<bool> verifyPin(String enteredPin) async {
    try {
      String? pin = await _storage.read(key: _pinKey);
      return pin == enteredPin;
    } catch (e) {
      return false;
    }
  }

  static Future<void> clearPin() async {
    await _storage.delete(key: _pinKey);
  }

  static Future<void> saveCredentials(String phone, String password) async {
    await _storage.write(key: _phoneKey, value: phone);
    await _storage.write(key: _passwordKey, value: password);
  }

  static Future<Map<String, String>?> getSavedCredentials() async {
    try {
      final phone = await _storage.read(key: _phoneKey);
      final password = await _storage.read(key: _passwordKey);
      if (phone != null && phone.isNotEmpty && password != null && password.isNotEmpty) {
        return {'phone': phone, 'password': password};
      }
    } catch (e) {
      debugPrint("Error reading saved credentials: $e");
    }
    return null;
  }

  static Future<void> clearCredentials() async {
    await _storage.delete(key: _phoneKey);
    await _storage.delete(key: _passwordKey);
    await clearPin();
  }

  static Future<bool> ensureSilentAutoLogin() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        return true;
      }

      final creds = await getSavedCredentials();
      if (creds != null) {
        final phone = creds['phone']!;
        final password = creds['password']!;
        final pseudoEmail = PhoneUtils.toPseudoEmail(phone);

        final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: pseudoEmail,
          password: password,
        );

        return userCred.user != null;
      }
    } catch (e) {
      debugPrint("Silent auto login note: $e");
    }
    return FirebaseAuth.instance.currentUser != null;
  }

  static int _failedPinAttempts = 0;
  static DateTime? _lockoutUntil;

  static bool isLockedOut() {
    if (_lockoutUntil == null) return false;
    if (DateTime.now().isAfter(_lockoutUntil!)) {
      _lockoutUntil = null;
      _failedPinAttempts = 0;
      return false;
    }
    return true;
  }

  static int getRemainingLockoutSeconds() {
    if (_lockoutUntil == null) return 0;
    final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  static void recordFailedPinAttempt() {
    _failedPinAttempts++;
    if (_failedPinAttempts >= 5) {
      _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
    }
  }

  static void recordSuccessfulPinAttempt() {
    _failedPinAttempts = 0;
    _lockoutUntil = null;
  }

  static void recordPause() {
    _lastPausedTime = DateTime.now();
  }

  static bool shouldPromptPin() {
    if (_lastPausedTime == null) return false;
    final diff = DateTime.now().difference(_lastPausedTime!);
    _lastPausedTime = null;
    return diff.inSeconds >= 30;
  }
}
