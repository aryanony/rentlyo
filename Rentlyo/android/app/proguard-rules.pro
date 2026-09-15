# ProGuard Obfuscation & Security Hardening Rules for Arya Spaces

# Flutter Core Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase Rules
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Cryptography & Security Rules
-keep class javax.crypto.** { *; }
-dontwarn javax.crypto.**

# Suppress warnings
-dontwarn android.util.Log
