import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/gemini_food_service.dart';
import 'package:sophis/services/label_intake_flow.dart';
import 'package:sophis/services/service_result.dart';

class _MockGemini extends Mock implements GeminiFoodService {}

void main() {
  group('LabelIntakeFlow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    const wellFormedOcr = '''
Nährwertangaben pro 100g:
Brennwert 2000 kJ / 480 kcal
Fett 20 g
Kohlenhydrate 50 g
Ballaststoffe 5 g
Eiweiß 10 g
''';

    test('parses a well-formed label locally without Gemini', () async {
      final flow = LabelIntakeFlow();

      final result = await flow.processOcrText(
        ocrText: wellFormedOcr,
        idGenerator: () => 'test-id-1',
      );

      expect(result.isSuccess, isTrue);
      final intake = result.valueOrNull!;
      expect(intake.label.caloriesPer100g, 480);
      expect(intake.label.proteinPer100g, 10);
      expect(intake.label.carbsPer100g, 50);
      expect(intake.label.fatPer100g, 20);
      expect(intake.label.fiberPer100g, 5);
      expect(intake.product.id, 'test-id-1');
      expect(intake.product.caloriesPer100g, 480);
    });

    test('uses fallbackProductName when label has no product name', () async {
      final flow = LabelIntakeFlow();

      final result = await flow.processOcrText(
        ocrText: wellFormedOcr,
        idGenerator: () => 'id',
        fallbackProductName: 'Scanned Default',
      );

      final intake = result.valueOrNull!;
      expect(intake.product.name, 'Scanned Default');
    });

    test('uses fallbackBrand when label has no brand', () async {
      final flow = LabelIntakeFlow();

      final result = await flow.processOcrText(
        ocrText: wellFormedOcr,
        idGenerator: () => 'id',
        fallbackBrand: 'Fallback Brand',
      );

      final intake = result.valueOrNull!;
      expect(intake.product.brand, 'Fallback Brand');
    });

    test('preserves label brand over fallback', () async {
      final gemini = _MockGemini();
      when(() => gemini.hasApiKey).thenReturn(true);
      when(() => gemini.parseNutritionText(any())).thenAnswer(
        (_) async => const Success<NutritionLabelResult?>(
          NutritionLabelResult(
            brand: 'Label Brand',
            caloriesPer100g: 250,
            proteinPer100g: 12,
            carbsPer100g: 30,
            fatPer100g: 8,
            fiberPer100g: 4,
          ),
        ),
      );

      final flow = LabelIntakeFlow(gemini: gemini);

      final result = await flow.processOcrText(
        ocrText: 'unreadable',
        idGenerator: () => 'id',
        fallbackBrand: 'Fallback Brand',
      );

      final intake = result.valueOrNull!;
      expect(intake.label.brand, 'Label Brand');
      expect(intake.product.brand, 'Label Brand');
    });

    test('returns Failure when OCR text is unparseable and no Gemini', () async {
      final flow = LabelIntakeFlow();

      final result = await flow.processOcrText(
        ocrText: 'this is not a label at all',
        idGenerator: () => 'id',
      );

      expect(result.isFailure, isTrue);
      final failure = result as Failure<LabelIntakeResult>;
      expect(failure.errorType, ServiceErrorType.parseError);
    });

    test('falls back to Gemini when local parse fails', () async {
      final gemini = _MockGemini();
      when(() => gemini.hasApiKey).thenReturn(true);
      when(() => gemini.parseNutritionText(any())).thenAnswer(
        (_) async => const Success<NutritionLabelResult?>(
          NutritionLabelResult(
            productName: 'Gemini Product',
            caloriesPer100g: 250,
            proteinPer100g: 12,
            carbsPer100g: 30,
            fatPer100g: 8,
            fiberPer100g: 4,
          ),
        ),
      );

      final flow = LabelIntakeFlow(gemini: gemini);

      final result = await flow.processOcrText(
        ocrText: 'totally unreadable',
        idGenerator: () => 'id',
      );

      expect(result.isSuccess, isTrue);
      final intake = result.valueOrNull!;
      expect(intake.label.caloriesPer100g, 250);
      expect(intake.product.name, 'Gemini Product');
      verify(() => gemini.parseNutritionText('totally unreadable')).called(1);
    });

    test('returns Failure when both local parse and Gemini fail', () async {
      final gemini = _MockGemini();
      when(() => gemini.hasApiKey).thenReturn(true);
      when(() => gemini.parseNutritionText(any())).thenAnswer(
        (_) async => const Failure<NutritionLabelResult?>(
          ServiceErrorType.network,
          'timeout',
        ),
      );

      final flow = LabelIntakeFlow(gemini: gemini);

      final result = await flow.processOcrText(
        ocrText: 'still not a label',
        idGenerator: () => 'id',
      );

      expect(result.isFailure, isTrue);
      final failure = result as Failure<LabelIntakeResult>;
      expect(failure.errorType, ServiceErrorType.parseError);
    });

    test('skips Gemini when local parse already succeeded', () async {
      final gemini = _MockGemini();
      when(() => gemini.hasApiKey).thenReturn(true);

      final flow = LabelIntakeFlow(gemini: gemini);

      await flow.processOcrText(
        ocrText: wellFormedOcr,
        idGenerator: () => 'id',
      );

      verifyNever(() => gemini.parseNutritionText(any()));
    });

    test('skips Gemini when Gemini has no API key', () async {
      final gemini = _MockGemini();
      when(() => gemini.hasApiKey).thenReturn(false);

      final flow = LabelIntakeFlow(gemini: gemini);

      final result = await flow.processOcrText(
        ocrText: 'totally unreadable',
        idGenerator: () => 'id',
      );

      expect(result.isFailure, isTrue);
      verifyNever(() => gemini.parseNutritionText(any()));
    });

    test('rejects calories==0 from local parser', () async {
      final flow = LabelIntakeFlow();

      const ocrWithZeroCalories = '''
Nährwertangaben pro 100g:
Brennwert 0 kcal
Fett 0 g
Kohlenhydrate 0 g
Eiweiß 0 g
''';

      final result = await flow.processOcrText(
        ocrText: ocrWithZeroCalories,
        idGenerator: () => 'id',
      );

      expect(result.isFailure, isTrue);
      final failure = result as Failure<LabelIntakeResult>;
      expect(failure.errorType, ServiceErrorType.parseError);
    });

    test('rejects calories==0 from Gemini result', () async {
      final gemini = _MockGemini();
      when(() => gemini.hasApiKey).thenReturn(true);
      when(() => gemini.parseNutritionText(any())).thenAnswer(
        (_) async => const Success<NutritionLabelResult?>(
          NutritionLabelResult(
            caloriesPer100g: 0,
            proteinPer100g: 0,
            carbsPer100g: 0,
            fatPer100g: 0,
            fiberPer100g: 0,
          ),
        ),
      );

      final flow = LabelIntakeFlow(gemini: gemini);

      final result = await flow.processOcrText(
        ocrText: 'unreadable',
        idGenerator: () => 'id',
      );

      expect(result.isFailure, isTrue);
    });

    test('generates ServingSize fractions when servingSizeG is provided', () async {
      const ocrWithServing = '''
Nährwertangaben pro 100g:
Brennwert 2000 kJ / 480 kcal
Portion 30g
Fett 20 g
Kohlenhydrate 50 g
Ballaststoffe 5 g
Eiweiß 10 g
''';
      final flow = LabelIntakeFlow();

      final result = await flow.processOcrText(
        ocrText: ocrWithServing,
        idGenerator: () => 'id',
      );

      final intake = result.valueOrNull!;
      expect(intake.product.servings, isNotEmpty);
      expect(intake.label.servingSizeG, 30);
    });

    test('produces empty servings when no servingSizeG present', () async {
      final flow = LabelIntakeFlow();

      final result = await flow.processOcrText(
        ocrText: wellFormedOcr,
        idGenerator: () => 'id',
      );

      final intake = result.valueOrNull!;
      expect(intake.product.servings, isEmpty);
    });

    test('passes barcode into the FoodItem when provided', () async {
      final flow = LabelIntakeFlow();

      final result = await flow.processOcrText(
        ocrText: wellFormedOcr,
        idGenerator: () => 'id',
        barcode: '4006381333931',
      );

      final intake = result.valueOrNull!;
      expect(intake.product.barcode, '4006381333931');
    });

    test('idGenerator is called exactly once per call', () async {
      final flow = LabelIntakeFlow();
      var callCount = 0;
      String gen() {
        callCount++;
        return 'generated-$callCount';
      }

      final result = await flow.processOcrText(
        ocrText: wellFormedOcr,
        idGenerator: gen,
      );

      expect(callCount, 1);
      expect(result.valueOrNull!.product.id, 'generated-1');
    });

    test('hasGeminiFallback is false when no gemini passed', () {
      final flow = LabelIntakeFlow();
      expect(flow.hasGeminiFallback, isFalse);
    });

    test('hasGeminiFallback is false when gemini has no API key', () {
      final gemini = _MockGemini();
      when(() => gemini.hasApiKey).thenReturn(false);
      final flow = LabelIntakeFlow(gemini: gemini);
      expect(flow.hasGeminiFallback, isFalse);
    });

    test('hasGeminiFallback is true when gemini has API key', () {
      final gemini = _MockGemini();
      when(() => gemini.hasApiKey).thenReturn(true);
      final flow = LabelIntakeFlow(gemini: gemini);
      expect(flow.hasGeminiFallback, isTrue);
    });
  });
}
