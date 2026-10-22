import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:sophis/ui/components/ai_food_image_tile.dart';
import 'package:sophis/ui/screens/ai_food_camera_screen.dart';

import '../helpers/test_services.dart';

class _GalleryPicker extends ImagePickerPlatform {
  final List<XFile> images = [];
  int? requestedLimit;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    requestedLimit = options.limit;
    return images;
  }
}

void main() {
  testWidgets('gallery retained five selected images and enforced capacity', (
    tester,
  ) async {
    final originalPicker = ImagePickerPlatform.instance;
    final picker = _GalleryPicker();
    ImagePickerPlatform.instance = picker;
    final directory = Directory.systemTemp.createTempSync('sophis-gallery-');
    addTearDown(() {
      ImagePickerPlatform.instance = originalPicker;
      directory.deleteSync(recursive: true);
    });
    final bytes = img.encodePng(img.Image(width: 2, height: 2));
    for (var i = 0; i < 6; i++) {
      final file = File('${directory.path}/$i.png')..writeAsBytesSync(bytes);
      picker.images.add(XFile(file.path));
    }
    final settings = await createWidgetTestSettingsProvider(tester);
    await settings.setGeminiApiKey('test-key');
    await pumpTestApp(
      tester,
      const AIFoodCameraScreen(meal: 'breakfast'),
      settingsProvider: settings,
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();

    expect(picker.requestedLimit, 5);
    expect(find.textContaining('5/5'), findsOneWidget);
    final preview = tester.widget<ListView>(find.byType(ListView).first);
    expect(preview.childrenDelegate.estimatedChildCount, 5);
    expect(find.byType(AiFoodImageTile), findsWidgets);
    final gallery = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Gallery'),
    );
    expect(gallery.onPressed, isNull);
  });

  testWidgets('AI screen opens Gemini settings when the key is missing', (
    tester,
  ) async {
    final settings = await createWidgetTestSettingsProvider(tester);

    await pumpTestApp(
      tester,
      const AIFoodCameraScreen(meal: 'breakfast'),
      settingsProvider: settings,
      locale: const Locale('de'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gemini-Key eintragen'), findsOneWidget);

    await tester.tap(find.text('Gemini-Key eintragen'));
    await tester.pumpAndSettle();

    expect(find.text('Gemini API Key'), findsOneWidget);
    expect(find.text('API Key eingeben'), findsOneWidget);
  });
}
