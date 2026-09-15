import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_config.dart';

class BrandConfig {
  // Compile-time safe defaults sourced directly from centralized AppConfig
  static const defaultBrandName = AppConfig.brandName;
  static const defaultPrimaryHex = AppConfig.primaryHex;
  static const defaultAccentHex = AppConfig.accentHex;
  static const defaultBackgroundHex = AppConfig.darkBackgroundHex;

  static String brandName = AppConfig.brandName;
  static Color primaryColor = _hex(AppConfig.primaryHex);
  static Color accentColor = _hex(AppConfig.accentHex);
  static Color backgroundColor = _hex(AppConfig.darkBackgroundHex);
  static String? logoBase64;
  static String tagline = AppConfig.tagline;
  static String contactPhone = AppConfig.contactPhone;
  static String whatsappNumber = AppConfig.whatsappNumber;

  /// ValueNotifier to allow reactive UI updates whenever BrandConfig changes
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  /// Load brand configuration dynamically from Firestore
  static Future<void> load([String? propertyId]) async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? doc;
      final targetId = propertyId ?? AppConfig.defaultPropertyId;

      final specificDoc = await FirebaseFirestore.instance.collection('properties').doc(targetId).get();
      if (specificDoc.exists && specificDoc.data() != null) {
        doc = specificDoc;
      } else {
        final snap = await FirebaseFirestore.instance.collection('properties').limit(1).get();
        if (snap.docs.isNotEmpty) {
          doc = snap.docs.first;
        }
      }
      if (doc != null && doc.exists && doc.data() != null) {
        final d = doc.data()!;
        brandName = (d['brandName'] as String?) ?? (d['name'] as String?) ?? AppConfig.brandName;
        primaryColor = _hex(d['primaryColorHex'] as String? ?? AppConfig.primaryHex);
        accentColor = _hex(d['accentColorHex'] as String? ?? AppConfig.accentHex);
        backgroundColor = _hex(d['backgroundColorHex'] as String? ?? AppConfig.darkBackgroundHex);
        logoBase64 = d['logoBase64'] as String?;
        tagline = (d['tagline'] as String?) ?? tagline;
        contactPhone = (d['contactPhone'] as String?) ?? contactPhone;
        whatsappNumber = (d['whatsappNumber'] as String?) ?? whatsappNumber;
        notifier.value++;
      }
    } catch (e) {
      debugPrint("BrandConfig load note: $e");
    }
  }

  /// Helper widget to render custom base64 logo or fallback to asset logo
  static Widget buildLogoWidget({
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    String defaultAsset = AppConfig.fullLogoAsset,
  }) {
    if (logoBase64 != null && logoBase64!.trim().isNotEmpty) {
      try {
        final bytes = base64Decode(logoBase64!.trim());
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => Image.asset(
            defaultAsset,
            width: width,
            height: height,
            fit: fit,
          ),
        );
      } catch (_) {}
    }
    return Image.asset(
      defaultAsset,
      width: width,
      height: height,
      fit: fit,
    );
  }

  static Color _hex(String h) {
    try {
      final clean = h.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF083B4C);
  }
}
