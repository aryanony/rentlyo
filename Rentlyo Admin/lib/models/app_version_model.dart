import 'package:cloud_firestore/cloud_firestore.dart';

class AppVersionModel {
  final String latestVersionName;
  final int latestBuildNumber;
  final String downloadUrl;
  final String changelogEn;
  final String changelogHi;
  final bool forceUpdate;
  final DateTime? releasedAt;

  AppVersionModel({
    required this.latestVersionName,
    required this.latestBuildNumber,
    required this.downloadUrl,
    required this.changelogEn,
    required this.changelogHi,
    this.forceUpdate = false,
    this.releasedAt,
  });

  factory AppVersionModel.fromMap(Map<String, dynamic> map) {
    return AppVersionModel(
      latestVersionName: map['latestVersionName'] ?? '1.0.0',
      latestBuildNumber: (map['latestBuildNumber'] as num?)?.toInt() ?? 1,
      downloadUrl: map['downloadUrl'] ?? 'https://github.com/aryanony/arya-spaces-releases/releases/download/renter-v1.0.0/app-release.apk',
      changelogEn: map['changelogEn'] ?? 'Bug fixes and performance updates.',
      changelogHi: map['changelogHi'] ?? 'बग सुधार और नए फीचर्स अपडेट किए गए हैं।',
      forceUpdate: map['forceUpdate'] == true,
      releasedAt: (map['releasedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latestVersionName': latestVersionName,
      'latestBuildNumber': latestBuildNumber,
      'downloadUrl': downloadUrl,
      'changelogEn': changelogEn,
      'changelogHi': changelogHi,
      'forceUpdate': forceUpdate,
      'releasedAt': releasedAt != null ? Timestamp.fromDate(releasedAt!) : null,
    };
  }
}
