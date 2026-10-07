import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Optional native screenshots for local review. Run with flutter run to keep
/// the test app/container after completion, then copy these files to the host.
Future<void> captureSocialScreen(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  if (!const bool.fromEnvironment('SOCIAL_SCREENSHOTS')) return;
  await tester.pumpAndSettle();
  if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
  final bytes = await binding.takeScreenshot(name);
  final directory = await getApplicationSupportDirectory();
  final screenshots = Directory('${directory.path}/social-test-screenshots');
  await screenshots.create(recursive: true);
  await File('${screenshots.path}/$name.png').writeAsBytes(bytes);
}
