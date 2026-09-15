import 'package:flutter/material.dart';

class FacilityPresetItem {
  final String name;
  final IconData icon;
  final Color color;
  final String defaultNote;

  const FacilityPresetItem({
    required this.name,
    required this.icon,
    required this.color,
    required this.defaultNote,
  });
}

class FacilityIconHelper {
  static const List<FacilityPresetItem> presets = [
    FacilityPresetItem(
      name: 'Mess Food Plan',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFD97706),
      defaultNote: '3 Meals Daily Included',
    ),
    FacilityPresetItem(
      name: 'Separate Electricity Meter',
      icon: Icons.electric_meter_rounded,
      color: Color(0xFFEA580C),
      defaultNote: 'Sub-metered @ Govt tariff / unit',
    ),
    FacilityPresetItem(
      name: 'Water Supply',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF0284C7),
      defaultNote: '24/7 RO Purified Water Included',
    ),
    FacilityPresetItem(
      name: 'Reserved Parking',
      icon: Icons.directions_car_rounded,
      color: Color(0xFF4F46E5),
      defaultNote: 'Dedicated Covered Parking Slot',
    ),
    FacilityPresetItem(
      name: 'Room Cleaning',
      icon: Icons.cleaning_services_rounded,
      color: Color(0xFF059669),
      defaultNote: 'Bi-weekly Room Housekeeping',
    ),
    FacilityPresetItem(
      name: 'Maintenance Included',
      icon: Icons.build_rounded,
      color: Color(0xFF7C3AED),
      defaultNote: 'Full Plumbing & Electrical Upkeep',
    ),
    FacilityPresetItem(
      name: 'High-Speed WiFi',
      icon: Icons.wifi_rounded,
      color: Color(0xFF2563EB),
      defaultNote: '100 Mbps Unlimited Fiber Internet',
    ),
    FacilityPresetItem(
      name: 'CCTV Security',
      icon: Icons.security_rounded,
      color: Color(0xFFDC2626),
      defaultNote: '24/7 Surveillance & Gate Entry',
    ),
    FacilityPresetItem(
      name: 'Washing Machine',
      icon: Icons.local_laundry_service_rounded,
      color: Color(0xFF0D9488),
      defaultNote: 'Laundry Facility Access',
    ),
    FacilityPresetItem(
      name: 'AC & Geyser',
      icon: Icons.ac_unit_rounded,
      color: Color(0xFF0891B2),
      defaultNote: 'In-room Split AC & Hot Geyser',
    ),
  ];

  static IconData getIcon(String facilityName) {
    final lower = facilityName.toLowerCase();
    if (lower.contains('mess') || lower.contains('food') || lower.contains('meal') || lower.contains('canteen') || lower.contains('dining')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('electric') || lower.contains('meter') || lower.contains('power') || lower.contains('light')) {
      return Icons.electric_meter_rounded;
    }
    if (lower.contains('water') || lower.contains('ro') || lower.contains('plumb')) {
      return Icons.water_drop_rounded;
    }
    if (lower.contains('park') || lower.contains('vehicle') || lower.contains('car') || lower.contains('bike')) {
      return Icons.directions_car_rounded;
    }
    if (lower.contains('clean') || lower.contains('housekeeping') || lower.contains('maid') || lower.contains('sweeping')) {
      return Icons.cleaning_services_rounded;
    }
    if (lower.contains('maintain') || lower.contains('repair') || lower.contains('upkeep') || lower.contains('fix')) {
      return Icons.build_rounded;
    }
    if (lower.contains('wifi') || lower.contains('internet') || lower.contains('broadband') || lower.contains('net')) {
      return Icons.wifi_rounded;
    }
    if (lower.contains('cctv') || lower.contains('security') || lower.contains('guard') || lower.contains('camera')) {
      return Icons.security_rounded;
    }
    if (lower.contains('laundry') || lower.contains('wash') || lower.contains('cloth')) {
      return Icons.local_laundry_service_rounded;
    }
    if (lower.contains('ac') || lower.contains('cool') || lower.contains('geyser') || lower.contains('air condition')) {
      return Icons.ac_unit_rounded;
    }
    if (lower.contains('gym') || lower.contains('fitness') || lower.contains('workout')) {
      return Icons.fitness_center_rounded;
    }
    if (lower.contains('lift') || lower.contains('elevator')) {
      return Icons.elevator_rounded;
    }
    if (lower.contains('tv') || lower.contains('television') || lower.contains('cable')) {
      return Icons.tv_rounded;
    }
    if (lower.contains('gas') || lower.contains('cylinder') || lower.contains('kitchen')) {
      return Icons.local_gas_station_rounded;
    }
    return Icons.star_rounded;
  }

  static Color getColor(String facilityName) {
    final lower = facilityName.toLowerCase();
    if (lower.contains('mess') || lower.contains('food') || lower.contains('meal') || lower.contains('canteen')) {
      return const Color(0xFFD97706);
    }
    if (lower.contains('electric') || lower.contains('meter') || lower.contains('power')) {
      return const Color(0xFFEA580C);
    }
    if (lower.contains('water') || lower.contains('ro')) {
      return const Color(0xFF0284C7);
    }
    if (lower.contains('park') || lower.contains('vehicle')) {
      return const Color(0xFF4F46E5);
    }
    if (lower.contains('clean') || lower.contains('housekeeping')) {
      return const Color(0xFF059669);
    }
    if (lower.contains('maintain') || lower.contains('repair')) {
      return const Color(0xFF7C3AED);
    }
    if (lower.contains('wifi') || lower.contains('internet')) {
      return const Color(0xFF2563EB);
    }
    if (lower.contains('cctv') || lower.contains('security')) {
      return const Color(0xFFDC2626);
    }
    if (lower.contains('laundry') || lower.contains('wash')) {
      return const Color(0xFF0D9488);
    }
    if (lower.contains('ac') || lower.contains('cool') || lower.contains('geyser')) {
      return const Color(0xFF0891B2);
    }
    if (lower.contains('gym') || lower.contains('fitness')) {
      return const Color(0xFFBE185D);
    }
    return const Color(0xFF0F766E);
  }
}
