// ============================================================================
// 🏷️ APP CONFIGURATION — CENTRALIZED WHITE-LABEL SETUP (TENANT COMPANION)
// ============================================================================
// This is the SINGLE Dart file to configure if setting up manually without scripts.
// All values below represent the client's configuration variables.
// ============================================================================

class AppConfig {
  // ─── 1. BRAND & PROPERTY IDENTITY ─────────────────────────────────────────
  /// Display brand name across app bars, dialogs, and statements
  static const String brandName = "Royal Complex";

  /// Property complex name
  static const String propertyName = "Royal Complex";

  /// Physical address of the complex
  static const String defaultAddress = "Jaipur, Rajasthan, India";

  // ─── 2. APP PRESENTATION & LABELS ─────────────────────────────────────────
  /// Application name displayed on user's device
  static const String appName = "Rentlyo";

  /// Subtitle/tagline shown on splash, login, and home screens
  static const String tagline = "Tenant Companion • LeaseSync Portal";

  // ─── 3. CONTACT & SUPPORT CHANNELS ────────────────────────────────────────
  /// Official support phone number for inquiries & tenant support
  static const String contactPhone = "+91 93084 89230";

  /// Official WhatsApp number for 1-click tenant communication
  static const String whatsappNumber = "+91 93084 89230";

  /// Support email address
  static const String supportEmail = "support@rentlyo.com";

  /// Official UPI ID for rent payments & deposits
  static const String ownerUpiId = "rentlyo@upi";

  // ─── 4. BRAND COLORS & PALETTE ────────────────────────────────────────────
  /// Primary brand color (Hex without #)
  static const String primaryHex = "044040";

  /// Secondary complementary color
  static const String secondaryHex = "CF9D30";

  /// Accent / highlight color (Gold / Warm Accent)
  static const String accentHex = "C58B2B";

  /// Deep dark background color for splash & dark accents
  static const String darkBackgroundHex = "041B23";

  /// Light surface / scaffold background
  static const String lightSurfaceHex = "F8FAF9";

  // ─── 5. FIREBASE BACKEND & DATABASE DETAILS ───────────────────────────────
  /// Auth domain used for mapping 10-digit mobile numbers to Firebase pseudo-emails
  /// Format: <phone>@<authEmailDomain> (e.g. 9876543210@rentlyo.local)
  static const String authEmailDomain = "rentlyo.local";

  /// Default property document ID in Firestore `/properties/{id}`
  static const String defaultPropertyId = "royal_complex";

  /// Default currency code
  static const String defaultCurrency = "INR";

  /// Currency symbol used in rent receipts and statements
  static const String currencySymbol = "₹";

  // ─── 6. GITHUB RELEASES & IN-APP AUTO-UPDATES ─────────────────────────────
  /// GitHub repository owner where release APKs are hosted
  static const String githubRepoOwner = "aryanony";

  /// GitHub repository name
  static const String githubRepoName = "rentlyo";

  /// Generated GitHub Releases REST API endpoint
  static String get githubReleasesApi =>
      "https://api.github.com/repos/$githubRepoOwner/$githubRepoName/releases";

  /// Generated GitHub Release download base URL
  static String get githubDownloadBaseUrl =>
      "https://github.com/$githubRepoOwner/$githubRepoName/releases/download";

  // ─── 7. ASSETS & IMAGES ───────────────────────────────────────────────────
  /// Main logo asset path (512x512 PNG)
  static const String logoAsset = "assets/images/logo.png";

  /// Full brand banner / horizontal logo asset path
  static const String fullLogoAsset = "assets/images/rentlyo_full.png";
}
