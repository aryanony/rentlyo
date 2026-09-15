import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arya_spaces_admin/widgets/app_loader.dart';
import 'package:arya_spaces_admin/models/app_version_model.dart';

void main() {
  testWidgets('AppLoader renders correctly with message', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppLoader(message: 'Testing App Loader...'),
      ),
    );

    expect(find.text('Testing App Loader...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AppSplashScreen renders title and logo container', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppSplashScreen(subtitle: 'Connecting...'),
      ),
    );

    expect(find.text('Connecting...'), findsOneWidget);
  });

  test('AppVersionModel deserializes and evaluates version build number correctly', () {
    final map = {
      'latestVersionName': '1.1.0',
      'latestBuildNumber': 3,
      'downloadUrl': 'https://github.com/owner/repo/releases/download/v1.1.0/app-release.apk',
      'changelogEn': 'New dashboard and self-update feature',
      'changelogHi': 'नया डैशबोर्ड और सेल्फ-अपडेट फीचर',
      'forceUpdate': false,
    };

    final model = AppVersionModel.fromMap(map);

    expect(model.latestVersionName, equals('1.1.0'));
    expect(model.latestBuildNumber, equals(3));
    expect(model.downloadUrl, contains('app-release.apk'));
    expect(model.forceUpdate, isFalse);
    expect(model.latestBuildNumber > 1, isTrue); // Comparison against build 1
  });
}
