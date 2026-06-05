import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/ui/components/label_preview_sheet.dart';

class _SheetOpener extends StatefulWidget {
  const _SheetOpener({
    required this.label,
    required this.onResult,
  });

  final NutritionLabelResult label;
  final ValueChanged<bool> onResult;

  @override
  State<_SheetOpener> createState() => _SheetOpenerState();
}

class _SheetOpenerState extends State<_SheetOpener> {
  bool _open = false;

  Future<void> _openSheet() async {
    setState(() => _open = true);
    final result = await showLabelPreviewSheet(
      context: context,
      label: widget.label,
    );
    if (mounted) setState(() => _open = false);
    widget.onResult(result);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _open ? null : _openSheet,
      child: const Text('open'),
    );
  }
}

Widget _wrap({required NutritionLabelResult label, ValueChanged<bool>? onResult}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: _SheetOpener(label: label, onResult: onResult ?? (_) {}),
    ),
  );
}

const _fullLabel = NutritionLabelResult(
  productName: 'Greek Yogurt',
  brand: 'Fage',
  caloriesPer100g: 97,
  proteinPer100g: 9.0,
  carbsPer100g: 3.6,
  fatPer100g: 5.0,
  fiberPer100g: 0.0,
  servingSizeG: 170,
  servingName: '1 cup',
);

void main() {
  group('showLabelPreviewSheet', () {
    testWidgets('shows the product name and brand', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(label: _fullLabel));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Greek Yogurt'), findsOneWidget);
      expect(find.text('Fage'), findsOneWidget);
    });

    testWidgets('renders calories, protein, carbs, fat rows',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(label: _fullLabel));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.calories), findsOneWidget);
      expect(find.text(l10n.protein), findsOneWidget);
      expect(find.text(l10n.carbs), findsOneWidget);
      expect(find.text(l10n.fat), findsOneWidget);
    });

    testWidgets('hides fiber row when fiberPer100g == 0',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(label: _fullLabel));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.fiber), findsNothing);
    });

    testWidgets('shows fiber row when fiberPer100g > 0',
        (WidgetTester tester) async {
      const labelWithFiber = NutritionLabelResult(
        caloriesPer100g: 250,
        proteinPer100g: 8,
        carbsPer100g: 30,
        fatPer100g: 9,
        fiberPer100g: 5,
      );
      await tester.pumpWidget(_wrap(label: labelWithFiber));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.fiber), findsOneWidget);
    });

    testWidgets('shows serving-size line when servingSizeG is set',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(label: _fullLabel));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('170g'), findsOneWidget);
    });

    testWidgets('"Looks good" returns true', (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(_wrap(
        label: _fullLabel,
        onResult: (r) => result = r,
      ),);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.looksGood));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('"Rescan" returns false', (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(_wrap(
        label: _fullLabel,
        onResult: (r) => result = r,
      ),);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.rescanLabel));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });
}
