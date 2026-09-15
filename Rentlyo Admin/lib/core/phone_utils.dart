import 'app_config.dart';

class PhoneUtils {
  /// Extracts exactly the 10-digit mobile number from any input format.
  /// Handles +91, 91, 0, spaces, hyphens, and non-digit characters.
  static String sanitizeTenDigitPhone(String raw) {
    String digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// Converts any raw phone input to a clean 10-digit pseudo-email for Auth
  static String toPseudoEmail(String rawPhone) {
    final cleanTen = sanitizeTenDigitPhone(rawPhone);
    return "$cleanTen@${AppConfig.authEmailDomain}";
  }
}
