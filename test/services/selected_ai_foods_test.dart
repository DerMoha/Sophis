import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/services/food_intake_controller.dart';
import 'package:sophis/services/gemini/models/food_analysis.dart';
import 'package:sophis/ui/components/ai_food_result.dart';

import '../helpers/test_services.dart';

void main() {
  test('saved checked foods, retained partial success and retried without duplicates', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final provider = await createLoadedNutritionProvider(database: db);
    final intake = FoodIntakeController(provider);
    final results = [for (final name in ['Rice', 'Excluded', 'Soup'])
      EditableFoodResult(analysis: FoodAnalysis(name: name, portionGrams: 100,
        calories: 100, protein: 2, carbs: 20, fat: 1, fiber: 1,),),];
    addTearDown(() { for (final result in results) { result.dispose(); } });
    results[1].isSelected = false;
    await db.customStatement("CREATE TRIGGER fail_soup BEFORE INSERT ON foods WHEN NEW.name LIKE 'Soup%' BEGIN SELECT RAISE(ABORT, 'failure'); END");
    final first = await addSelectedAiFoods(results, intake, 'dinner');
    expect(first.added, hasLength(1));
    expect(first.error, isNotNull);
    expect(results[0].isAdded, isTrue);
    expect(results[1].isAdded, isFalse);
    expect(results[2].isAdded, isFalse);
    await db.customStatement('DROP TRIGGER fail_soup');
    final second = await addSelectedAiFoods(results, intake, 'dinner');
    expect(second.added, hasLength(1));
    expect(second.error, isNull);
    expect(provider.entries, hasLength(2));
    expect(provider.entries.every((e) => e.meal == 'dinner'), isTrue);
    expect(provider.entries.any((e) => e.name.startsWith('Excluded')), isFalse);
    expect((await addSelectedAiFoods(results, intake, 'dinner')).added, isEmpty);
  });
}
