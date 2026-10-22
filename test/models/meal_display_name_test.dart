import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/custom_meal_type.dart';

void main() {
  test('localized untouched defaults and preserved renamed meals', () {
    final de = lookupAppLocalizations(const Locale('de'));
    final en = lookupAppLocalizations(const Locale('en'));
    final meals = CustomMealType.defaults;
    expect(meals.map((m) => m.displayName(de)),
        ['Frühstück', 'Mittagessen', 'Abendessen', 'Snacks']);
    expect(meals.first.displayName(en), 'Breakfast');
    expect(meals.first.copyWith(name: 'Brunch').displayName(de), 'Brunch');
    expect(
        const CustomMealType(id: 'breakfast', name: 'Breakfast')
            .displayName(de),
        'Breakfast');
    expect(meals.first.name, 'Breakfast');
  });
}
