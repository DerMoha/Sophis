import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/shareable_meal.dart';
import 'package:sophis/ui/screens/share_meal_screen.dart';
import 'package:sophis/ui/theme/app_theme.dart';

void main() {
  testWidgets('kept the QR code readable in dark mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ShareMealScreen(
          meal: ShareableMeal(
            items: [
              SharedFoodItem(
                name: 'Tomatoes',
                calories: 27,
                protein: 1.3,
                carbs: 5.8,
                fat: 0.3,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.backgroundColor, Colors.white);
    expect(qr.eyeStyle.color, Colors.black);
    expect(qr.dataModuleStyle.color, Colors.black);
    expect(tester.takeException(), isNull);
  });
}
