import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/food_item.dart';
import 'package:sophis/ui/components/food_search_result_tile.dart';

void main() {
  group('FoodSearchResultTile', () {
    const testItem = FoodItem(
      id: 'apple-1',
      name: 'Apple',
      category: 'fruit',
      caloriesPer100g: 52,
      proteinPer100g: 0.3,
      carbsPer100g: 14,
      fatPer100g: 0.2,
      brand: 'Farm Fresh',
    );

    testWidgets('displays food name', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodSearchResultTile(
              item: testItem,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Apple'), findsOneWidget);
    });

    testWidgets('displays brand when available', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodSearchResultTile(
              item: testItem,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Farm Fresh'), findsOneWidget);
    });

    testWidgets('displays calorie badge', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodSearchResultTile(
              item: testItem,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('52'), findsOneWidget);
      expect(find.text('kcal'), findsOneWidget);
    });

    testWidgets('displays macro chips', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodSearchResultTile(
              item: testItem,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('P: 0g'), findsOneWidget);
      expect(find.text('C: 14g'), findsOneWidget);
      expect(find.text('F: 0g'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodSearchResultTile(
              item: testItem,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FoodSearchResultTile));
      expect(tapped, isTrue);
    });

    testWidgets('shows custom food label for custom foods',
        (WidgetTester tester) async {
      const customItem = FoodItem(
        id: 'custom-1',
        name: 'My Smoothie',
        category: 'custom',
        caloriesPer100g: 120,
        proteinPer100g: 5,
        carbsPer100g: 20,
        fatPer100g: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodSearchResultTile(
              item: customItem,
              onTap: () {},
              isCustomFood: true,
            ),
          ),
        ),
      );

      expect(find.text('My Foods'), findsOneWidget);
      expect(find.text('My Smoothie'), findsOneWidget);
    });

    testWidgets('shows favorite star when isFavorite is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodSearchResultTile(
              item: testItem,
              onTap: () {},
              isFavorite: true,
              onFavoriteToggle: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('shows outline star when not favorite',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodSearchResultTile(
              item: testItem,
              onTap: () {},
              isFavorite: false,
              onFavoriteToggle: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    });

    testWidgets('calls onFavoriteToggle when star tapped',
        (WidgetTester tester) async {
      var favoriteTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodSearchResultTile(
              item: testItem,
              onTap: () {},
              isFavorite: false,
              onFavoriteToggle: () => favoriteTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.star_outline_rounded));
      expect(favoriteTapped, isTrue);
    });

    testWidgets('hides favorite button when onFavoriteToggle is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodSearchResultTile(
              item: testItem,
              onTap: () {},
              isFavorite: false,
              onFavoriteToggle: null,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('displays brand label in primary color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: FoodSearchResultTile(
              item: testItem,
              onTap: () {},
            ),
          ),
        ),
      );

      final brandText = tester.widget<Text>(find.text('Farm Fresh'));
      expect(brandText.style?.color, isNotNull);
    });

    testWidgets('handles item without brand', (WidgetTester tester) async {
      const itemWithoutBrand = FoodItem(
        id: 'banana-1',
        name: 'Banana',
        category: 'fruit',
        caloriesPer100g: 89,
        proteinPer100g: 1.1,
        carbsPer100g: 23,
        fatPer100g: 0.3,
        brand: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodSearchResultTile(
              item: itemWithoutBrand,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('Farm Fresh'), findsNothing);
    });
  });
}
